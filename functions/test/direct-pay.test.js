// End-to-end tests of the per-service charge, run against the Firebase emulators:
//   npm test
// They call the real Cloud Functions, using a "demo-" project that cannot reach live
// Firebase services. A small local server stands in for PayNow.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const http = require("node:http");

const { bookingHousekeeping } = require("../lib/index.js");
const { Timestamp } = require("firebase-admin/firestore");
const { db, HOUR, signUp, call, setBalance, balanceOf, bookingOf, walletTxns, revenueFor, newBooking } = require("./helpers");

// ---------- Fake PayNow ----------
let paynowServer;
let paynowUrl;

/** Signs a reply the way PayNow does. The emulator runs with an empty integration key. */
function signedReply(fields) {
  const hash = crypto.createHash("sha512").update(Object.values(fields).join("")).digest("hex").toUpperCase();
  return new URLSearchParams({ ...fields, hash }).toString();
}

before(async () => {
  paynowServer = http.createServer((req, res) => {
    res.end(signedReply({ reference: "ref", paynowreference: "1", amount: "10.00", status: req.url.slice(1), pollurl: "x" }));
  });
  await new Promise((resolve) => paynowServer.listen(0, "127.0.0.1", resolve));
  paynowUrl = `http://127.0.0.1:${paynowServer.address().port}`;
});

after(() => paynowServer.close());

/** A provider, a client and a job the provider has marked complete. */
async function completedJob(balanceCents, fields = {}) {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  await setBalance(provider.uid, balanceCents);
  const id = await newBooking(client, provider, { status: "completed", quotedFeeCents: 3500, completedAt: Timestamp.now(), ...fields });
  return { client, provider, id };
}

// ---------- Sending a quote ----------
test("a provider who cannot cover the charge cannot send a quote", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  await setBalance(provider.uid, 349);
  const id = await newBooking(client, provider);

  await assert.rejects(call("respondToBooking", { bookingId: id, accept: true, feeCents: 3500 }, provider), {
    code: "FAILED_PRECONDITION",
    message: /balance is too low.*3\.50/,
  });

  const b = await bookingOf(id);
  assert.equal(b.status, "pending");
  assert.equal(b.slotLocked, undefined);
});

test("a provider with no wallet yet cannot send a quote", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  const id = await newBooking(client, provider);
  await assert.rejects(call("respondToBooking", { bookingId: id, accept: true, feeCents: 100 }, provider), { code: "FAILED_PRECONDITION" });
});

test("a balance equal to the charge is enough, and declining needs no balance", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  await setBalance(provider.uid, 350);
  const quoted = await newBooking(client, provider);
  await call("respondToBooking", { bookingId: quoted, accept: true, feeCents: 3500 }, provider);
  assert.equal((await bookingOf(quoted)).status, "awaiting_payment");
  assert.equal(await balanceOf(provider.uid), 350, "sending a quote does not charge");

  await setBalance(provider.uid, 0);
  const declined = await newBooking(client, provider);
  await call("respondToBooking", { bookingId: declined, accept: false }, provider);
  assert.equal((await bookingOf(declined)).status, "declined");
});

// ---------- The whole job ----------
test("a job runs from quote to close, charging 10% once, with no payment in the app", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  await setBalance(provider.uid, 500);
  const bookingId = await newBooking(client, provider);

  await call("respondToBooking", { bookingId, accept: true, feeCents: 3500 }, provider);
  await call("acceptQuote", { bookingId }, client);
  assert.equal((await bookingOf(bookingId)).status, "confirmed");

  for (const status of ["in_transit", "in_progress", "completed"]) {
    await call("updateJobStatus", { bookingId, status }, provider);
  }
  assert.equal(await balanceOf(provider.uid), 500, "no charge before the job closes");

  await call("confirmCompletion", { bookingId }, client);

  const b = await bookingOf(bookingId);
  assert.equal(b.status, "closed");
  assert.equal(b.commissionCents, 350);
  assert.equal(await balanceOf(provider.uid), 150);
  assert.deepEqual((await walletTxns(provider.uid)).map((t) => [t.type, t.amountCents, t.bookingId]), [["commission", -350, bookingId]]);
  assert.deepEqual(await revenueFor(bookingId), [350]);
  assert.equal(await balanceOf(client.uid), 0, "the client's wallet is untouched");
  assert.equal((await db().collection("providers").doc(provider.uid).get()).get("completedJobs"), 1);
  assert.equal((await db().collection("slots").where("bookingId", "==", bookingId).get()).size, 0, "the slot is freed");

  await assert.rejects(call("confirmCompletion", { bookingId }, client), { code: "FAILED_PRECONDITION" });
  assert.equal(await balanceOf(provider.uid), 150, "confirming again does not charge again");
});

test("only the client can accept a quote, and only while it is open", async () => {
  const [client, provider, stranger] = await Promise.all([signUp("client"), signUp("provider"), signUp("client")]);
  await setBalance(provider.uid, 500);
  const bookingId = await newBooking(client, provider);

  await assert.rejects(call("acceptQuote", { bookingId }, client), { code: "FAILED_PRECONDITION" });
  await call("respondToBooking", { bookingId, accept: true, feeCents: 3500 }, provider);
  await assert.rejects(call("acceptQuote", { bookingId }, provider), { code: "PERMISSION_DENIED" });
  await assert.rejects(call("acceptQuote", { bookingId }, stranger), { code: "PERMISSION_DENIED" });

  await call("acceptQuote", { bookingId }, client);
  await assert.rejects(call("acceptQuote", { bookingId }, client), { code: "FAILED_PRECONDITION" });
});

test("a charge can take the balance below zero, which then blocks new quotes", async () => {
  const { client, provider, id } = await completedJob(100);
  await call("confirmCompletion", { bookingId: id }, client);
  assert.equal(await balanceOf(provider.uid), -250);

  const next = await newBooking(client, provider);
  await assert.rejects(call("respondToBooking", { bookingId: next, accept: true, feeCents: 100 }, provider), { code: "FAILED_PRECONDITION" });
});

test("cancelling a directly paid booking charges and refunds nothing", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  await setBalance(provider.uid, 500);
  const bookingId = await newBooking(client, provider);
  await call("respondToBooking", { bookingId, accept: true, feeCents: 3500 }, provider);
  await call("acceptQuote", { bookingId }, client);

  const { refundCents } = await call("cancelBooking", { bookingId, reason: "Plans changed" }, client);

  assert.equal(refundCents, 0);
  assert.equal((await bookingOf(bookingId)).status, "cancelled");
  assert.equal(await balanceOf(provider.uid), 500);
  assert.equal(await balanceOf(client.uid), 0);
});

// ---------- Automatic close ----------
test("housekeeping closes and charges an unconfirmed job after 48 hours, but not sooner", async () => {
  const old = await completedJob(500, { completedAt: Timestamp.fromMillis(Date.now() - 49 * HOUR) });
  const fresh = await completedJob(500, { completedAt: Timestamp.fromMillis(Date.now() - 47 * HOUR) });

  await bookingHousekeeping.run({});

  assert.equal((await bookingOf(old.id)).status, "closed");
  assert.equal(await balanceOf(old.provider.uid), 150);
  assert.equal((await bookingOf(fresh.id)).status, "completed");
  assert.equal(await balanceOf(fresh.provider.uid), 500);

  await bookingHousekeeping.run({});
  assert.equal(await balanceOf(old.provider.uid), 150, "a second run does not charge again");
});

test("housekeeping cancels a quote left unanswered for 24 hours", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  const id = await newBooking(client, provider, {
    status: "awaiting_payment",
    quotedFeeCents: 3500,
    acceptedAt: Timestamp.fromMillis(Date.now() - 25 * HOUR),
  });
  await bookingHousekeeping.run({});
  const b = await bookingOf(id);
  assert.equal(b.status, "cancelled");
  assert.equal(b.cancelReason, "Quote not accepted in time");
});

// ---------- Disputes ----------
test("a client can dispute a directly paid job, which pauses the charge", async () => {
  const { client, provider, id } = await completedJob(500);
  await call("raiseDispute", { bookingId: id, reason: "The tap still leaks badly" }, client);
  assert.equal((await bookingOf(id)).status, "disputed");
  assert.equal(await balanceOf(provider.uid), 500);
  await assert.rejects(call("confirmCompletion", { bookingId: id }, client), { code: "FAILED_PRECONDITION" });
});

for (const [outcome, providerPercent, status, charged] of [
  ["release", null, "closed", 350],
  ["refund", null, "cancelled", 0],
  ["split", 50, "closed", 175],
  ["split", 0, "closed", 0],
]) {
  test(`dispute outcome "${outcome}"${providerPercent === null ? "" : ` at ${providerPercent}%`} charges ${charged} on a directly paid job`, async () => {
    const admin = await signUp("admin");
    const { client, provider, id } = await completedJob(500);
    await call("raiseDispute", { bookingId: id, reason: "The tap still leaks badly" }, client);

    await call("resolveDispute", { bookingId: id, outcome, providerPercent, note: "Reviewed" }, admin);

    const b = await bookingOf(id);
    assert.equal(b.status, status);
    assert.equal(await balanceOf(provider.uid), 500 - charged);
    assert.equal(await balanceOf(client.uid), 0, "no money is sent to the client");
    assert.deepEqual(await revenueFor(id), charged ? [charged] : []);
    assert.notEqual(b.paymentStatus, "refunded");
  });
}

// ---------- Money already in escrow ----------
async function escrowJob(fields) {
  const job = await completedJob(0, { paymentStatus: "held", paymentId: "unset", ...fields });
  const payment = db().collection("payments").doc();
  await payment.set({ bookingId: job.id, payerId: job.client.uid, payeeId: job.provider.uid, amountCents: 3500, status: "held" });
  await db().collection("bookings").doc(job.id).update({ paymentId: payment.id });
  return { ...job, payment };
}

test("a job already paid into escrow still pays out the old way when confirmed", async () => {
  const { client, provider, id, payment } = await escrowJob();
  await call("confirmCompletion", { bookingId: id }, client);

  const b = await bookingOf(id);
  assert.equal(b.status, "closed");
  assert.equal(b.paymentStatus, "released");
  assert.equal(await balanceOf(provider.uid), 3150);
  assert.equal((await payment.get()).get("status"), "released");
});

test("an escrow job still pays out when it closes automatically", async () => {
  const { provider, id } = await escrowJob({ completedAt: Timestamp.fromMillis(Date.now() - 49 * HOUR) });
  await bookingHousekeeping.run({});
  assert.equal((await bookingOf(id)).paymentStatus, "released");
  assert.equal(await balanceOf(provider.uid), 3150);
});

test("an escrow job in dispute can still be refunded to the client", async () => {
  const admin = await signUp("admin");
  const { client, provider, id } = await escrowJob();
  await call("raiseDispute", { bookingId: id, reason: "The tap still leaks badly" }, client);
  await call("resolveDispute", { bookingId: id, outcome: "refund", providerPercent: null, note: "Reviewed" }, admin);

  const b = await bookingOf(id);
  assert.equal(b.status, "cancelled");
  assert.equal(b.paymentStatus, "refunded");
  assert.equal(await balanceOf(client.uid), 3500);
  assert.equal(await balanceOf(provider.uid), 0);
});

test("a cancelled escrow booking is still refunded", async () => {
  const { client, id } = await escrowJob({ status: "confirmed" });
  const { refundCents } = await call("cancelBooking", { bookingId: id, reason: "Plans changed" }, client);
  assert.equal(refundCents, 3500);
  assert.equal(await balanceOf(client.uid), 3500);
});

// ---------- Top-ups ----------
async function topUp(uid, status, fields = {}) {
  const ref = db().collection("payments").doc();
  await ref.set({ purpose: "topup", payerId: uid, amountCents: 1000, status: "initiated", pollUrl: `${paynowUrl}/${encodeURIComponent(status)}`, ...fields });
  return ref;
}

test("startTopUp rejects clients and amounts below the minimum", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  await assert.rejects(call("startTopUp", { amountCents: 1000, method: "ecocash", phone: "0771234567" }, client), { code: "PERMISSION_DENIED" });
  for (const amountCents of [99, 0, -500, 10.5, "1000"]) {
    await assert.rejects(call("startTopUp", { amountCents, method: "ecocash", phone: "0771234567" }, provider), { code: "INVALID_ARGUMENT" });
  }
});

test("a paid top-up credits the balance exactly once", async () => {
  const provider = await signUp("provider");
  await setBalance(provider.uid, -250);
  const payment = await topUp(provider.uid, "Paid");

  assert.deepEqual(await call("checkPayment", { paymentId: payment.id }, provider), { status: "paid" });
  assert.deepEqual(await call("checkPayment", { paymentId: payment.id }, provider), { status: "paid" });

  assert.equal(await balanceOf(provider.uid), 750);
  assert.deepEqual((await walletTxns(provider.uid)).map((t) => [t.type, t.amountCents]), [["topup", 1000]]);
  assert.equal((await db().collection("revenue").where("bookingId", "==", payment.id).get()).size, 0);
});

test("topping up unblocks a provider who owes money", async () => {
  const { client, provider, id } = await completedJob(0);
  await call("confirmCompletion", { bookingId: id }, client);
  const payment = await topUp(provider.uid, "Paid");
  await call("checkPayment", { paymentId: payment.id }, provider);

  const next = await newBooking(client, provider);
  await call("respondToBooking", { bookingId: next, accept: true, feeCents: 1000 }, provider);
  assert.equal((await bookingOf(next)).status, "awaiting_payment");
});

test("a failed top-up credits nothing, and an unfinished one stays open", async () => {
  const provider = await signUp("provider");
  const failed = await topUp(provider.uid, "Cancelled");
  assert.deepEqual(await call("checkPayment", { paymentId: failed.id }, provider), { status: "failed" });
  const waiting = await topUp(provider.uid, "Sent");
  assert.deepEqual(await call("checkPayment", { paymentId: waiting.id }, provider), { status: "initiated" });
  assert.equal(await balanceOf(provider.uid), 0);
});

test("nobody else can settle a provider's top-up", async () => {
  const [provider, other] = await Promise.all([signUp("provider"), signUp("provider")]);
  const payment = await topUp(provider.uid, "Paid");
  await assert.rejects(call("checkPayment", { paymentId: payment.id }, other), { code: "PERMISSION_DENIED" });
  assert.equal(await balanceOf(provider.uid), 0);
});
