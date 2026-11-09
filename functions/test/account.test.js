// End-to-end tests of account deletion and support messages, run against the Firebase
// emulators with `npm test`.
const { test } = require("node:test");
const assert = require("node:assert/strict");

require("../lib/index.js");
const { getAuth } = require("firebase-admin/auth");
const { db, signUp, call, setBalance, bookingOf, newBooking, asUser } = require("./helpers");

const userExists = (uid) => getAuth().getUser(uid).then(() => true, () => false);
const count = async (query) => (await query.get()).size;

// ---------- Deleting an account ----------
for (const [role, status] of [["client", "confirmed"], ["provider", "pending"], ["client", "disputed"], ["provider", "completed"]]) {
  test(`a ${role} with a ${status} booking cannot delete their account`, async () => {
    const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
    await newBooking(client, provider, { status, quotedFeeCents: 3500 });
    const user = role === "client" ? client : provider;
    await assert.rejects(call("deleteAccount", {}, user), { code: "FAILED_PRECONDITION", message: /booking that is still open/ });
    assert.equal(await userExists(user.uid), true);
    assert.equal((await db().collection("users").doc(user.uid).get()).get("deleted"), undefined);
  });
}

test("money on the balance, or owed, blocks deleting an account", async () => {
  const provider = await signUp("provider");
  await setBalance(provider.uid, 500);
  await assert.rejects(call("deleteAccount", {}, provider), { code: "FAILED_PRECONDITION", message: /Withdraw it first/ });
  await setBalance(provider.uid, -350);
  await assert.rejects(call("deleteAccount", {}, provider), { code: "FAILED_PRECONDITION", message: /Top up/ });
  await setBalance(provider.uid, 0);
  await db().collection("withdrawals").add({ userId: provider.uid, amountCents: 500, status: "pending" });
  await assert.rejects(call("deleteAccount", {}, provider), { code: "FAILED_PRECONDITION", message: /withdrawal/ });
  assert.equal(await userExists(provider.uid), true);
});

test("deleting a provider removes their login, details, ID documents and photos, and keeps job records", async () => {
  const [client, provider, other] = await Promise.all([signUp("client"), signUp("provider"), signUp("provider")]);
  const p = provider.uid;
  await db().collection("providers").doc(p).set({ fullName: "Real Name", phone: "+263771234567", bio: "Plumber", isVerified: true, isAvailable: true, avgRating: 4.5 }, { merge: true });
  await db().collection("providers").doc(p).collection("private").doc("id").set({ idPhoto: "x", selfie: "y" });
  await db().collection("providerServices").add({ providerId: p, title: "Plumbing" });
  await db().collection("providerServices").add({ providerId: other.uid, title: "Wiring" });
  await db().collection("images").add({ ownerId: p, data: "x" });
  await db().collection("images").add({ ownerId: other.uid, data: "x" });
  await db().collection("notifications").add({ userId: p, title: "Hi" });
  const closed = await newBooking(client, provider, { status: "closed", quotedFeeCents: 3500 });

  await call("deleteAccount", {}, provider);

  assert.equal(await userExists(p), false, "the login is gone");
  const u = (await db().collection("users").doc(p).get()).data();
  assert.equal(u.fullName, "Deleted user");
  assert.equal(u.email, "");
  assert.equal(u.deleted, true);
  assert.equal(u.role, "provider");
  const prov = (await db().collection("providers").doc(p).get()).data();
  assert.equal(prov.fullName, "Deleted user");
  assert.equal(prov.phone, "");
  assert.equal(prov.isAvailable, false, "no longer shows in search");
  assert.equal(prov.isVerified, false);
  assert.equal(await count(db().collection("providers").doc(p).collection("private")), 0, "ID documents are gone");
  assert.equal(await count(db().collection("providerServices").where("providerId", "==", p)), 0);
  assert.equal(await count(db().collection("images").where("ownerId", "==", p)), 0);
  assert.equal(await count(db().collection("notifications").where("userId", "==", p)), 0);

  assert.equal(await userExists(other.uid), true, "other users are untouched");
  assert.equal(await count(db().collection("providerServices").where("providerId", "==", other.uid)), 1);
  assert.equal(await count(db().collection("images").where("ownerId", "==", other.uid)), 1);
  assert.equal((await bookingOf(closed)).status, "closed", "the client keeps the job record");
});

test("a client with only finished bookings can delete their account", async () => {
  const [client, provider] = await Promise.all([signUp("client"), signUp("provider")]);
  await newBooking(client, provider, { status: "closed", quotedFeeCents: 3500 });
  await newBooking(client, provider, { status: "cancelled" });
  await db().collection("clientRatings").doc(client.uid).set({ avgRating: 4, reviewCount: 1, ratingSum: 4 });

  await call("deleteAccount", {}, client);
  assert.equal(await userExists(client.uid), false);
  assert.equal((await db().collection("clientRatings").doc(client.uid).get()).exists, false);
  assert.equal((await db().collection("users").doc(client.uid).get()).get("deleted"), true);
});

test("admins cannot delete their own account from the app", async () => {
  const admin = await signUp("admin");
  await assert.rejects(call("deleteAccount", {}, admin), { code: "FAILED_PRECONDITION", message: /another admin/ });
  assert.equal(await userExists(admin.uid), true);
});

// ---------- Support ----------
test("a user's support message reaches the admins, who can close it", async () => {
  const [client, admin] = await Promise.all([signUp("client"), signUp("admin")]);
  const { ticketId } = await call("contactSupport", { topic: "payment", message: "  My provider asked me to pay twice.  " }, client);

  const t = (await db().collection("supportTickets").doc(ticketId).get()).data();
  assert.equal(t.userId, client.uid);
  assert.equal(t.email, (await db().collection("users").doc(client.uid).get()).get("email"));
  assert.equal(t.topic, "payment");
  assert.equal(t.message, "My provider asked me to pay twice.");
  assert.equal(t.status, "open");

  await assert.rejects(call("resolveSupportTicket", { ticketId }, client), { code: "PERMISSION_DENIED" });
  await call("resolveSupportTicket", { ticketId, note: "We called you and sorted it out." }, admin);
  const done = (await db().collection("supportTickets").doc(ticketId).get()).data();
  assert.equal(done.status, "resolved");
  assert.equal(done.reply, "We called you and sorted it out.");
  await assert.rejects(call("resolveSupportTicket", { ticketId }, admin), { code: "FAILED_PRECONDITION" });

  const notes = await db().collection("notifications").where("userId", "==", client.uid).where("title", "==", "Support request closed").get();
  assert.equal(notes.size, 1, "the user is told");
  assert.equal(notes.docs[0].get("body"), "We called you and sorted it out.");
});

test("support messages need a topic and enough detail", async () => {
  const client = await signUp("client");
  await assert.rejects(call("contactSupport", { topic: "nonsense", message: "Something went wrong here" }, client), { code: "INVALID_ARGUMENT" });
  await assert.rejects(call("contactSupport", { topic: "other", message: "   help    " }, client), { code: "INVALID_ARGUMENT" });
  await assert.rejects(call("contactSupport", { topic: "other", message: "x".repeat(2001) }, client), { code: "INVALID_ARGUMENT" });
  assert.equal(await count(db().collection("supportTickets").where("userId", "==", client.uid)), 0);
});

test("only the sender and admins can read a support message, and nobody can edit it from the app", async () => {
  const [client, stranger, admin] = await Promise.all([signUp("client"), signUp("client"), signUp("admin")]);
  const { ticketId } = await call("contactSupport", { topic: "account", message: "I cannot change my phone number." }, client);
  const path = `supportTickets/${ticketId}`;
  assert.equal(await asUser(client, "GET", path), 200);
  assert.equal(await asUser(admin, "GET", path), 200);
  assert.equal(await asUser(stranger, "GET", path), 403);
  assert.equal(await asUser(client, "PATCH", path, { fields: { status: { stringValue: "resolved" } } }), 403);
});
