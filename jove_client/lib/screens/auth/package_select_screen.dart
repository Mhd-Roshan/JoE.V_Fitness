import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // --- MODERN FLOATING ALERT ---
  void _showModernSnackBar(String message) {
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
    // 1. Check if a package is selected!
    if (_selectedPackageId == null) {
      _showModernSnackBar('Please select a package to continue.');
      return;
    }

    // 2. If selected, proceed
    _db.collection('packages').doc(_selectedPackageId).get().then((doc) {
      _handleContinue(doc.data() ?? {});
    });
  }

  Future<void> _handleContinue(Map<String, dynamic> selectedPackageData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedPackageId == null) return;

    setState(() => _isContinuing = true);

    try {
      await _db.collection('users').doc(uid).set({
        'pendingPackageId': _selectedPackageId,
        'pendingAutoRenew': _autoRenew,
      }, SetOptions(merge: true));

      if (!mounted) return;

      // Navigator.push(context,
      //   MaterialPageRoute(builder: (_) => OrderSummaryScreen(
      //     packageId: _selectedPackageId!,
      //     packageData: selectedPackageData,
      //   )));

      // Replace with your actual routing, but here is a success modern snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Package selected successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(20),
        ),
      );
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF8F9FA,
      ), // Very light grey for modern contrast
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        iconTheme: const IconThemeData(color: navy),
        title: Text(
          'Select Packages',
          style: GoogleFonts.poppins(color: navy, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'Choose your package',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('packages')
                      .orderBy('order')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: cyan),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'Could not load packages: ${snapshot.error}',
                        style: GoogleFonts.poppins(color: Colors.red),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No packages are available yet.\nPlease check back shortly.',
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

                        // --- BADGE LOGIC ---
                        String displayBadge = '';
                        Color badgeColor = cyan;

                        if (badge != null && badge.isNotEmpty) {
                          if (badge == 'bestValue') {
                            displayBadge = 'BEST VALUE';
                            badgeColor = const Color(
                              0xFFF39C12,
                            ); // Premium Orange
                          } else if (badge == 'mostPopular') {
                            displayBadge = 'MOST POPULAR';
                            badgeColor = cyan;
                          } else {
                            displayBadge = badge.toUpperCase();
                          }
                        }

                        return GestureDetector(
                          onTap: () => setState(() => _selectedPackageId = id),
                          // MODERN ANIMATED CONTAINER FOR SELECTION
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
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
                                      ? cyan.withValues(alpha: 0.15)
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
                                      const SizedBox(), // Empty space if no badge
                                    // Modern Radio Check Circle
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
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
                    'Auto-renew monthly',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Cancel anytime',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onChanged: (v) => setState(() => _autoRenew = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),

              const SizedBox(height: 10),

              // --- CONTINUE BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56, // Slightly taller for modern feel
                child: ElevatedButton(
                  // Button is ALWAYS active so the user can tap it and trigger the alert
                  onPressed: _isContinuing ? null : _onContinueTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                    elevation: _selectedPackageId != null
                        ? 4
                        : 0, // Flat if not selected
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isContinuing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
