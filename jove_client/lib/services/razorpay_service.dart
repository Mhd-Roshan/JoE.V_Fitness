import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RazorpayService {
  static final RazorpayService instance = RazorpayService._internal();
  RazorpayService._internal();

  late Razorpay _razorpay;
  bool _isInitialized = false;

  // Default test API key
  static const String defaultKeyId = 'rzp_test_TUIFsntsNuezHz';
  // Note: The Razorpay secret key is: 37WG7evVDqNTBXrt06Nqugqn
  // Important: Secret keys should NEVER be exposed in the frontend app in production.
  // It is kept here as a reference for your backend/Firebase Functions signature verification.

  Function(PaymentSuccessResponse response)? _onSuccess;
  Function(PaymentFailureResponse response)? _onError;
  Function(ExternalWalletResponse response)? _onWallet;

  void initialize({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) {
    if (_isInitialized) {
      _razorpay.clear();
    }

    _onSuccess = onSuccess;
    _onError = onError;
    _onWallet = onExternalWallet;

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _isInitialized = true;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("Razorpay Payment Success: ${response.paymentId}");
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint(
      "Razorpay Payment Error: ${response.code} - ${response.message}",
    );
    _onError?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("Razorpay External Wallet: ${response.walletName}");
    _onWallet?.call(response);
  }

  /// Opens the Razorpay native checkout modal
  void openCheckout({
    required num amount, // in Rupees (will be multiplied by 100 for paise)
    required String packageName,
    required String userEmail,
    required String userPhone,
    required String userName,
    String? keyId,
    Map<String, dynamic>? notes,
  }) {
    final int amountInPaise = (amount * 100).toInt();

    final options = {
      'key': keyId ?? defaultKeyId,
      'amount': amountInPaise,
      'name': 'JoE.V Fitness',
      'description': '$packageName Membership Plan',
      'timeout': 300, // 5 minutes
      'prefill': {
        'contact': userPhone.isNotEmpty ? userPhone : '9876543210',
        'email': userEmail.isNotEmpty ? userEmail : 'athlete@jovefitness.com',
        'name': userName.isNotEmpty ? userName : 'Athlete',
      },
      'theme': {
        'color': '#BB0013', // Jove Fitness Brand Red
      },
      'notes': {
        'appName': 'JoE.V Fitness',
        'packageName': packageName,
        ...?notes,
      },
      'retry': {'enabled': true, 'max_count': 3},
      'send_sms_hash': true,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error opening Razorpay checkout: $e");
    }
  }

  /// Saves the successful subscription & payment record to Firestore
  static Future<void> recordSuccessfulSubscription({
    required String uid,
    required Map<String, dynamic> packageData,
    required String packageId,
    required PaymentSuccessResponse response,
    required bool autoRenew,
  }) async {
    final now = DateTime.now();
    final String billingCycle = (packageData['billingCycle'] ?? 'MONTHLY')
        .toString()
        .toUpperCase();

    // Calculate expiry date based on billing cycle
    DateTime expiryDate;
    if (billingCycle.contains('YEAR') || billingCycle.contains('ANNUAL')) {
      expiryDate = DateTime(now.year + 1, now.month, now.day);
    } else if (billingCycle.contains('6') || billingCycle.contains('HALF')) {
      expiryDate = DateTime(now.year, now.month + 6, now.day);
    } else if (billingCycle.contains('3') || billingCycle.contains('QUARTER')) {
      expiryDate = DateTime(now.year, now.month + 3, now.day);
    } else {
      expiryDate = DateTime(now.year, now.month + 1, now.day);
    }

    final double price = (packageData['price'] as num?)?.toDouble() ?? 0.0;
    final String planName = packageData['name'] ?? 'Premium Plan';

    final Map<String, dynamic> subscriptionData = {
      'packageId': packageId,
      'planName': planName,
      'packageName': billingCycle,
      'price': price,
      'status': 'Active',
      'autoRenew': autoRenew,
      'paymentMethod': 'Razorpay',
      'paymentId': response.paymentId ?? '',
      'orderId': response.orderId ?? '',
      'signature': response.signature ?? '',
      'startDate': FieldValue.serverTimestamp(),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final Map<String, dynamic> paymentHistoryItem = {
      'paymentId': response.paymentId ?? '',
      'orderId': response.orderId ?? '',
      'planName': planName,
      'billingCycle': billingCycle,
      'amount': price,
      'currency': 'INR',
      'paymentMethod': 'Razorpay',
      'status': 'Success',
      'timestamp': FieldValue.serverTimestamp(),
      'packageId': packageId,
    };

    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);
    DocumentReference historyRef = userRef
        .collection('payment_history')
        .doc(
          response.paymentId ??
              DateTime.now().millisecondsSinceEpoch.toString(),
        );

    batch.set(userRef, {
      'subscription': subscriptionData,
      'hasActiveSubscription': true,
      'packageName': planName,
      'packageBillingCycle': billingCycle,
    }, SetOptions(merge: true));

    batch.set(historyRef, paymentHistoryItem);

    await batch.commit();
  }

  void dispose() {
    if (_isInitialized) {
      _razorpay.clear();
      _isInitialized = false;
    }
  }
}
