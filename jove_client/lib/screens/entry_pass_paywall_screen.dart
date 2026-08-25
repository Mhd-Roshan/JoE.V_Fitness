import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';

import '../services/razorpay_service.dart';
import 'welcome_screen.dart';
import 'home_dashboard_screen.dart';

class EntryPassPaywallScreen extends StatefulWidget {
  const EntryPassPaywallScreen({super.key});

  @override
  State<EntryPassPaywallScreen> createState() => _EntryPassPaywallScreenState();
}

class _EntryPassPaywallScreenState extends State<EntryPassPaywallScreen> {
  static const Color _primaryRed = Color(0xFFBB0013);

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
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HomeDashboardScreen(),
                      ),
                      (route) => false,
                    );
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. ETHEREAL PASTEL MESH BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFC),
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.2),
                  radius: 1.1,
                  colors: [
                    Color(0xFFFFF7ED), // Warm amber glow in center
                    Color(0xFFEFF6FF), // Soft sky-blue wash
                    Color(0xFFFAF5FF), // Soft pastel lavender
                    Color(0xFFFFFFFF), // Pure bottom white
                  ],
                  stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Top Soft Aurora Blobs
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBAE6FD).withValues(alpha: 0.45),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFECDD3).withValues(alpha: 0.4),
              ),
            ),
          ),

          // 2. MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                // Top Bar with Minimal Logout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Tag with JoE.V Logo styling
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'JoE',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Color(0xFF0F172A),
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              height: 1.0,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 3.0,
                              right: 4.0,
                              bottom: 1.5,
                            ),
                            child: SvgPicture.asset(
                              'assets/images/kettlebell-icon.svg',
                              height: 10,
                              colorFilter: const ColorFilter.mode(
                                _primaryRed,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const Text(
                            'V FITNESS',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Color(0xFF0F172A),
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),

                      // Logout button
                      TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 15,
                          color: _primaryRed,
                        ),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(
                            color: _primaryRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: _primaryRed.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: _primaryRed.withValues(alpha: 0.2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Orbital Graphic Section (Flexible center)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: size.height * 0.44,
                        maxWidth: size.width * 0.92,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Concentric Orbital Rings
                          CustomPaint(
                            size: const Size(340, 340),
                            painter: _OrbitalRingsPainter(),
                          ),

                          // Glowing Center Star
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFFB7185), Color(0xFF818CF8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  size: 34,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          // Floating Badges on Orbit
                          // 1. Calendar / Workouts (Top Left)
                          _buildFloatingItem(
                            top: 40,
                            left: 50,
                            widget: _buildBadge(
                              icon: Icons.calendar_today_rounded,
                              bgColor: const Color(0xFF6366F1),
                              label: '21',
                            ),
                          ),

                          // 2. Map Pin / Gyms (Top Right)
                          _buildFloatingItem(
                            top: 30,
                            right: 90,
                            widget: _buildPinBadge(),
                          ),

                          // 3. User Avatar (Far Right)
                          _buildFloatingItem(
                            top: 85,
                            right: 20,
                            widget: _buildAvatarBadge(
                              bgColor: const Color(0xFFFDE047),
                              emoji: '😎',
                            ),
                          ),

                          // 4. Trainer / Coach (Middle Right)
                          _buildFloatingItem(
                            bottom: 95,
                            right: 40,
                            widget: _buildAvatarBadge(
                              bgColor: const Color(0xFFF472B6),
                              emoji: '🏋️',
                            ),
                          ),

                          // 5. Activity Globe / Tracking (Bottom Center)
                          _buildFloatingItem(
                            bottom: 30,
                            left: 110,
                            widget: _buildGlobeBadge(),
                          ),

                          // 6. Member Avatar (Middle Left)
                          _buildFloatingItem(
                            bottom: 110,
                            left: 28,
                            widget: _buildAvatarBadge(
                              bgColor: const Color(0xFFFDBA74),
                              emoji: '⚡',
                            ),
                          ),

                          // 7. Watch / Health (Top Far Left)
                          _buildFloatingItem(
                            top: 95,
                            left: 15,
                            widget: _buildIconPill(
                              icon: Icons.watch_rounded,
                              color: const Color(0xFF0284C7),
                            ),
                          ),

                          // 8. Trophy / Target (Near Center Top)
                          _buildFloatingItem(
                            top: 75,
                            right: 125,
                            widget: _buildAvatarBadge(
                              bgColor: const Color(0xFF86EFAC),
                              emoji: '🎯',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Content Sheet
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // JoE.V FITNESS Logo Row (Like Welcome Screen)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'JoE',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Color(0xFF0F172A),
                              fontSize: 26,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              height: 1.0,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 4.0,
                              right: 5.0,
                              bottom: 2.0,
                            ),
                            child: SvgPicture.asset(
                              'assets/images/kettlebell-icon.svg',
                              height: 14,
                              colorFilter: const ColorFilter.mode(
                                _primaryRed,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const Text(
                            'V FITNESS',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Color(0xFF0F172A),
                              fontSize: 26,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Gradient Sub-headline
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFFD946EF),
                            Color(0xFFF97316),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Starts Here',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Description
                      Text(
                        'Unlock exploration pass to preview workouts, browse elite trainers, sync smart devices & track daily health.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.0,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Alert Banner Above Button: Preview App Only
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB), // Soft warm amber
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.visibility_outlined,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 12.0,
                                    height: 1.35,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Preview Mode Only: ',
                                      style: TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    TextSpan(
                                      text: 'This pass grants view-only app exploration. Session booking requires a membership package.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Minimal Modern CTA Button in RED Color
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryRed, // Brand RED color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 4,
                            shadowColor: _primaryRed.withValues(alpha: 0.35),
                          ),
                          onPressed: _isProcessingPayment ? null : _startRazorpayPayment,
                          child: _isProcessingPayment
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Get Started • ₹99',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Trust Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'One-time payment • Secured by Razorpay',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- FLOATING ELEMENT HELPERS ---
  Widget _buildFloatingItem({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Widget widget,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget,
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required Color bgColor,
    required String label,
  }) {
    return Container(
      width: 44,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarBadge({required Color bgColor, required String emoji}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildPinBadge() {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFE879F9), Color(0xFFC084FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildGlobeBadge() {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFC084FC), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.public_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildIconPill({required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

// Custom Painter for Orbital Concentric Circles
class _OrbitalRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer Orbit
    canvas.drawCircle(center, 140, paint);

    // Middle Orbit
    final dashedPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, 95, dashedPaint);

    // Inner Orbit
    final innerPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, 54, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
