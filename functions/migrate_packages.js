const admin = require("firebase-admin");

// Initialize Firebase Admin with Application Default Credentials
// Or since it's running locally against the emulator/default project, we can just use default initialization
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

const PLAN_MAPPING = {
  4999: "plan_TW5SoV7sbb1LCv", // Package 1
  7999: "plan_TW5UDcSYTn5rV2", // Package 2
  9999: "plan_TW5VHz5TrDFJIO"  // Package 3
};

async function migratePackages() {
  console.log("Starting package migration...");
  const packagesRef = db.collection("packages");
  const snapshot = await packagesRef.get();

  if (snapshot.empty) {
    console.log("No packages found.");
    return;
  }

  const batch = db.batch();
  let migratedCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const price = data.price;
    const currentId = doc.id;

    // Check if it already starts with 'plan_'
    if (currentId.startsWith("plan_")) {
      console.log(`Package ${currentId} is already migrated.`);
      continue;
    }

    const newPlanId = PLAN_MAPPING[price];
    if (newPlanId) {
      console.log(`Migrating package: ${data.name} (${price}) -> New ID: ${newPlanId}`);
      
      // Create new document with Razorpay plan ID
      const newDocRef = packagesRef.doc(newPlanId);
      batch.set(newDocRef, data);

      // Delete old document
      const oldDocRef = packagesRef.doc(currentId);
      batch.delete(oldDocRef);
      
      migratedCount++;
    } else {
      console.log(`Warning: Could not find a mapping for package with price ${price}`);
    }
  }

  if (migratedCount > 0) {
    await batch.commit();
    console.log(`Successfully migrated ${migratedCount} packages!`);
  } else {
    console.log("No packages needed migration.");
  }
}

migratePackages().catch(console.error);
