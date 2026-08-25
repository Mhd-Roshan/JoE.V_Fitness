import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../order_summary_screen.dart';
import '../home_dashboard_screen.dart';

const navy = Color(0xFF00225D);
const cyan = Color(0xFF01BCE3);
const red = Color(0xFFBB0013);

class PackageSelectScreen extends StatefulWidget {
  const PackageSelectScreen({super.key});

  @override
  State<PackageSelectScreen> createState() => _PackageSelectScreenState();
}

class _PackageSelectScreenState extends State<PackageSelectScreen> {
  final _db = FirebaseFirestore.instance;
  String? _selectedPackageId;
  bool _autoRenew = true;
  bool _isContinuing = false;
  bool _canExplore = true;

  // Cached stream so it doesn't restart on every setState or Hot Reload
  late final Stream<QuerySnapshot> _packagesStream = _db
      .collection('packages')
      .orderBy('order')
      .snapshots();

  @override
  void initState() {
    super.initState();
    _checkUserPreviewEligibility();
  }

  Future<void> _checkUserPreviewEligibility() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          final bool hasSeenFirstPreview = data['hasSeenFirstPreview'] == true;
          final bool hasPaidEntryFee = data['hasPaidEntryFee'] == true;
          final bool hasSeenSecondPreview = data['hasSeenSecondPreview'] == true;

          setState(() {
            _canExplore = !hasSeenFirstPreview || (hasPaidEntryFee && !hasSeenSecondPreview);
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _onExploreAppTap() async {
    HapticFeedback.mediumImpact();
    setState(() => _isContinuing = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        final data = doc.data() ?? {};
        final bool hasSeenFirstPreview = data['hasSeenFirstPreview'] == true;
        final bool hasPaidEntryFee = data['hasPaidEntryFee'] == true;

        Map<String, dynamic> updates = {};
        if (!hasSeenFirstPreview) {
          updates['hasSeenFirstPreview'] = true;
          updates['firstPreviewSeenAt'] = FieldValue.serverTimestamp();
        } else if (hasPaidEntryFee && data['hasSeenSecondPreview'] != true) {
          updates['hasSeenSecondPreview'] = true;
          updates['secondPreviewSeenAt'] = FieldValue.serverTimestamp();
        }

        if (updates.isNotEmpty) {
          await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
        );
      } catch (e) {
        if (mounted) {
          _showModernSnackBar('Error opening preview: $e');
        }
      } finally {
        if (mounted) setState(() => _isContinuing = false);
      }
    }
  }

  // --- MODERN FLOATING ALERT ---
  void _showModernSnackBar(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        // Premium Orange/Amber color for warnings/alerts
        backgroundColor: const Color(0xFFE67E22).withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- CONTINUE BUTTON LOGIC ---
  void _onContinueTap() {
    if (_selectedPackageId == null) {
      _showModernSnackBar('err_select_package'.tr());
      return;
    }

    _db.collection('packages').doc(_selectedPackageId).get().then((doc) {
      _handleContinue(doc.data() ?? {});
    });
  }

  Future<void> _handleContinue(Map<String, dynamic> selectedPackageData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedPackageId == null) return;

    setState(() => _isContinuing = true);

    try {
      // 1. Build a standardized subscription object for Firestore
      // This perfectly matches the robust logic we put in SubscriptionScreen
      Map<String, dynamic> pendingSubscriptionData = {
        'packageId': _selectedPackageId,
        'planName': selectedPackageData['name'] ?? 'Premium Plan',
        'packageName':
            selectedPackageData['billingCycle']?.toString().toUpperCase() ??
            'MONTHLY',
        'price': selectedPackageData['price'] ?? 0,
        'autoRenew': _autoRenew,
        'status':
            'Pending', // Pending until payment is complete on the next screen
        'paymentMethod': 'None',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 2. Save it to Firestore
      await _db.collection('users').doc(uid).set({
        'pendingPackageId':
            _selectedPackageId, // Kept for backward compatibility with checkout screen
        'pendingAutoRenew': _autoRenew, // Kept for backward compatibility
        'subscription':
            pendingSubscriptionData, // <-- THE NEW STANDARDIZED DATA
      }, SetOptions(merge: true));

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'success_package_selected'.tr(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(20),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSummaryScreen(
            packageData: selectedPackageData,
            packageId: _selectedPackageId!,
            initialAutoRenew: _autoRenew,
            isOnboarding: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showModernSnackBar('Error selecting package: $e');
      }
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Very light grey
      appBar: canPop
          ? AppBar(
              backgroundColor: const Color(0xFFF8F9FA),
              elevation: 0,
              automaticallyImplyLeading: true,
              iconTheme: const IconThemeData(color: navy),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'choose_package_heading'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _packagesStream, // OPTIMIZED STREAM
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: cyan),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'err_load_packages'.tr(
                          namedArgs: {'error': snapshot.error.toString()},
                        ),
                        style: GoogleFonts.poppins(color: Colors.red),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'no_packages_available'.tr(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final id = doc.id;
                        final data = doc.data() as Map<String, dynamic>;
                        final isSelected = _selectedPackageId == id;

                        final name = data['name'] ?? 'Package';
                        final order = data['order'] ?? 0;
                        final price = data['price'] ?? 0;
                        final cycle = data['billingCycle'] ?? 'monthly';
                        final badge = data['badge'] as String?;

                        List<String> features = [];
                        if (data['features'] != null) {
                          features = List<String>.from(data['features']);
                        }

                        // Badge Logic
                        String displayBadge = '';
                        Color badgeColor = cyan;

                        if (badge != null && badge.isNotEmpty) {
                          if (badge == 'bestValue') {
                            displayBadge = 'BEST VALUE';
                            badgeColor = const Color(0xFFF39C12); // Orange
                          } else if (badge == 'mostPopular') {
                            displayBadge = 'MOST POPULAR';
                            badgeColor = cyan;
                          } else {
                            displayBadge = badge.toUpperCase();
                          }
                        }

                        // OPTIMIZATION: Bouncing wrapper for smoothness
                        return _BouncingButton(
                          scaleFactor: 0.96,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPackageId = id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? cyan : Colors.transparent,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? cyan.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.05),
                                  blurRadius: isSelected ? 15 : 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge & Radio Icon Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (displayBadge.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          displayBadge,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: badgeColor,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(),

                                    // Modern Radio Check Circle
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOutBack,
                                      height: 24,
                                      width: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? cyan
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? cyan
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Title & Price
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: navy,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Package $order',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '₹${price.toString()}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: navy,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                '/${cycle == 'monthly' ? 'Mo' : cycle}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Divider
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Divider(
                                    color: Colors.grey.shade200,
                                    thickness: 1.5,
                                  ),
                                ),

                                // Features
                                ...features.map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          size: 18,
                                          color: cyan,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            f,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Auto-Renew Toggle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: CheckboxListTile(
                  value: _autoRenew,
                  activeColor: navy,
                  checkColor: Colors.white,
                  title: Text(
                    'auto_renew_monthly'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'cancel_anytime'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onChanged: (v) {
                    HapticFeedback.lightImpact();
                    setState(() => _autoRenew = v ?? true);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),

              const SizedBox(height: 10),

              // --- CONTINUE BUTTON ---
              _BouncingButton(
                onTap: _isContinuing ? null : _onContinueTap,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isContinuing ? null : _onContinueTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: red,
                      elevation: _selectedPackageId != null ? 4 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isContinuing
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
                              Text(
                                'continue_btn'.tr(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              if (_canExplore) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _isContinuing ? null : _onExploreAppTap,
                    icon: const Icon(Icons.explore_outlined, color: navy, size: 18),
                    label: Text(
                      'view_app_preview'.tr(),
                      style: GoogleFonts.poppins(
                        color: navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DEDICATED WIDGET FOR PERFORMANCE: ANIMATED BOUNCING BUTTON
// ==========================================
class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const _BouncingButton({
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.96,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
