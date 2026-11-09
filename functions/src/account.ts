import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, Query } from "firebase-admin/firestore";
import { db, requireAdmin, requireAuth, audit, notify, notifyAdmins } from "./helpers";
import { BOOKING_STATUS as S } from "./config";

const REGION = "europe-west1";

/** Bookings still in progress. An account can't be deleted while any of these are open. */
const ACTIVE = [S.pending, S.awaitingPayment, S.confirmed, S.inTransit, S.inProgress, S.completed, S.disputed];

async function deleteAll(query: Query) {
  for (;;) {
    const snap = await query.limit(400).get();
    if (snap.empty) return;
    const batch = db().batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

/**
 * Deletes the caller's account (app settings → Delete account).
 * Refused while a booking is open or money is still on the balance, so nobody walks away from
 * a job or a debt. Bookings, reviews and wallet history are kept for both parties' records,
 * under the name "Deleted user". Personal details, photos, ID documents and the login are removed.
 */
export const deleteAccount = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  if (req.auth?.token.admin === true) throw new HttpsError("failed-precondition", "Admin accounts can't be deleted from the app. Ask another admin.");

  const bookings = db().collection("bookings");
  const [asClient, asProvider] = await Promise.all([
    bookings.where("clientId", "==", uid).where("status", "in", ACTIVE).limit(1).get(),
    bookings.where("providerId", "==", uid).where("status", "in", ACTIVE).limit(1).get(),
  ]);
  if (!asClient.empty || !asProvider.empty) {
    throw new HttpsError("failed-precondition", "You have a booking that is still open. Finish or cancel it first.");
  }

  const balance: number = (await db().collection("wallets").doc(uid).get()).get("balanceCents") ?? 0;
  if (balance > 0) throw new HttpsError("failed-precondition", "You still have money on your balance. Withdraw it first.");
  if (balance < 0) throw new HttpsError("failed-precondition", "Your balance is below zero. Top up to clear it first.");
  const pendingPayout = await db().collection("withdrawals").where("userId", "==", uid).where("status", "==", "pending").limit(1).get();
  if (!pendingPayout.empty) throw new HttpsError("failed-precondition", "A withdrawal is still being paid out. Try again once it arrives.");

  const userRef = db().collection("users").doc(uid);
  const role: string = (await userRef.get()).get("role") ?? "client";
  await userRef.set({ role, fullName: "Deleted user", email: "", phone: "", isSuspended: false, deleted: true, deletedAt: FieldValue.serverTimestamp() });

  const providerRef = db().collection("providers").doc(uid);
  if ((await providerRef.get()).exists) {
    await db().recursiveDelete(providerRef.collection("private"));
    await providerRef.update({
      fullName: "Deleted user",
      photoUrl: null,
      phone: "",
      bio: "",
      baseAddress: "",
      baseLocation: null,
      portfolioUrls: [],
      isAvailable: false,
      isVerified: false,
      deleted: true,
    });
    await deleteAll(db().collection("providerServices").where("providerId", "==", uid));
  }

  await Promise.all([
    deleteAll(db().collection("images").where("ownerId", "==", uid)),
    deleteAll(db().collection("notifications").where("userId", "==", uid)),
    db().collection("clientRatings").doc(uid).delete(),
  ]);
  await getAuth().deleteUser(uid);
  await audit(null, uid, "account_deleted", "user", uid, { role });
  return { ok: true };
});

const TOPICS = ["booking", "payment", "account", "safety", "other"];

/** A user sends a message to the support team, who see it in the admin console. */
export const contactSupport = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { topic, message } = req.data as { topic: unknown; message: unknown };
  if (typeof topic !== "string" || !TOPICS.includes(topic)) throw new HttpsError("invalid-argument", "Choose what your message is about.");
  const text = typeof message === "string" ? message.trim() : "";
  if (text.length < 10) throw new HttpsError("invalid-argument", "Tell us a little more, at least 10 characters.");
  if (text.length > 2000) throw new HttpsError("invalid-argument", "Keep your message under 2000 characters.");

  const u = (await db().collection("users").doc(uid).get()).data() ?? {};
  const ref = await db().collection("supportTickets").add({
    userId: uid,
    userName: u.fullName ?? "",
    email: u.email ?? "",
    phone: u.phone ?? "",
    role: u.role ?? "client",
    topic,
    message: text,
    status: "open",
    createdAt: FieldValue.serverTimestamp(),
  });
  await notifyAdmins("Support request", `${u.fullName ?? "A user"}: ${text.slice(0, 80)}`, { type: "support", refId: ref.id });
  return { ticketId: ref.id };
});

/** An admin closes a support request, with an optional note the user sees. */
export const resolveSupportTicket = onCall({ region: REGION }, async (req) => {
  const adminId = requireAdmin(req);
  const { ticketId, note } = req.data as { ticketId: unknown; note?: unknown };
  if (typeof ticketId !== "string" || !ticketId) throw new HttpsError("invalid-argument", "Missing request.");
  const reply = typeof note === "string" ? note.trim() : "";
  const ref = db().collection("supportTickets").doc(ticketId);
  const t = await db().runTransaction(async (tx) => {
    const t = (await tx.get(ref)).data();
    if (!t) throw new HttpsError("not-found", "Request not found.");
    if (t.status !== "open") throw new HttpsError("failed-precondition", "This request is already closed.");
    tx.update(ref, { status: "resolved", reply, resolvedBy: adminId, resolvedAt: FieldValue.serverTimestamp() });
    audit(tx, adminId, "support_resolved", "supportTicket", ticketId);
    return t;
  });
  await notify(t.userId, "Support request closed", reply || "We have dealt with your message. Thank you.", { type: "support", refId: ticketId });
  return { ok: true };
});
