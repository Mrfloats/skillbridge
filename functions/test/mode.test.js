// Switching between client and provider mode, checked against the Firestore rules on the
// emulators with `npm test`. Requests are sent as the signed-in user, the way the app sends them.
const { test } = require("node:test");
const assert = require("node:assert/strict");

require("../lib/index.js");
const { PROJECT, db, signUp } = require("./helpers");

const docName = (path) => `projects/${PROJECT}/databases/(default)/documents/${path}`;

/** Commits several writes at once as the user, like a Firestore batch, and returns the HTTP status. */
async function batchAs(user, writes) {
  const url = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${PROJECT}/databases/(default)/documents:commit`;
  const res = await fetch(url, {
    method: "POST",
    headers: { authorization: `Bearer ${user.token}`, "content-type": "application/json" },
    body: JSON.stringify({ writes }),
  });
  return res.status;
}

const updateUser = (uid, fields) => ({
  update: { name: docName(`users/${uid}`), fields },
  updateMask: { fieldPaths: Object.keys(fields) },
});

/** The provider profile the app creates, matching AuthService.becomeProvider. */
const newProviderProfile = (uid) => ({
  update: {
    name: docName(`providers/${uid}`),
    fields: {
      fullName: { stringValue: "Test client" },
      verificationStatus: { stringValue: "pending" },
      isVerified: { booleanValue: false },
      isAvailable: { booleanValue: true },
      avgRating: { integerValue: "0" },
      reviewCount: { integerValue: "0" },
      completedJobs: { integerValue: "0" },
    },
  },
  currentDocument: { exists: false },
});

test("a client can become a provider, and their profile starts unverified", async () => {
  const client = await signUp("client");
  const status = await batchAs(client, [
    newProviderProfile(client.uid),
    updateUser(client.uid, { providerProfile: { booleanValue: true }, mode: { stringValue: "provider" } }),
  ]);
  assert.equal(status, 200);
  const u = (await db().collection("users").doc(client.uid).get()).data();
  assert.equal(u.mode, "provider");
  assert.equal(u.providerProfile, true);
  assert.equal(u.role, "client", "the sign-up role does not change");
  assert.equal((await db().collection("providers").doc(client.uid).get()).get("isVerified"), false);
});

test("a client cannot create a provider profile that is already verified", async () => {
  const client = await signUp("client");
  const verified = newProviderProfile(client.uid);
  verified.update.fields.isVerified = { booleanValue: true };
  verified.update.fields.verificationStatus = { stringValue: "approved" };
  const status = await batchAs(client, [verified, updateUser(client.uid, { providerProfile: { booleanValue: true } })]);
  assert.equal(status, 403);
  assert.equal((await db().collection("providers").doc(client.uid).get()).exists, false);
});

test("an account cannot claim a provider profile it does not have", async () => {
  const client = await signUp("client");
  assert.equal(await batchAs(client, [updateUser(client.uid, { providerProfile: { booleanValue: true } })]), 403);
});

test("anyone can switch between client and provider mode, but not to any other mode", async () => {
  const provider = await signUp("provider");
  assert.equal(await batchAs(provider, [updateUser(provider.uid, { mode: { stringValue: "client" } })]), 200);
  assert.equal(await batchAs(provider, [updateUser(provider.uid, { mode: { stringValue: "provider" } })]), 200);
  assert.equal(await batchAs(provider, [updateUser(provider.uid, { mode: { stringValue: "admin" } })]), 403);
  assert.equal(await batchAs(provider, [updateUser(provider.uid, { role: { stringValue: "admin" } })]), 403, "the role itself stays locked");
  assert.equal((await db().collection("users").doc(provider.uid).get()).get("mode"), "provider");
});

test("someone else cannot switch a user's mode", async () => {
  const [client, stranger] = await Promise.all([signUp("client"), signUp("client")]);
  assert.equal(await batchAs(stranger, [updateUser(client.uid, { mode: { stringValue: "provider" } })]), 403);
});
