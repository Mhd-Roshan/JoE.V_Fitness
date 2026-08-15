import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Package selected. Payment screen goes here next.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: navy),
        title: const Text('Select Packages', style: TextStyle(color: navy)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Choose your packages',
                style: TextStyle(
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
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Text(
                        'No packages are available yet. Please check back shortly.',
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    return ListView(
                      children: docs.map((doc) {
                        final id = doc.id;
                        final data = doc.data() as Map<String, dynamic>;
                        final isSelected = _selectedPackageId == id;

                        // Mapping exact fields from your Firebase Data
                        final name = data['name'] ?? 'Package';
                        final order = data['order'] ?? 0;
                        final price = data['price'] ?? 0;
                        final cycle = data['billingCycle'] ?? 'monthly';
                        final badge =
                            data['badge']
                                as String?; // Could be null, "mostPopular", or "bestValue"

                        List<String> features = [];
                        if (data['features'] != null) {
                          features = List<String>.from(data['features']);
                        }

                        // --- BADGE LOGIC ---
                        String displayBadge = '';
                        Color badgeColor = cyan;
                        Color badgeTextColor = Colors.white;

                        if (badge != null && badge.isNotEmpty) {
                          if (badge == 'bestValue') {
                            displayBadge = 'Best Value';
                            badgeColor = Colors.amber;
                            badgeTextColor = navy; // Dark text on yellow
                          } else if (badge == 'mostPopular') {
                            displayBadge = 'Most Popular';
                            badgeColor = cyan;
                            badgeTextColor = Colors.white; // White text on cyan
                          } else {
                            displayBadge = badge;
                          }
                        }

                        return GestureDetector(
                          onTap: () => setState(() => _selectedPackageId = id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? cyan : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (displayBadge.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        displayBadge,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: badgeTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: navy,
                                          ),
                                        ),
                                        Text(
                                          'Package $order',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '₹${price.toString()}',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: navy,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                '/${cycle == 'monthly' ? 'Mo' : cycle}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...features.map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 20,
                                          color: cyan,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            f,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
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
                      }).toList(),
                    );
                  },
                ),
              ),

              Row(
                children: [
                  Checkbox(
                    value: _autoRenew,
                    activeColor: navy,
                    onChanged: (v) => setState(() => _autoRenew = v ?? true),
                  ),
                  const Expanded(
                    child: Text(
                      'Auto-renew monthly cancel anytime',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_selectedPackageId == null || _isContinuing)
                      ? null
                      : () {
                          _db
                              .collection('packages')
                              .doc(_selectedPackageId)
                              .get()
                              .then((doc) {
                                _handleContinue(doc.data() ?? {});
                              });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isContinuing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
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
