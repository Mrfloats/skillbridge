import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { Paynow } from "paynow";
import { CONFIG, BOOKING_STATUS as S } from "./config";
import { db, requireAuth, requireAdmin, walletEntry, audit, notify } from "./helpers";

const REGION = "europe-west1";
const PAYNOW_ID = defineSecret("PAYNOW_INTEGRATION_ID");
const PAYNOW_KEY = defineSecret("PAYNOW_INTEGRATION_KEY");
/** Public URL of the paynowResult function, set after first deploy. */
const RESULT_URL = defineString("PAYNOW_RESULT_URL", { default: "https://example.com/paynowResult" });
const RETURN_URL = defineString("PAYNOW_RETURN_URL", { default: "https://skillbridge.app/payment-complete" });

function paynow() {
  return new Paynow(PAYNOW_ID.value(), PAYNOW_KEY.value(), RESULT_URL.value(), RETURN_URL.value());
}

const MOBILE_METHODS = ["ecocash", "onemoney", "innbucks"];

/**
 * Starts a PayNow payment for an accepted quote (FR-6.1).
 * Mobile money sends a USSD prompt to the phone; "web" returns a redirect URL for card payment.
 */
export const initiatePayment = onCall({ region: REGION, secrets: [PAYNOW_ID, PAYNOW_KEY] }, async (req) => {
  const uid = requireAuth(req);
  const { bookingId, method, phone } = req.data as { bookingId: string; method: string; phone?: string };
  const bookingRef = db().collection("bookings").doc(bookingId);
  const booking = await bookingRef.get();
  const b = booking.data();
  if (!b || b.clientId !== uid) throw new HttpsError("permission-denied", "Not your booking.");
  if (b.status !== S.awaitingPayment) throw new HttpsError("failed-precondition", "This booking is not awaiting payment.");

  const user = (await db().collection("users").doc(uid).get()).data() ?? {};
  const paymentRef = db().collection("payments").doc();
  const amount = b.quotedFeeCents / 100;

  const pn = paynow();
  const payment = pn.createPayment(paymentRef.id, user.email ?? req.auth?.token.email ?? "");
  payment.add(`${CONFIG.appName}: ${b.serviceTitle}`, amount);

  let response;
  if (MOBILE_METHODS.includes(method)) {
    if (!phone || !/^07\d{8}$/.test(phone)) throw new HttpsError("invalid-argument", "Enter a mobile number like 0771234567.");
    response = await pn.sendMobile(payment, phone, method);
  } else {
    response = await pn.send(payment);
  }
  if (!response || !response.success) {
    logger.error("PayNow init failed", response?.error);
    throw new HttpsError("unavailable", `Payment could not start: ${response?.error ?? "PayNow unreachable"}`);
  }

  await paymentRef.set({
    bookingId,
    payerId: uid,
    payeeId: b.providerId,
    amountCents: b.quotedFeeCents,
    currency: CONFIG.currency,
    method,
    pollUrl: response.pollUrl,
    status: "initiated",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await bookingRef.update({ paymentId: paymentRef.id, paymentStatus: "initiated" });

  return {
    paymentId: paymentRef.id,
    redirectUrl: response.redirectUrl ?? null,
    instructions: response.instructions ?? null,
  };
});

/**
 * Polls PayNow and, if paid, moves money into escrow and confirms the booking.
 * Idempotent: safe to call from the callback and from the app (FR-6.9).
 */
async function settlePayment(paymentId: string): Promise<string> {
  const paymentRef = db().collection("payments").doc(paymentId);
  const p = (await paymentRef.get()).data();
  if (!p) throw new HttpsError("not-found", "Payment not found.");
  if (p.status !== "initiated") return p.status;

  const status = await paynow().pollTransaction(p.pollUrl);
  const state = (status?.status ?? "").toLowerCase();
  logger.info("PayNow poll", { paymentId, state });

  if (state === "paid" || state === "awaiting delivery" || state === "delivered") {
    await db().runTransaction(async (tx) => {
      const fresh = await tx.get(paymentRef);
      if (fresh.get("status") !== "initiated") return;
      const bookingRef = db().collection("bookings").doc(p.bookingId);
      const booking = await tx.get(bookingRef);
      tx.update(paymentRef, { status: "held", paynowStatus: state, paidAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      if (booking.get("status") === S.awaitingPayment) {
        tx.update(bookingRef, {
          status: S.confirmed,
          paymentStatus: "held",
          updatedAt: FieldValue.serverTimestamp(),
          timeline: FieldValue.arrayUnion({ status: S.confirmed, at: Timestamp.now() }),
        });
      } else {
        // Booking was cancelled while the client was paying: refund to wallet.
        walletEntry(tx, p.payerId, p.amountCents, "refund", p.bookingId, "Refund: booking no longer active");
        tx.update(paymentRef, { status: "refunded" });
      }
    });
    return "held";
  }
  if (["cancelled", "failed", "disputed", "refunded"].includes(state)) {
    await paymentRef.update({ status: "failed", paynowStatus: state, updatedAt: FieldValue.serverTimestamp() });
    await db().collection("bookings").doc(p.bookingId).update({ paymentStatus: "failed" });
    return "failed";
  }
  return "initiated";
}

export const checkPayment = onCall({ region: REGION, secrets: [PAYNOW_ID, PAYNOW_KEY] }, async (req) => {
  const uid = requireAuth(req);
  const { paymentId } = req.data as { paymentId: string };
  const p = (await db().collection("payments").doc(paymentId).get()).data();
  if (!p || p.payerId !== uid) throw new HttpsError("permission-denied", "Not your payment.");
  return { status: await settlePayment(paymentId) };
});

/** PayNow server-to-server status callback. Hash is verified, then status is re-polled. */
export const paynowResult = onRequest({ region: REGION, secrets: [PAYNOW_ID, PAYNOW_KEY] }, async (req, res) => {
  try {
    const raw = typeof req.rawBody !== "undefined" ? req.rawBody.toString("utf8") : "";
    const update = paynow().parseStatusUpdate(raw);
    if (update.reference) await settlePayment(String(update.reference));
    res.status(200).send("OK");
  } catch (e) {
    logger.error("PayNow callback rejected", e);
    res.status(400).send("Invalid");
  }
});

/** Provider (or client with refunds) withdraws wallet balance (FR-6.6). Paid out manually by admin. */
export const requestWithdrawal = onCall({ region: REGION }, async (req) => {
  const uid = requireAuth(req);
  const { amountCents, method, destination } = req.data as { amountCents: number; method: string; destination: string };
  if (!Number.isInteger(amountCents) || amountCents < CONFIG.minWithdrawalCents) {
    throw new HttpsError("invalid-argument", `Minimum withdrawal is ${(CONFIG.minWithdrawalCents / 100).toFixed(2)}.`);
  }
  if (!destination) throw new HttpsError("invalid-argument", "Enter where to send the money.");
  const id = await db().runTransaction(async (tx) => {
    const wallet = await tx.get(db().collection("wallets").doc(uid));
    const balance: number = wallet.get("balanceCents") ?? 0;
    if (balance < amountCents) throw new HttpsError("failed-precondition", "Insufficient balance.");
    const ref = db().collection("withdrawals").doc();
    walletEntry(tx, uid, -amountCents, "withdrawal", null, `Withdrawal to ${method} ${destination}`);
    tx.create(ref, { userId: uid, amountCents, method, destination, status: "pending", createdAt: FieldValue.serverTimestamp() });
    return ref.id;
  });
  return { withdrawalId: id };
});

export const markWithdrawalPaid = onCall({ region: REGION }, async (req) => {
  const adminId = requireAdmin(req);
  const { withdrawalId, reference, reject } = req.data as { withdrawalId: string; reference?: string; reject?: boolean };
  let userId = "";
  let amount = 0;
  await db().runTransaction(async (tx) => {
    const ref = db().collection("withdrawals").doc(withdrawalId);
    const w = (await tx.get(ref)).data();
    if (!w || w.status !== "pending") throw new HttpsError("failed-precondition", "Withdrawal is not pending.");
    userId = w.userId;
    amount = w.amountCents;
    if (reject) walletEntry(tx, w.userId, w.amountCents, "withdrawal_reversed", null, "Withdrawal rejected, funds returned");
    tx.update(ref, { status: reject ? "rejected" : "paid", reference: reference ?? "", processedBy: adminId, processedAt: FieldValue.serverTimestamp() });
    audit(tx, adminId, reject ? "withdrawal_rejected" : "withdrawal_paid", "withdrawal", withdrawalId, { reference });
  });
  await notify(userId, reject ? "Withdrawal rejected" : "Withdrawal sent", `${CONFIG.currency} ${(amount / 100).toFixed(2)}`, { type: "wallet" });
  return { ok: true };
});
