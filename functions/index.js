const functions = require("firebase-functions");
const admin = require("firebase-admin");
const Razorpay = require("razorpay");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

// ---------------------------------------------------------------------------
// Razorpay keys are read from functions/.env (never hard-code them here):
//   RAZORPAY_KEY_ID=rzp_live_xxx
//   RAZORPAY_KEY_SECRET=xxxx
// ---------------------------------------------------------------------------
let _razorpay = null;
function getRazorpay() {
  if (!_razorpay) {
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keyId || !keySecret) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Payment gateway is not configured."
      );
    }
    _razorpay = new Razorpay({ key_id: keyId, key_secret: keySecret });
  }
  return _razorpay;
}

function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in."
    );
  }
  return context.auth.uid;
}

const ENTRY_PASS_RUPEES = 99;

function normalizeEmail(v) {
  return (v || "").toString().trim().toLowerCase();
}

// ---------------------------------------------------------------------------
// 1. ACCOUNT LOOKUP (used by sign up / login so the app no longer needs to
//    read the whole `users` collection).
//    - Not signed in  -> only yes/no answers are returned.
//    - Signed in      -> also returns the matching account's uid/provider/phone.
// ---------------------------------------------------------------------------
exports.lookupAccount = functions.https.onCall(async (data, context) => {
  const phone = (data && data.phone ? String(data.phone) : "").trim();
  const email = normalizeEmail(data && data.email);
  const signedIn = !!context.auth;

  const result = {
    userByPhone: false,
    userByEmail: false,
    pendingByPhone: false,
    pendingByEmail: false,
  };

  if (phone) {
    const snap = await db
      .collection("users")
      .where("phone", "==", phone)
      .where("role", "==", "client")
      .limit(1)
      .get();
    if (!snap.empty) {
      result.userByPhone = true;
      if (signedIn) {
        const d = snap.docs[0];
        result.userByPhoneInfo = {
          uid: d.id,
          authProvider: d.data().authProvider || "phone",
          phone: d.data().phone || "",
        };
      }
    }
    const pending = await db.collection("pending_users").doc(phone).get();
    result.pendingByPhone = pending.exists;
  }

  if (email) {
    // Exact match first, then a case-insensitive scan for old data.
    let found = null;
    const exact = await db
      .collection("users")
      .where("email", "==", email)
      .where("role", "==", "client")
      .limit(1)
      .get();
    if (!exact.empty) {
      found = exact.docs[0];
    } else {
      const all = await db
        .collection("users")
        .where("role", "==", "client")
        .get();
      found =
        all.docs.find((d) => normalizeEmail(d.data().email) === email) || null;
    }
    if (found) {
      result.userByEmail = true;
      if (signedIn) {
        result.userByEmailInfo = {
          uid: found.id,
          authProvider: found.data().authProvider || "phone",
          phone: found.data().phone || "",
        };
      }
    }

    const pendingExact = await db
      .collection("pending_users")
      .where("email", "==", email)
      .limit(1)
      .get();
    if (!pendingExact.empty) {
      result.pendingByEmail = true;
    } else {
      const allPending = await db.collection("pending_users").get();
      result.pendingByEmail = allPending.docs.some(
        (d) => normalizeEmail(d.data().email) === email
      );
    }
  }

  return result;
});

// ---------------------------------------------------------------------------
// 2. CONSUME PENDING SIGN-UP (called right after OTP / Google sign in).
//    Returns the saved name/email/phone and removes the pending entry, so the
//    app can create the real `users` document with the correct name.
// ---------------------------------------------------------------------------
exports.consumePending = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const token = context.auth.token || {};
  const tokenPhone = token.phone_number || "";
  const tokenEmail = normalizeEmail(token.email);

  // The caller may only claim pending data that belongs to their own login.
  const phone = tokenPhone;
  const email = tokenEmail;

  let name = "";
  let savedEmail = "";
  let savedPhone = "";
  const toDelete = [];

  if (phone) {
    const doc = await db.collection("pending_users").doc(phone).get();
    if (doc.exists) {
      const d = doc.data() || {};
      name = d.name || name;
      savedEmail = d.email || savedEmail;
      savedPhone = d.phone || phone;
      toDelete.push(doc.ref);
    }
  }

  if (email && !name) {
    const snap = await db.collection("pending_users").get();
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      if (normalizeEmail(d.email) === email) {
        name = d.name || name;
        savedEmail = d.email || savedEmail;
        savedPhone = d.phone || savedPhone;
        toDelete.push(doc.ref);
        break;
      }
    }
  }

  // Old/orphaned client document for the same phone (dev/test leftovers).
  if (!name && phone) {
    const orphan = await db
      .collection("users")
      .where("phone", "==", phone)
      .where("role", "==", "client")
      .limit(5)
      .get();
    for (const doc of orphan.docs) {
      if (doc.id === uid) continue;
      const d = doc.data() || {};
      name = d.fullName || d.name || "";
      savedEmail = d.email || savedEmail;
      savedPhone = d.phone || savedPhone;
      toDelete.push(doc.ref);
      break;
    }
  }

  // Final fallback: the name Firebase Auth already knows.
  if (!name) {
    name = token.name || "";
  }

  await Promise.all(toDelete.map((ref) => ref.delete()));

  return {
    name: name || "",
    email: savedEmail || "",
    phone: savedPhone || phone || "",
  };
});

// ---------------------------------------------------------------------------
// 3. REMOVE STALE GOOGLE DOC (Google login found the same email under another
//    uid that is a leftover Google account). Only deletes documents that are
//    clearly stale Google docs with the caller's own email.
// ---------------------------------------------------------------------------
exports.removeStaleGoogleDoc = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const docId = data && data.docId ? String(data.docId) : "";
  const email = normalizeEmail(context.auth.token.email);
  if (!docId || docId === uid || !email) {
    throw new functions.https.HttpsError("invalid-argument", "Bad request.");
  }
  const ref = db.collection("users").doc(docId);
  const snap = await ref.get();
  if (!snap.exists) return { removed: false };
  const d = snap.data() || {};
  if (
    d.role === "client" &&
    (d.authProvider || "phone") !== "phone" &&
    normalizeEmail(d.email) === email
  ) {
    await ref.delete();
    return { removed: true };
  }
  return { removed: false };
});

// ---------------------------------------------------------------------------
// 4. PAYMENTS
// ---------------------------------------------------------------------------

// Creates a Razorpay order for either the Rs.99 entry pass or a package.
// The AMOUNT is decided here on the server - the app cannot choose it.
exports.createPaymentOrder = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const type = data && data.type;
  const razorpay = getRazorpay();

  let amountRupees = 0;
  let packageId = null;
  let packageName = "";

  if (type === "entry_pass") {
    amountRupees = ENTRY_PASS_RUPEES;
  } else if (type === "package") {
    packageId = data.packageId ? String(data.packageId) : "";
    if (!packageId) {
      throw new functions.https.HttpsError("invalid-argument", "packageId required.");
    }
    const pkg = await db.collection("packages").doc(packageId).get();
    if (!pkg.exists) {
      throw new functions.https.HttpsError("not-found", "Package not found.");
    }
    amountRupees = Number(pkg.data().price) || 0;
    packageName = pkg.data().name || "";
    if (amountRupees <= 0) {
      throw new functions.https.HttpsError("failed-precondition", "Invalid package price.");
    }
  } else {
    throw new functions.https.HttpsError("invalid-argument", "Unknown payment type.");
  }

  const amountPaise = Math.round(amountRupees * 100);
  const order = await razorpay.orders.create({
    amount: amountPaise,
    currency: "INR",
    receipt: `${type}_${uid}`.substring(0, 40),
    notes: { uid, type, packageId: packageId || "" },
  });

  await db.collection("orders").doc(order.id).set({
    uid,
    type,
    packageId,
    packageName,
    amount: amountRupees,
    amountPaise,
    kind: "order",
    status: "created",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    orderId: order.id,
    amountPaise,
    keyId: process.env.RAZORPAY_KEY_ID,
  };
});

// Auto-renew (subscription) payments.
exports.createRazorpaySubscription = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const { planId, totalCount } = data || {};

  if (!planId) {
    throw new functions.https.HttpsError("invalid-argument", "The function must be called with a planId.");
  }

  const pkg = await db.collection("packages").doc(String(planId)).get();
  if (!pkg.exists) {
    throw new functions.https.HttpsError("not-found", "Package not found.");
  }

  try {
    const razorpay = getRazorpay();
    const subscription = await razorpay.subscriptions.create({
      plan_id: planId,
      customer_notify: 1,
      total_count: totalCount || 12,
    });

    await db.collection("orders").doc(subscription.id).set({
      uid,
      type: "package",
      packageId: String(planId),
      packageName: pkg.data().name || "",
      amount: Number(pkg.data().price) || 0,
      kind: "subscription",
      status: "created",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      subscriptionId: subscription.id,
      shortUrl: subscription.short_url,
    };
  } catch (error) {
    console.error("Error creating Razorpay subscription:", error);
    throw new functions.https.HttpsError("internal", "Unable to create Razorpay subscription.");
  }
});

function expiryFor(billingCycleRaw) {
  const billingCycle = String(billingCycleRaw || "MONTHLY").toUpperCase();
  const now = new Date();
  const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (billingCycle.includes("YEAR") || billingCycle.includes("ANNUAL")) {
    d.setFullYear(d.getFullYear() + 1);
  } else if (billingCycle.includes("6") || billingCycle.includes("HALF")) {
    d.setMonth(d.getMonth() + 6);
  } else if (billingCycle.includes("3") || billingCycle.includes("QUARTER")) {
    d.setMonth(d.getMonth() + 3);
  } else {
    d.setMonth(d.getMonth() + 1);
  }
  return { date: d, billingCycle };
}

// Verifies the Razorpay signature and ONLY THEN marks the user as paid.
exports.verifyPayment = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const { orderId, subscriptionId, paymentId, signature } = data || {};
  const refId = orderId || subscriptionId;

  if (!refId || !paymentId || !signature) {
    throw new functions.https.HttpsError("invalid-argument", "Missing payment details.");
  }

  const secret = process.env.RAZORPAY_KEY_SECRET;
  if (!secret) {
    throw new functions.https.HttpsError("failed-precondition", "Payment gateway is not configured.");
  }

  const orderRef = db.collection("orders").doc(String(refId));
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Order not found.");
  }
  const order = orderSnap.data();
  if (order.uid !== uid) {
    throw new functions.https.HttpsError("permission-denied", "This order is not yours.");
  }
  if (order.status === "paid") {
    return { success: true, alreadyProcessed: true };
  }

  // Order payments:        HMAC(orderId + "|" + paymentId)
  // Subscription payments: HMAC(paymentId + "|" + subscriptionId)
  const payload =
    order.kind === "subscription"
      ? `${paymentId}|${refId}`
      : `${refId}|${paymentId}`;
  const expected = crypto.createHmac("sha256", secret).update(payload).digest("hex");

  const a = Buffer.from(expected);
  const b = Buffer.from(String(signature));
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    throw new functions.https.HttpsError("permission-denied", "Payment signature is invalid.");
  }

  const userRef = db.collection("users").doc(uid);
  const historyRef = userRef.collection("payment_history").doc(String(paymentId));
  const batch = db.batch();
  const FV = admin.firestore.FieldValue;

  if (order.type === "entry_pass") {
    const today = new Date().toISOString().substring(0, 10);
    batch.set(
      userRef,
      {
        hasPaidEntryFee: true,
        entryFeePaidAt: FV.serverTimestamp(),
        entryFeePaymentId: String(paymentId),
        lastAppAccessDate: today,
      },
      { merge: true }
    );
    batch.set(historyRef, {
      paymentId: String(paymentId),
      orderId: String(refId),
      planName: "App Access Pass (\u20B999)",
      billingCycle: "ACCESS_PASS",
      amount: Number(order.amount) || ENTRY_PASS_RUPEES,
      currency: "INR",
      paymentMethod: "Razorpay",
      status: "Success",
      timestamp: FV.serverTimestamp(),
    });
  } else {
    const pkgSnap = await db.collection("packages").doc(order.packageId).get();
    const pkg = pkgSnap.exists ? pkgSnap.data() : {};
    const { date, billingCycle } = expiryFor(pkg.billingCycle);
    const planName = pkg.name || order.packageName || "Premium Plan";
    const price = Number(pkg.price) || Number(order.amount) || 0;

    // One-time orders never auto-renew; Razorpay subscriptions always do.
    const autoRenew = order.kind === "subscription";

    batch.set(
      userRef,
      {
        subscription: {
          packageId: order.packageId,
          planName,
          packageName: billingCycle,
          price,
          status: "Active",
          autoRenew,
          paymentMethod: "Razorpay",
          paymentId: String(paymentId),
          orderId: String(refId),
          startDate: FV.serverTimestamp(),
          expiryDate: admin.firestore.Timestamp.fromDate(date),
          updatedAt: FV.serverTimestamp(),
        },
        hasActiveSubscription: true,
        packageName: planName,
        packageBillingCycle: billingCycle,
      },
      { merge: true }
    );
    batch.set(historyRef, {
      paymentId: String(paymentId),
      orderId: String(refId),
      planName,
      billingCycle,
      amount: price,
      currency: "INR",
      paymentMethod: "Razorpay",
      status: "Success",
      timestamp: FV.serverTimestamp(),
      packageId: order.packageId,
    });
  }

  batch.update(orderRef, {
    status: "paid",
    paymentId: String(paymentId),
    paidAt: FV.serverTimestamp(),
  });
  await batch.commit();

  return { success: true };
});
