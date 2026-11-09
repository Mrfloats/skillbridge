// Helpers shared by the emulator tests. See direct-pay.test.js for how to run them.
const assert = require("node:assert/strict");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

const PROJECT = process.env.GCLOUD_PROJECT;
const db = () => getFirestore();
const HOUR = 3600 * 1000;

let counter = 0;
const unique = () => `${Date.now()}${++counter}`;

async function signUp(role) {
  const email = `${role}${unique()}@example.com`;
  const authUrl = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1`;
  const post = async (path) => {
    const res = await fetch(`${authUrl}/${path}?key=fake`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password: "password123", returnSecureToken: true }),
    });
    return res.json();
  };
  const { localId: uid, idToken } = await post("accounts:signUp");
  await db().collection("users").doc(uid).set({ role, email, fullName: `Test ${role}` });
  if (role === "provider") await db().collection("providers").doc(uid).set({ completedJobs: 0 });
  if (role !== "admin") return { uid, token: idToken };
  await getAuth().setCustomUserClaims(uid, { admin: true });
  return { uid, token: (await post("accounts:signInWithPassword")).idToken };
}

async function call(name, data, user) {
  const res = await fetch(`http://127.0.0.1:5001/${PROJECT}/europe-west1/${name}`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${user.token}` },
    body: JSON.stringify({ data }),
  });
  const json = await res.json();
  if (json.error) throw Object.assign(new Error(json.error.message), { code: json.error.status });
  return json.result;
}

const setBalance = (uid, balanceCents) => db().collection("wallets").doc(uid).set({ uid, balanceCents });
const balanceOf = async (uid) => (await db().collection("wallets").doc(uid).get()).get("balanceCents") ?? 0;
const bookingOf = async (id) => (await db().collection("bookings").doc(id).get()).data();

async function walletTxns(uid) {
  const snap = await db().collection("wallets").doc(uid).collection("transactions").get();
  return snap.docs.map((d) => d.data());
}

async function revenueFor(bookingId) {
  const snap = await db().collection("revenue").where("bookingId", "==", bookingId).get();
  return snap.docs.map((d) => d.get("commissionCents"));
}

/** Creates a booking and waits for its create trigger, which would overwrite seeded fields. */
async function newBooking(client, provider, fields = {}) {
  const ref = db().collection("bookings").doc();
  await ref.set({
    clientId: client.uid,
    clientName: "Test Client",
    providerId: provider.uid,
    providerName: "Test Provider",
    serviceTitle: "Plumbing",
    serviceDate: Timestamp.fromMillis(Date.now() + 72 * HOUR),
    timeSlot: `slot-${unique()}`,
    status: "pending",
    createdAt: Timestamp.now(),
  });
  for (let i = 0; !(await ref.get()).get("chatId"); i++) {
    assert.ok(i < 150, "onBookingCreated did not run");
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  if (Object.keys(fields).length) await ref.update(fields);
  return ref.id;
}

/** Sends a request to Firestore as the given user, the way the app does, and returns the HTTP status. */
async function asUser(user, method, path, body) {
  const url = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${path}`;
  const res = await fetch(url, {
    method,
    headers: { authorization: `Bearer ${user.token}`, "content-type": "application/json" },
    body: body && JSON.stringify(body),
  });
  return res.status;
}

module.exports = { PROJECT, db, HOUR, unique, signUp, call, setBalance, balanceOf, bookingOf, walletTxns, revenueFor, newBooking, asUser };
