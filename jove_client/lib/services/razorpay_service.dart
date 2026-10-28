import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RazorpayService {
  static final RazorpayService instance = RazorpayService._internal();
  RazorpayService._internal();

  late Razorpay _razorpay;
  bool _isInitialized = false;

  // Default API key
  static const String defaultKeyId = 'rzp_live_TW1gk81ITSEDXf';

  // Remembered between openCheckout() and verifyPayment()
  String? _pendingOrderId;
  String? _pendingSubscriptionId;

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

  /// Opens the Razorpay native checkout modal.
  /// The amount is decided by the server (Cloud Function), not by the app.
  /// Returns true if the checkout was opened, false if something failed.
  Future<bool> openCheckout({
    required num amount, // only used for display/validation, server decides
    required String packageName,
    required String userEmail,
    required String userPhone,
    required String userName,
    String? keyId,
    Map<String, dynamic>? notes,
  }) async {
    String currentKeyId = keyId ?? defaultKeyId;
    _pendingOrderId = null;
    _pendingSubscriptionId = null;

    try {
      final options = <String, dynamic>{
        'key': currentKeyId,
        'name': 'JoE.V Fitness',
        'description': '$packageName Membership Plan',
        'image':
            'https://firebasestorage.googleapis.com/v0/b/joev-fintess.firebasestorage.app/o/Document%20from%20(1).png?alt=media',
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

      // If Auto-Renew is requested and it's a package purchase, use Subscriptions API
      if (notes != null &&
          notes['autoRenew'] == true &&
          notes.containsKey('packageId')) {
        final planId =
            notes['packageId']; // We assume the packageId in Firestore matches the Razorpay plan_id
        debugPrint(
          "Calling Cloud Function to create subscription for plan: $planId",
        );

        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
          'createRazorpaySubscription',
        );
        final result = await callable.call(<String, dynamic>{
          'planId': planId,
          'totalCount': 12, // 12 months default
        });

        final subscriptionId = result.data['subscriptionId'];
        _pendingSubscriptionId = subscriptionId;
        options['subscription_id'] = subscriptionId;
      } else {
        // Standard One-Time Payment: ask the server to create the order.
        final bool isEntryPass = notes != null && notes['type'] == 'entry_pass';
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
          'createPaymentOrder',
        );
        final result = await callable.call(<String, dynamic>{
          'type': isEntryPass ? 'entry_pass' : 'package',
          if (!isEntryPass) 'packageId': notes?['packageId'],
        });
        _pendingOrderId = result.data['orderId'];
        options['order_id'] = _pendingOrderId;
        options['amount'] = result.data['amountPaise'];
        final String? serverKey = result.data['keyId'];
        if (serverKey != null && serverKey.isNotEmpty) {
          options['key'] = serverKey;
        }
      }

      _razorpay.open(options);
      return true;
    } catch (e) {
      debugPrint("Error opening Razorpay checkout: $e");
      return false;
    }
  }

  /// Asks the server to verify the Razorpay payment signature. Only the
  /// server marks the user as paid / subscribed, so this must succeed for the
  /// user to get access. Throws if verification fails.
  Future<void> verifyPayment(PaymentSuccessResponse response) async {
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'verifyPayment',
    );
    await callable.call(<String, dynamic>{
      'orderId': _pendingOrderId,
      'subscriptionId': _pendingSubscriptionId,
      'paymentId': response.paymentId,
      'signature': response.signature,
    });
  }

  void dispose() {
    if (_isInitialized) {
      _razorpay.clear();
      _isInitialized = false;
    }
  }
}
