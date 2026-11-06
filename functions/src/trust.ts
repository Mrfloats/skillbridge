import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getAuth } from "firebase-admin/auth";
import { FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { db, requireAdmin, requireAuth, audit, notify, notifyAdmins } from "./helpers";

const REGION = "europe-west1";

/** Admin approves or rejects a provider's documents (FR-2.4, FR-2.5). */
export const reviewProvider = onCall({ region: REGION }, async (req) => {
  const adminId = requireAdmin(req);
  const { providerId, approve, reason } = req.data as { providerId: string; approve: boolean; reason?: string };
  if (!approve && !reason) throw new HttpsError("invalid-argument", "Give a reason for rejection.");
  await db().runTransaction(async (tx) => {
    const ref = db().collection("providers").doc(providerId);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Provider not found.");
    tx.update(ref, {
      verificationStatus: approve ? "approved" : "rejected",
      isVerified: approve,
      rejectionReason: approve ? FieldValue.delete() : reason,
      verifiedAt: approve ? FieldValue.serverTimestamp() : FieldValue.delete(),
      verifiedBy: adminId,
    });
    audit(tx, adminId, approve ? "provider_approved" : "provider_rejected", "provider", providerId, { reason });
  });
  await notify(
    providerId,
    approve ? "You're verified" : "Verification unsuccessful",
    approve ? "Your profile is now visible to clients." : `Reason: ${reason}. You can resubmit your documents.`,
    { type: "verification" },
  );
  return { ok: true };
});

/** Admin suspends or reactivates an account (FR-1.8). */
export const setUserSuspended = onCall({ region: REGION }, async (req) => {
  const adminId = requireAdmin(req);
  const { userId, suspended } = req.data as { userId: string; suspended: boolean };
  await getAuth().updateUser(userId, { disabled: suspended });
  if (suspended) await getAuth().revokeRefreshTokens(userId);
  await db().collection("users").doc(userId).update({ isSuspended: suspended });
  const provider = db().collection("providers").doc(userId);
  if ((await provider.get()).exists) await provider.update({ isSuspended: suspended });
  await audit(null, adminId, suspended ? "user_suspended" : "user_reactivated", "user", userId);
  return { ok: true };
});

/** Admin hides or restores a review (FR-8.6). */
export const setReviewHidden = onCall({ region: REGION }, async (req) => {
  const adminId = requireAdmin(req);
  const { reviewId, hidden } = req.data as { reviewId: string; hidden: boolean };
  const ref = db().collection("reviews").doc(reviewId);
  await db().runTransaction(async (tx) => {
    const r = (await tx.get(ref)).data();
    if (!r) throw new HttpsError("not-found", "Review not found.");
    if (r.isHidden === hidden) return;
    const pRef = db().collection("providers").doc(r.providerId);
    const p = (await tx.get(pRef)).data() ?? {};
    const sum: number = (p.ratingSum ?? 0) + (hidden ? -r.rating : r.rating);
    const count: number = (p.reviewCount ?? 0) + (hidden ? -1 : 1);
    tx.update(pRef, { ratingSum: sum, reviewCount: count, avgRating: count > 0 ? Math.round((sum / count) * 10) / 10 : 0 });
    tx.update(ref, { isHidden: hidden });
    audit(tx, adminId, hidden ? "review_hidden" : "review_restored", "review", reviewId);
  });
  return { ok: true };
});

/** Grants the admin role. Only existing admins can call it; bootstrap the first admin with scripts/make-admin.js. */
export const setAdmin = onCall({ region: REGION }, async (req) => {
  const adminId = requireAdmin(req);
  const { userId, admin } = req.data as { userId: string; admin: boolean };
  await getAuth().setCustomUserClaims(userId, { admin });
  await db().collection("users").doc(userId).update({ role: admin ? "admin" : "client" });
  await audit(null, adminId, admin ? "admin_granted" : "admin_revoked", "user", userId);
  return { ok: true };
});

/** Recalculates the provider's rating on each review (FR-8.3). Rules ensure one review per completed booking. */
export const onReviewCreated = onDocumentCreated({ document: "reviews/{id}", region: REGION }, async (event) => {
  const r = event.data?.data();
  if (!r) return;
  const pRef = db().collection("providers").doc(r.providerId);
  await db().runTransaction(async (tx) => {
    const p = (await tx.get(pRef)).data() ?? {};
    const sum = (p.ratingSum ?? 0) + r.rating;
    const count = (p.reviewCount ?? 0) + 1;
    tx.update(pRef, { ratingSum: sum, reviewCount: count, avgRating: Math.round((sum / count) * 10) / 10 });
    tx.update(db().collection("bookings").doc(r.bookingId), { reviewed: true });
  });
  await notify(r.providerId, "New review", `${r.rating}★ from ${r.clientName}`, { type: "review", refId: r.bookingId });
});

/** SOS: alert admins and the user's trusted contacts (FR-9.2, FR-9.4). */
export const onSosCreated = onDocumentCreated({ document: "sosAlerts/{id}", region: REGION }, async (event) => {
  const a = event.data?.data();
  if (!a) return;
  await notifyAdmins("SOS ALERT", `${a.userName} needs help (booking ${a.bookingId})`, { type: "sos", refId: event.params.id });
  const user = (await db().collection("users").doc(a.userId).get()).data() ?? {};
  const contacts: { name: string; phone: string }[] = user.trustedContacts ?? [];
  const mapLink = a.location ? `https://maps.google.com/?q=${a.location.latitude},${a.location.longitude}` : "location unavailable";
  for (const c of contacts) {
    // Integration point: send SMS through your SMS gateway (e.g. Africa's Talking, Twilio).
    // Queued in Firestore so a gateway extension or worker can deliver it.
    await db().collection("smsQueue").add({
      to: c.phone,
      body: `SOS from ${a.userName} via SkillBridge. Last location: ${mapLink}. Other party: ${a.otherPartyName}.`,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  logger.warn("SOS raised", { id: event.params.id, userId: a.userId, contacts: contacts.length });
});

export const resolveSos = onCall({ region: REGION }, async (req) => {
  const adminId = requireAdmin(req);
  const { alertId, status, note } = req.data as { alertId: string; status: "acknowledged" | "resolved"; note?: string };
  await db().collection("sosAlerts").doc(alertId).update({
    status,
    adminId,
    note: note ?? "",
    [`${status}At`]: FieldValue.serverTimestamp(),
  });
  await audit(null, adminId, `sos_${status}`, "sosAlert", alertId, { note });
  return { ok: true };
});

/** Push for new chat messages (FR-7.3). */
export const onMessageCreated = onDocumentCreated({ document: "chats/{chatId}/messages/{msgId}", region: REGION }, async (event) => {
  const m = event.data?.data();
  if (!m) return;
  const chatRef = db().collection("chats").doc(event.params.chatId);
  const chat = (await chatRef.get()).data();
  if (!chat) return;
  await chatRef.update({ lastMessage: m.text || "Photo", updatedAt: FieldValue.serverTimestamp() });
  const to = (chat.participants as string[]).filter((p) => p !== m.senderId);
  for (const uid of to) await notify(uid, m.senderName ?? "New message", m.text || "Sent a photo", { type: "chat", refId: event.params.chatId });
});

/** Flag a user, review or message to admins (FR-7.4). */
export const reportContent = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { targetType, targetId, reason } = req.data as { targetType: string; targetId: string; reason: string };
  await db().collection("reports").add({ reporterId: uid, targetType, targetId, reason, status: "open", createdAt: FieldValue.serverTimestamp() });
  await notifyAdmins("Content reported", `${targetType} flagged: ${reason}`, { type: "report" });
  return { ok: true };
});
