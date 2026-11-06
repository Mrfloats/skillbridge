import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { FieldValue, Timestamp, Transaction } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { CONFIG, BOOKING_STATUS as S } from "./config";
import { db, requireAuth, requireAdmin, slotId, walletEntry, audit, notify, getBooking, hoursAgo } from "./helpers";

const REGION = "europe-west1";

function stamp(status: string) {
  return {
    status,
    updatedAt: FieldValue.serverTimestamp(),
    timeline: FieldValue.arrayUnion({ status, at: Timestamp.now() }),
  };
}

function freeSlot(tx: Transaction, b: FirebaseFirestore.DocumentData) {
  if (b.slotLocked) tx.delete(db().collection("slots").doc(slotId(b.providerId, b.serviceDate, b.timeSlot)));
}

/** Release held funds to the provider, minus commission (FR-6.3, FR-6.5). */
export function releaseEscrow(tx: Transaction, bookingRef: FirebaseFirestore.DocumentReference, b: FirebaseFirestore.DocumentData, providerShareCents?: number) {
  const fee: number = b.quotedFeeCents;
  const gross = providerShareCents ?? fee;
  const commission = Math.round(gross * CONFIG.commissionRate);
  walletEntry(tx, b.providerId, gross - commission, "earning", bookingRef.id, `Payment for ${b.serviceTitle}`);
  tx.create(db().collection("revenue").doc(), {
    bookingId: bookingRef.id,
    commissionCents: commission,
    createdAt: FieldValue.serverTimestamp(),
  });
  const refund = fee - gross;
  if (refund > 0) walletEntry(tx, b.clientId, refund, "refund", bookingRef.id, `Partial refund for ${b.serviceTitle}`);
  tx.update(bookingRef, { ...stamp(S.closed), paymentStatus: "released", commissionCents: commission, releasedAt: FieldValue.serverTimestamp() });
  tx.update(db().collection("payments").doc(b.paymentId), { status: "released", updatedAt: FieldValue.serverTimestamp() });
  tx.update(db().collection("providers").doc(b.providerId), { completedJobs: FieldValue.increment(1) });
}

export function refundClient(tx: Transaction, bookingRef: FirebaseFirestore.DocumentReference, b: FirebaseFirestore.DocumentData, refundCents: number) {
  const fee: number = b.quotedFeeCents;
  if (refundCents > 0) walletEntry(tx, b.clientId, refundCents, "refund", bookingRef.id, `Refund for ${b.serviceTitle}`);
  const toProvider = fee - refundCents;
  if (toProvider > 0) {
    const commission = Math.round(toProvider * CONFIG.commissionRate);
    walletEntry(tx, b.providerId, toProvider - commission, "cancellation_fee", bookingRef.id, `Late cancellation fee`);
  }
  tx.update(db().collection("payments").doc(b.paymentId), { status: "refunded", updatedAt: FieldValue.serverTimestamp() });
}

/** Provider accepts with a quote or declines (FR-5.3, FR-5.5). */
export const respondToBooking = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { bookingId, accept, feeCents } = req.data as { bookingId: string; accept: boolean; feeCents?: number };
  await db().runTransaction(async (tx) => {
    const { ref, data: b } = await getBooking(tx, bookingId);
    if (b.providerId !== uid) throw new HttpsError("permission-denied", "Not your booking.");
    if (b.status !== S.pending) throw new HttpsError("failed-precondition", "Booking is no longer pending.");
    if (!accept) {
      tx.update(ref, stamp(S.declined));
      return;
    }
    if (!Number.isInteger(feeCents) || (feeCents as number) < 100) throw new HttpsError("invalid-argument", "Quote must be at least 1.00.");
    const lockRef = db().collection("slots").doc(slotId(b.providerId, b.serviceDate, b.timeSlot));
    const lock = await tx.get(lockRef);
    if (lock.exists) throw new HttpsError("already-exists", "You already have a booking in this time slot.");
    tx.create(lockRef, { bookingId, providerId: uid, createdAt: FieldValue.serverTimestamp() });
    tx.update(ref, { ...stamp(S.awaitingPayment), quotedFeeCents: feeCents, slotLocked: true, acceptedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
});

/** Provider moves a paid job along: confirmed → in_transit → in_progress → completed (FR-5.8). */
export const updateJobStatus = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { bookingId, status } = req.data as { bookingId: string; status: string };
  const allowed: Record<string, string> = {
    [S.confirmed]: S.inTransit,
    [S.inTransit]: S.inProgress,
    [S.inProgress]: S.completed,
  };
  await db().runTransaction(async (tx) => {
    const { ref, data: b } = await getBooking(tx, bookingId);
    if (b.providerId !== uid) throw new HttpsError("permission-denied", "Not your booking.");
    if (allowed[b.status] !== status) throw new HttpsError("failed-precondition", `Cannot move from ${b.status} to ${status}.`);
    const extra = status === S.completed ? { completedAt: FieldValue.serverTimestamp() } : {};
    tx.update(ref, { ...stamp(status), ...extra });
  });
  return { ok: true };
});

/** Client confirms the work is done; funds are released (FR-6.3). */
export const confirmCompletion = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { bookingId } = req.data as { bookingId: string };
  await db().runTransaction(async (tx) => {
    const { ref, data: b } = await getBooking(tx, bookingId);
    if (b.clientId !== uid) throw new HttpsError("permission-denied", "Not your booking.");
    if (b.status !== S.completed || b.paymentStatus !== "held") throw new HttpsError("failed-precondition", "Job is not awaiting confirmation.");
    releaseEscrow(tx, ref, b);
    freeSlot(tx, b);
  });
  return { ok: true };
});

/** Client disputes a completed job within the release window (FR-12.3). */
export const raiseDispute = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { bookingId, reason } = req.data as { bookingId: string; reason: string };
  if (!reason || reason.trim().length < 10) throw new HttpsError("invalid-argument", "Describe the problem (at least 10 characters).");
  await db().runTransaction(async (tx) => {
    const { ref, data: b } = await getBooking(tx, bookingId);
    if (b.clientId !== uid && b.providerId !== uid) throw new HttpsError("permission-denied", "Not your booking.");
    const disputable = [S.confirmed, S.inTransit, S.inProgress, S.completed];
    if (!disputable.includes(b.status) || b.paymentStatus !== "held") throw new HttpsError("failed-precondition", "This booking cannot be disputed.");
    tx.create(db().collection("disputes").doc(bookingId), {
      bookingId,
      raisedBy: uid,
      reason: reason.trim(),
      previousStatus: b.status,
      status: "open",
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(ref, stamp(S.disputed));
  });
  return { ok: true };
});

/** Admin settles a dispute: release, refund or split (FR-12.3). */
export const resolveDispute = onCall({ region: REGION }, async (req) => {
  const adminId = requireAdmin(req);
  const { bookingId, outcome, providerPercent, note } = req.data as {
    bookingId: string; outcome: "release" | "refund" | "split"; providerPercent?: number; note?: string;
  };
  await db().runTransaction(async (tx) => {
    const { ref, data: b } = await getBooking(tx, bookingId);
    if (b.status !== S.disputed) throw new HttpsError("failed-precondition", "Booking is not disputed.");
    const fee: number = b.quotedFeeCents;
    if (outcome === "release") {
      releaseEscrow(tx, ref, b);
    } else if (outcome === "refund") {
      refundClient(tx, ref, b, fee);
      tx.update(ref, { ...stamp(S.cancelled), paymentStatus: "refunded" });
    } else {
      const pct = Math.max(0, Math.min(100, providerPercent ?? 50));
      releaseEscrow(tx, ref, b, Math.round((fee * pct) / 100));
    }
    freeSlot(tx, b);
    tx.update(db().collection("disputes").doc(bookingId), {
      status: "resolved", outcome, providerPercent: providerPercent ?? null, note: note ?? "", adminId,
      resolvedAt: FieldValue.serverTimestamp(),
    });
    audit(tx, adminId, `dispute_${outcome}`, "booking", bookingId, { providerPercent, note });
  });
  return { ok: true };
});

/** Either party cancels; refund rules from SRS 8.3 (FR-5.7, FR-6.7). */
export const cancelBooking = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { bookingId, reason } = req.data as { bookingId: string; reason?: string };
  let refundCents = 0;
  await db().runTransaction(async (tx) => {
    const { ref, data: b } = await getBooking(tx, bookingId);
    const isClient = b.clientId === uid;
    if (!isClient && b.providerId !== uid) throw new HttpsError("permission-denied", "Not your booking.");
    const cancellable = [S.pending, S.awaitingPayment, S.confirmed];
    if (!cancellable.includes(b.status)) throw new HttpsError("failed-precondition", "This booking can no longer be cancelled. Raise a dispute instead.");
    if (b.paymentStatus === "held") {
      const fee: number = b.quotedFeeCents;
      const hoursToJob = ((b.serviceDate as Timestamp).toMillis() - Date.now()) / 3600000;
      refundCents = isClient && hoursToJob < CONFIG.freeCancelHours ? Math.round(fee * (1 - CONFIG.lateCancelFeeRate)) : fee;
      refundClient(tx, ref, b, refundCents);
    }
    freeSlot(tx, b);
    tx.update(ref, {
      ...stamp(S.cancelled),
      cancelledBy: uid,
      cancelReason: reason ?? "",
      paymentStatus: b.paymentStatus === "held" ? "refunded" : b.paymentStatus ?? "none",
    });
  });
  return { ok: true, refundCents };
});

/** Reschedule proposals: one party proposes, the other accepts (FR-5.6). */
export const respondToReschedule = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { bookingId, accept } = req.data as { bookingId: string; accept: boolean };
  await db().runTransaction(async (tx) => {
    const { ref, data: b } = await getBooking(tx, bookingId);
    const p = b.rescheduleRequest;
    if (!p) throw new HttpsError("failed-precondition", "No reschedule request.");
    if (p.requestedBy === uid || (b.clientId !== uid && b.providerId !== uid)) throw new HttpsError("permission-denied", "Only the other party can answer.");
    if (!accept) {
      tx.update(ref, { rescheduleRequest: FieldValue.delete() });
      return;
    }
    if (b.slotLocked) {
      const newLock = db().collection("slots").doc(slotId(b.providerId, p.serviceDate, p.timeSlot));
      if ((await tx.get(newLock)).exists) throw new HttpsError("already-exists", "Provider is booked in that slot.");
      freeSlot(tx, b);
      tx.create(newLock, { bookingId, providerId: b.providerId, createdAt: FieldValue.serverTimestamp() });
    }
    tx.update(ref, {
      serviceDate: p.serviceDate,
      timeSlot: p.timeSlot,
      rescheduleRequest: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});

/** Hourly: auto-release escrow, expire stale requests and unpaid quotes (FR-5.4, FR-6.4). */
export const bookingHousekeeping = onSchedule({ schedule: "every 60 minutes", region: REGION }, async () => {
  const col = db().collection("bookings");

  const toRelease = await col.where("status", "==", S.completed).where("completedAt", "<=", hoursAgo(CONFIG.autoReleaseHours)).get();
  for (const doc of toRelease.docs) {
    await db().runTransaction(async (tx) => {
      const { ref, data: b } = await getBooking(tx, doc.id);
      if (b.status === S.completed && b.paymentStatus === "held") {
        releaseEscrow(tx, ref, b);
        freeSlot(tx, b);
      }
    });
  }

  const stalePending = await col.where("status", "==", S.pending).where("createdAt", "<=", hoursAgo(CONFIG.requestExpiryHours)).get();
  for (const doc of stalePending.docs) await doc.ref.update(stamp(S.expired));

  const unpaid = await col.where("status", "==", S.awaitingPayment).where("acceptedAt", "<=", hoursAgo(CONFIG.paymentExpiryHours)).get();
  for (const doc of unpaid.docs) {
    await db().runTransaction(async (tx) => {
      const { ref, data: b } = await getBooking(tx, doc.id);
      if (b.status !== S.awaitingPayment) return;
      freeSlot(tx, b);
      tx.update(ref, { ...stamp(S.cancelled), cancelReason: "Quote not paid in time" });
    });
  }
  logger.info("Housekeeping", { released: toRelease.size, expired: stalePending.size, unpaid: unpaid.size });
});

/** New booking: validate server-side fields and notify the provider (FR-5.2). */
export const onBookingCreated = onDocumentCreated({ document: "bookings/{id}", region: REGION }, async (event) => {
  const b = event.data?.data();
  if (!b) return;
  await event.data!.ref.update({
    timeline: [{ status: S.pending, at: Timestamp.now() }],
    paymentStatus: "none",
    chatId: event.params.id,
  });
  await db().collection("chats").doc(event.params.id).set({
    bookingId: event.params.id,
    participants: [b.clientId, b.providerId],
    lastMessage: "",
    updatedAt: FieldValue.serverTimestamp(),
  });
  await notify(b.providerId, "New booking request", `${b.clientName} wants ${b.serviceTitle}`, { type: "booking", refId: event.params.id });
});

const STATUS_MESSAGES: Record<string, [to: "client" | "provider" | "both", text: string]> = {
  [S.awaitingPayment]: ["client", "Your request was accepted. Pay to confirm."],
  [S.declined]: ["client", "The provider declined your request."],
  [S.expired]: ["client", "Your request expired with no response."],
  [S.confirmed]: ["both", "Booking confirmed and paid."],
  [S.inTransit]: ["client", "Your provider is on the way."],
  [S.inProgress]: ["client", "Your provider has started the job."],
  [S.completed]: ["client", "Job marked complete. Please confirm and rate."],
  [S.closed]: ["provider", "Payment released to your wallet."],
  [S.cancelled]: ["both", "Booking cancelled."],
  [S.disputed]: ["both", "A dispute was raised. An admin will review it."],
};

export const onBookingUpdated = onDocumentUpdated({ document: "bookings/{id}", region: REGION }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const id = event.params.id;
  if (before.status !== after.status) {
    const msg = STATUS_MESSAGES[after.status];
    if (msg) {
      const [to, text] = msg;
      if (to !== "provider") await notify(after.clientId, after.serviceTitle, text, { type: "booking", refId: id });
      if (to !== "client") await notify(after.providerId, after.serviceTitle, text, { type: "booking", refId: id });
    }
  }
  if (!before.rescheduleRequest && after.rescheduleRequest) {
    const other = after.rescheduleRequest.requestedBy === after.clientId ? after.providerId : after.clientId;
    await notify(other, "Reschedule requested", `New time proposed for ${after.serviceTitle}`, { type: "booking", refId: id });
  }
});

