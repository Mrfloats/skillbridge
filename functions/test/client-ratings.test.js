// End-to-end tests of providers rating clients (FR-8.5), run against the Firebase emulators
// with `npm test`. The Firestore rules are checked through the emulator's REST API, signed
// in as each user, the same way the app reaches Firestore.
const { test } = require("node:test");
const assert = require("node:assert/strict");

require("../lib/index.js");
const { db, HOUR, signUp, call, bookingOf, newBooking, asUser } = require("./helpers");

const ratingOf = async (clientId) => (await db().collection("clientRatings").doc(clientId).get()).data();

/** A client and provider whose job has closed. */
async function closedJob() {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  const id = await newBooking(client, provider, { status: "closed", quotedFeeCents: 3500 });
  return { client, provider, id };
}

test("a provider rates the client once a job closes", async () => {
  const { client, provider, id } = await closedJob();
  await call("rateClient", { bookingId: id, rating: 4 }, provider);

  assert.deepEqual(await ratingOf(client.uid), { ratingSum: 4, reviewCount: 1, avgRating: 4 });
  assert.equal((await bookingOf(id)).clientRated, true);
  const review = (await db().collection("clientReviews").doc(id).get()).data();
  assert.equal(review.rating, 4);
  assert.equal(review.providerId, provider.uid);
  assert.equal(review.clientId, client.uid);

  const notes = await db().collection("notifications").where("userId", "==", client.uid).where("title", "==", "New rating").get();
  assert.equal(notes.size, 1, "the client is told");
});

test("each job can be rated only once", async () => {
  const { client, provider, id } = await closedJob();
  await call("rateClient", { bookingId: id, rating: 5 }, provider);
  await assert.rejects(call("rateClient", { bookingId: id, rating: 1 }, provider), { code: "ALREADY_EXISTS" });
  assert.deepEqual(await ratingOf(client.uid), { ratingSum: 5, reviewCount: 1, avgRating: 5 });
});

test("ratings from several jobs average out, rounded to one decimal", async () => {
  const client = await signUp("client");
  for (const rating of [5, 4, 4]) {
    const provider = await signUp("provider");
    const id = await newBooking(client, provider, { status: "closed", quotedFeeCents: 3500 });
    await call("rateClient", { bookingId: id, rating }, provider);
  }
  assert.deepEqual(await ratingOf(client.uid), { ratingSum: 13, reviewCount: 3, avgRating: 4.3 });
});

test("a job can only be rated once it has closed", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  for (const status of ["pending", "confirmed", "completed", "disputed", "cancelled"]) {
    const id = await newBooking(client, provider, { status, quotedFeeCents: 3500 });
    await assert.rejects(call("rateClient", { bookingId: id, rating: 5 }, provider), { code: "FAILED_PRECONDITION" }, status);
  }
  assert.equal(await ratingOf(client.uid), undefined);
});

test("only the provider on the job can rate the client", async () => {
  const { client, id } = await closedJob();
  const otherProvider = await signUp("provider");
  await assert.rejects(call("rateClient", { bookingId: id, rating: 1 }, otherProvider), { code: "PERMISSION_DENIED" });
  await assert.rejects(call("rateClient", { bookingId: id, rating: 5 }, client), { code: "PERMISSION_DENIED" });
  await assert.rejects(call("rateClient", { bookingId: "no-such-booking", rating: 5 }, otherProvider), { code: "PERMISSION_DENIED" });
  assert.equal(await ratingOf(client.uid), undefined);
});

test("a rating must be a whole number of stars from 1 to 5", async () => {
  const { client, provider, id } = await closedJob();
  for (const rating of [0, 6, 4.5, "5", null]) {
    await assert.rejects(call("rateClient", { bookingId: id, rating }, provider), { code: "INVALID_ARGUMENT" }, String(rating));
  }
  await assert.rejects(call("rateClient", { rating: 5 }, provider), { code: "INVALID_ARGUMENT" });
  assert.equal(await ratingOf(client.uid), undefined);
});

// ---------- Firestore rules ----------
test("any signed-in user can see a client's rating, but nobody can change it from the app", async () => {
  const { client, provider, id } = await closedJob();
  await call("rateClient", { bookingId: id, rating: 2 }, provider);
  const stranger = await signUp("provider");

  assert.equal(await asUser(stranger, "GET", `clientRatings/${client.uid}`), 200);
  const fiveStars = { fields: { ratingSum: { integerValue: "5" }, reviewCount: { integerValue: "1" }, avgRating: { doubleValue: 5 } } };
  assert.equal(await asUser(client, "PATCH", `clientRatings/${client.uid}`, fiveStars), 403);
  assert.equal(await asUser(client, "DELETE", `clientRatings/${client.uid}`), 403);
  assert.equal((await ratingOf(client.uid)).avgRating, 2);
});

test("each rating is visible only to the provider who gave it", async () => {
  const { client, provider, id } = await closedJob();
  await call("rateClient", { bookingId: id, rating: 3 }, provider);
  const stranger = await signUp("provider");

  assert.equal(await asUser(provider, "GET", `clientReviews/${id}`), 200);
  assert.equal(await asUser(client, "GET", `clientReviews/${id}`), 403);
  assert.equal(await asUser(stranger, "GET", `clientReviews/${id}`), 403);
  assert.equal(await asUser(provider, "PATCH", `clientReviews/${id}`, { fields: { rating: { integerValue: "5" } } }), 403);
});

test("a client cannot create a booking already marked as rated", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  await db().collection("providers").doc(provider.uid).set({ isVerified: true }, { merge: true });
  const booking = (extra) => ({
    fields: {
      clientId: { stringValue: client.uid },
      providerId: { stringValue: provider.uid },
      status: { stringValue: "pending" },
      serviceDate: { timestampValue: new Date(Date.now() + 72 * HOUR).toISOString() },
      ...extra,
    },
  });
  assert.equal(await asUser(client, "POST", "bookings", booking({ clientRated: { booleanValue: true } })), 403);
  assert.equal(await asUser(client, "POST", "bookings", booking()), 200, "the same booking without the flag is allowed");
});
