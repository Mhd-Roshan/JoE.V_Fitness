import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';

import '../services/razorpay_service.dart';
import '../theme/app_theme_controller.dart';
import 'welcome_screen.dart';
import 'home_dashboard_screen.dart';
import 'trainer_selection_screen.dart';

class EntryPassPaywallScreen extends StatefulWidget {
  const EntryPassPaywallScreen({super.key});

  @override
  State<EntryPassPaywallScreen> createState() => _EntryPassPaywallScreenState();
}

class _EntryPassPaywallScreenState extends State<EntryPassPaywallScreen> {
  static const Color _primaryRed = Color(0xFFBB0013);
  static const Color _navy = Color(0xFF00225D);
  static const Color _cyan = Color(0xFF01BCE3);

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isProcessingPayment = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _loadUserDetails();
  }

  void _initializeRazorpay() {
    RazorpayService.instance.initialize(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
    );
  }

  Future<void> _loadUserDetails() async {
    _nameController.text = _currentUser?.displayName ?? '';
    _emailController.text = _currentUser?.email ?? '';
    _phoneController.text = _currentUser?.phoneNumber ?? '';

    if (_currentUser?.uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          if (_nameController.text.isEmpty) {
            _nameController.text = data['fullName'] ?? data['name'] ?? '';
          }
          if (_emailController.text.isEmpty) {
            _emailController.text = data['email'] ?? '';
          }
          if (_phoneController.text.isEmpty) {
            _phoneController.text = data['phone'] ?? data['phoneNumber'] ?? '';
          }
        }
      } catch (e) {
        debugPrint("Error loading user profile: $e");
      }
    }
  }

  @override
  void dispose() {
    RazorpayService.instance.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // --- START RAZORPAY ₹99 PAYMENT ---
  void _startRazorpayPayment() {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessingPayment = true);

    RazorpayService.instance.openCheckout(
      amount: 99, // ₹99
      packageName: 'App Access Pass',
      userEmail: _emailController.text.trim(),
      userPhone: _phoneController.text.trim(),
      userName: _nameController.text.trim(),
      notes: {
        'type': 'entry_pass',
        'userId': _currentUser?.uid ?? '',
        'amount': '99',
      },
    );
  }

  // --- PAYMENT SUCCESS HANDLER ---
  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    HapticFeedback.heavyImpact();

    if (_currentUser?.uid != null) {
      try {
        final now = DateTime.now();
        final String todayDate = DateFormat('yyyy-MM-dd').format(now);

        WriteBatch batch = FirebaseFirestore.instance.batch();
        DocumentReference userRef =
            FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
        DocumentReference historyRef = userRef
            .collection('payment_history')
            .doc(response.paymentId ?? DateTime.now().millisecondsSinceEpoch.toString());

        batch.set(userRef, {
          'hasPaidEntryFee': true,
          'entryFeePaidAt': FieldValue.serverTimestamp(),
          'entryFeePaymentId': response.paymentId ?? '',
          'lastAppAccessDate': todayDate,
        }, SetOptions(merge: true));

        batch.set(historyRef, {
          'paymentId': response.paymentId ?? '',
          'orderId': response.orderId ?? '',
          'planName': 'App Access Pass (₹99)',
          'billingCycle': 'ACCESS_PASS',
          'amount': 99.0,
          'currency': 'INR',
          'paymentMethod': 'Razorpay',
          'status': 'Success',
          'timestamp': FieldValue.serverTimestamp(),
        });

        await batch.commit();
      } catch (e) {
        debugPrint("Error saving entry pass to Firestore: $e");
      }
    }

    if (!mounted) return;
    setState(() => _isProcessingPayment = false);

    _showSuccessDialog(response);
  }

  // --- PAYMENT ERROR HANDLER ---
  void _handlePaymentError(PaymentFailureResponse response) {
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() => _isProcessingPayment = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              'Payment Cancelled',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          response.message != null && response.message!.isNotEmpty
              ? response.message!
              : 'Payment of ₹99 was not completed. Please try again to unlock full app access.',
          style: const TextStyle(color: Colors.black87, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startRazorpayPayment();
            },
            child: const Text('Retry ₹99 Payment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirected to wallet: ${response.walletName}'),
        backgroundColor: const Color(0xFF1E88E5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(PaymentSuccessResponse response) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF2E7D32),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Access Pass Unlocked!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹99 payment verified. You have full access to JoE.V Fitness.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    // Check if trainer assigned
                    final uid = _currentUser?.uid;
                    if (uid != null) {
                      final snap = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .get();
                      final trainerId = snap.data()?['assignedTrainerId'];
                      if (context.mounted) {
                        if (trainerId == null || trainerId.toString().isEmpty) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SelectTrainerScreen(),
                            ),
                            (route) => false,
                          );
                        } else {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeDashboardScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      }
                    }
                  },
                  child: const Text(
                    'Enter JoE.V Fitness',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF7F8FA),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // TOP LOGOUT / SWITCH USER BAR
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.grey),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // BRAND BADGE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _primaryRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _primaryRed.withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock_outline_rounded, color: _primaryRed, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'PREMIUM APP ACCESS PASS',
                          style: TextStyle(
                            color: _primaryRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TITLE & HEADLINE
                  Text(
                    'Welcome Back to JoE.V',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : _navy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock app exploration pass to track daily fitness, sync smart devices & explore elite trainers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ₹99 OFFER HERO CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF00225D),
                          Color(0xFF0F172A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _navy.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _cyan,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'EXPLORATION PASS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const Text(
                              'Instant Access',
                              style: TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹99',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Only',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Full access to view all modules, workouts & health tracking',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 14),

                        _featureBullet('Complete app exploration & workout previews'),
                        _featureBullet('Smart Watch & Band Real-Time Activity Sync'),
                        _featureBullet('Personalized Health, Steps & Sleep Rings'),
                        _featureBullet('Explore Certified Elite Personal Trainers'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // RAZORPAY TRUST
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF2E7D32), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Secured by Razorpay • UPI / Cards / NetBanking',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // PAY ₹99 BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 6,
                        shadowColor: _primaryRed.withValues(alpha: 0.4),
                      ),
                      onPressed: _isProcessingPayment ? null : _startRazorpayPayment,
                      child: _isProcessingPayment
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Pay ₹99 & Continue to App',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _featureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFF01BCE3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 11),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
