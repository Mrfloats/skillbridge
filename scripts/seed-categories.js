// Seeds service categories. Usage: GOOGLE_APPLICATION_CREDENTIALS=key.json node ../scripts/seed-categories.js
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const CATEGORIES = [
  ["plumbing", "Plumbing", "plumbing"], ["electrical", "Electrical", "electrical_services"],
  ["carpentry", "Carpentry", "carpenter"], ["painting", "Painting", "format_paint"],
  ["landscaping", "Landscaping & Gardening", "yard"], ["cleaning", "Cleaning", "cleaning_services"],
  ["building", "Building & Masonry", "construction"], ["appliance", "Appliance Repair", "build"],
  ["welding", "Welding", "hardware"], ["solar", "Solar Installation", "solar_power"],
];
(async () => {
  initializeApp();
  const db = getFirestore();
  const batch = db.batch();
  CATEGORIES.forEach(([id, name, icon], i) => batch.set(db.collection("categories").doc(id), { name, icon, order: i, isActive: true }));
  await batch.commit();
  console.log(`Seeded ${CATEGORIES.length} categories`);
})();
