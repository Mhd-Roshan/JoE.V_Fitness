const functions = require("firebase-functions");
const admin = require("firebase-admin");
const Razorpay = require("razorpay");

admin.initializeApp();

// Initialize Razorpay with your live keys
// WARNING: Do NOT expose this secret key anywhere else!
const razorpay = new Razorpay({
  key_id: "rzp_live_TW1gk81ITSEDXf",
  key_secret: "Em3E25wSoR7Cd2ffIgsmZQHa",
});

exports.createRazorpaySubscription = functions.https.onCall(async (data, context) => {
  // Ensure the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be logged in to create a subscription."
    );
  }

  const { planId, totalCount } = data;

  if (!planId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a planId."
    );
  }

  try {
    // Create a subscription on Razorpay
    const subscriptionParams = {
      plan_id: planId,
      customer_notify: 1,
      total_count: totalCount || 12, // Default to 12 billing cycles if not provided
    };

    const subscription = await razorpay.subscriptions.create(subscriptionParams);

    return {
      success: true,
      subscriptionId: subscription.id,
      shortUrl: subscription.short_url,
    };
  } catch (error) {
    console.error("Error creating Razorpay subscription:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Unable to create Razorpay subscription."
    );
  }
});
