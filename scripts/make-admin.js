// Bootstrap the first admin. Usage (from the functions folder, with a service-account key):
//   GOOGLE_APPLICATION_CREDENTIALS=key.json node ../scripts/make-admin.js admin@example.com
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");

(async () => {
  const email = process.argv[2];
  if (!email) throw new Error("Pass the admin's email address");
  initializeApp();
  const user = await getAuth().getUserByEmail(email);
  await getAuth().setCustomUserClaims(user.uid, { admin: true });
  await getFirestore().collection("users").doc(user.uid).set({ role: "admin" }, { merge: true });
  console.log(`${email} is now an admin. They must sign out and back in.`);
})();
