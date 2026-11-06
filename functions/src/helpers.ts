import { getFirestore, FieldValue, Timestamp, Transaction, DocumentReference } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

export const db = () => getFirestore();

export function requireAuth(req: CallableRequest): string {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return req.auth.uid;
}

export function requireAdmin(req: CallableRequest): string {
  const uid = requireAuth(req);
  if (req.auth?.token.admin !== true) throw new HttpsError("permission-denied", "Admins only.");
  return uid;
}

export function hoursAgo(h: number): Timestamp {
  return Timestamp.fromMillis(Date.now() - h * 3600 * 1000);
}

/** Slot lock id: one provider, one date, one slot (FR-5.5). */
export function slotId(providerId: string, serviceDate: Timestamp, timeSlot: string): string {
  const d = serviceDate.toDate();
  const ymd = `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, "0")}${String(d.getUTCDate()).padStart(2, "0")}`;
  return `${providerId}_${ymd}_${timeSlot}`;
}

/** Credit (positive) or debit (negative) a wallet inside a transaction. */
export function walletEntry(
  tx: Transaction,
  uid: string,
  amountCents: number,
  type: string,
  bookingId: string | null,
  note: string,
) {
  const walletRef = db().collection("wallets").doc(uid);
  tx.set(
    walletRef,
    { uid, balanceCents: FieldValue.increment(amountCents), currency: "USD", updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  tx.create(walletRef.collection("transactions").doc(), {
    type,
    amountCents,
    bookingId,
    note,
    createdAt: FieldValue.serverTimestamp(),
  });
}

export function audit(tx: Transaction | null, adminId: string, action: string, targetType: string, targetId: string, details: object = {}) {
  const ref = db().collection("auditLogs").doc();
  const data = { adminId, action, targetType, targetId, details, createdAt: FieldValue.serverTimestamp() };
  if (tx) tx.create(ref, data);
  else return ref.set(data);
  return undefined;
}

/** Writes an in-app notification and sends a push to the user's devices (FR-10.1). */
export async function notify(uid: string, title: string, body: string, data: Record<string, string> = {}) {
  await db().collection("notifications").add({
    userId: uid,
    title,
    body,
    type: data.type ?? "general",
    refId: data.refId ?? null,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
  const user = await db().collection("users").doc(uid).get();
  const tokens: string[] = user.get("fcmTokens") ?? [];
  if (tokens.length === 0) return;
  try {
    const res = await getMessaging().sendEachForMulticast({ tokens, notification: { title, body }, data });
    const dead = res.responses
      .map((r, i) => (!r.success && r.error?.code === "messaging/registration-token-not-registered" ? tokens[i] : null))
      .filter((t): t is string => t !== null);
    if (dead.length) await user.ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  } catch (e) {
    logger.warn("Push failed", { uid, e });
  }
}

export async function notifyAdmins(title: string, body: string, data: Record<string, string> = {}) {
  try {
    await getMessaging().send({ topic: "admins", notification: { title, body }, data });
  } catch (e) {
    logger.warn("Admin push failed", e);
  }
}

export async function getBooking(tx: Transaction, bookingId: string) {
  const ref = db().collection("bookings").doc(bookingId) as DocumentReference;
  const snap = await tx.get(ref);
  if (!snap.exists) throw new HttpsError("not-found", "Booking not found.");
  return { ref, data: snap.data()! };
}
