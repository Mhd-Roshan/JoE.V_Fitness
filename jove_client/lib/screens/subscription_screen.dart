import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'trainer_selection_screen.dart';
import 'notification_screen.dart';
import 'auth/package_select_screen.dart';
import '../theme/app_theme_controller.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _redButton = Color(0xFFBB0013);
  static const Color _iconBg = Color(0xFFF0F2F5);

  bool get _isDarkMode => AppThemeController.isDark;

  static const LinearGradient _meshGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.35, 0.65, 0.85, 1.0],
    colors: [
      Color(0xFFE2F4EB), // Soft Mint / Cyan
      Color(0xFFFDF0B9), // Soft Yellow
      Color(0xFFFA6A48), // Vibrant Orange / Red
      Color(0xFF0F4E53), // Dark Teal
      Color(0xFFC7CDFA), // Soft Purple / Blue
    ],
  );

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);
  bool _isLoading = true;
  bool _isNavigating = false;

  Map<String, dynamic>? _subscriptionData;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _autoRenew = false;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionData();
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  // ==========================================
  // FIREBASE LOGIC
  // ==========================================
  Future<void> _fetchSubscriptionData() async {
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;

        // --- HIGHLY ROBUST DATA EXTRACTION ---
        Map<String, dynamic> extractedSubData = {};

        // 1. Check if stored inside a 'subscription' map
        if (data['subscription'] is Map) {
          extractedSubData = Map<String, dynamic>.from(data['subscription']);
        }

        // 2. Scan through all common Map/String keys used for packages during assessment
        List<String> packageKeys = [
          'selectedPackage',
          'package',
          'currentPackage',
          'plan',
          'subscriptionPlan',
          'selectedPlan',
          'membership',
        ];

        for (String key in packageKeys) {
          if (data[key] is Map) {
            var pData = data[key] as Map;
            extractedSubData['planName'] ??=
                pData['name'] ??
                pData['title'] ??
                pData['planName'] ??
                pData['type'];
            extractedSubData['packageName'] ??=
                pData['duration'] ??
                pData['subtitle'] ??
                pData['description'] ??
                pData['packageName'] ??
                pData['name'];
            extractedSubData['price'] ??=
                pData['price'] ?? pData['amount'] ?? pData['cost'];
            extractedSubData['status'] ??= pData['status'] ?? 'Active';
          } else if (data[key] is String && data[key].toString().isNotEmpty) {
            extractedSubData['planName'] ??= data[key];
            extractedSubData['status'] ??= 'Active';
          }
        }

        // 3. Fallbacks for root level flat variables
        extractedSubData['planName'] ??=
            data['planName'] ??
            data['subscriptionPlan'] ??
            data['selectedPlan'] ??
            data['packageName'];
        extractedSubData['packageName'] ??=
            data['packageDuration'] ?? data['duration'];
        extractedSubData['price'] ??=
            data['price'] ??
            data['subscriptionPrice'] ??
            data['amount'] ??
            data['packagePrice'];
        extractedSubData['status'] ??=
            data['status'] ?? data['subscriptionStatus'];

        // 4. If we found a planName, FORCE status to Active (so it doesn't say "Inactive" or "No active plan")
        if (extractedSubData['planName'] != null &&
            extractedSubData['planName'].toString().trim().isNotEmpty) {
          if (extractedSubData['status'] == null ||
              extractedSubData['status'].toString().toLowerCase() ==
                  'inactive') {
            extractedSubData['status'] = 'Active';
          }
        }

        // 5. Last resort: Check if role/userType dictates a premium membership
        if (extractedSubData['planName'] == null) {
          String role = data['role']?.toString().toLowerCase() ?? '';
          String type = data['userType']?.toString().toLowerCase() ?? '';
          if (role == 'premium' ||
              type == 'premium' ||
              role == 'pro' ||
              type == 'pro') {
            extractedSubData['planName'] = (data['role'] ?? data['userType'])
                .toString()
                .toUpperCase();
            extractedSubData['status'] = 'Active';
          }
        }

        // Apply defaults
        extractedSubData['paymentMethod'] ??=
            data['paymentMethod'] ?? data['subscriptionPaymentMethod'];
        extractedSubData['autoRenew'] ??= data['autoRenew'] ?? false;
        extractedSubData['nextBillingDate'] ??=
            data['nextBillingDate'] ?? data['expiryDate'];
        extractedSubData['promptedRenewal'] ??=
            data['promptedRenewal'] ?? false;

        // Extract Payment History
        List<Map<String, dynamic>> extractedHistory = [];
        var rawHistory = data['paymentHistory'] ?? data['payments'];
        if (rawHistory is List) {
          extractedHistory = rawHistory
              .map(
                (e) => e is Map
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{},
              )
              .where((e) => e.isNotEmpty)
              .toList();
        }

        if (mounted) {
          setState(() {
            _subscriptionData = extractedSubData;
            _autoRenew = extractedSubData['autoRenew'] == true;
            _paymentHistory = extractedHistory;
          });
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowRenewalPrompt();
        });
      }
    } catch (e) {
      debugPrint("Error fetching subscription data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAutoRenew(bool value) async {
    HapticFeedback.lightImpact();

    setState(() => _autoRenew = value);

    if (currentUser == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
            'subscription': {'autoRenew': value},
            'autoRenew': value, // Sync to root just in case
          }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        setState(() => _autoRenew = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('fail_update_auto_renew'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePaymentMethod(String newMethod) async {
    if (currentUser == null) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _subscriptionData ??= {};
      _subscriptionData!['paymentMethod'] = newMethod;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
            'subscription': {'paymentMethod': newMethod},
            'paymentMethod': newMethod, // Sync to root just in case
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('payment_method_updated'.tr()),
            backgroundColor: const Color(0xFF34C759),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('fail_update_payment_method'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelSubscription() async {
    HapticFeedback.mediumImpact();
    final bool isDark = _isDarkMode;

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "cancel_subscription".tr(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _redButton,
              ),
            ),
            content: Text(
              "cancel_sub_confirm_msg".tr(),
              style: TextStyle(
                color: isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade700,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "keep_plan".tr(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _redButton,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  "cancel_plan".tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || currentUser == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      barrierDismissible: false,
      builder: (context) => const Center(child: CustomLoadingIndicator()),
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
            'subscription': {'status': 'Cancelled', 'autoRenew': false},
            'status': 'Cancelled',
            'autoRenew': false,
          }, SetOptions(merge: true));

      setState(() {
        _subscriptionData?['status'] = 'Cancelled';
        _autoRenew = false;
      });

      if (mounted) {
        Navigator.pop(context); // Pop loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('subscription_cancelled'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_cancelling_plan'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _checkAndShowRenewalPrompt() {
    if (_subscriptionData == null) {
      return;
    }

    bool prompted = _subscriptionData?['promptedRenewal'] ?? false;
    Timestamp? nextBillingTS = _subscriptionData?['nextBillingDate'];

    if (nextBillingTS == null || _autoRenew || prompted) {
      return;
    }

    DateTime nextBillingDate = nextBillingTS.toDate();
    int daysUntilExpiry = nextBillingDate.difference(DateTime.now()).inDays;

    if (daysUntilExpiry <= 7 && daysUntilExpiry >= 0) {
      _showRenewalBottomSheet(daysUntilExpiry);
    }
  }

  void _showRenewalBottomSheet(int daysRemaining) {
    final bool isDark = _isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF333333)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                'sub_expiring_soon'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'sub_expires_in_days'.tr(
                  namedArgs: {'days': daysRemaining.toString()},
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFA8A8A8)
                      : Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF3B82F6)
                        : _navBgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'renew_now'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (currentUser != null) {
      FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
        'subscription': {'promptedRenewal': true},
        'promptedRenewal': true,
      }, SetOptions(merge: true));
    }
  }

  void _showChangePaymentMethodDialog() {
    HapticFeedback.lightImpact();
    final bool isDark = _isDarkMode;

    List<Map<String, dynamic>> availableMethods = [
      {'name': 'Razorpay', 'icon': Icons.payment_rounded},
      {'name': 'UPI • jon@okicici', 'icon': Icons.paypal_rounded},
      {'name': 'Credit Card •••• 1234', 'icon': Icons.credit_card_rounded},
      {'name': 'Apple Pay • jon@doe.com', 'icon': Icons.apple_rounded},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF333333)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'select_payment_method'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...availableMethods.map((method) {
                bool isSelected =
                    (_subscriptionData?['paymentMethod'] == method['name']);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    method['icon'],
                    color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                  ),
                  title: Text(
                    method['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF34C759))
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) {
                      _updatePaymentMethod(method['name']);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --- NAVIGATION LOGIC ---
  void _navigate(Widget screen) {
    if (_isNavigating) {
      return;
    }

    setState(() => _isNavigating = true);
    HapticFeedback.selectionClick();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a, b) => screen,
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 150),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    });
  }

  Future<void> _navigateToBooking() async {
    if (_isNavigating || currentUser == null) {
      return;
    }

    setState(() => _isNavigating = true);
    HapticFeedback.selectionClick();

    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      barrierDismissible: false,
      builder: (context) => const Center(child: CustomLoadingIndicator()),
    );

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      String? trainerId =
          (userDoc.data() as Map<String, dynamic>?)?['assignedTrainerId'];

      Widget nextScreen;
      if (trainerId == null || trainerId.isEmpty) {
        nextScreen = const SelectTrainerScreen();
      } else {
        DocumentSnapshot trainerDoc = await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .get(const GetOptions(source: Source.cache))
            .catchError(
              (_) => FirebaseFirestore.instance
                  .collection('trainers')
                  .doc(trainerId)
                  .get(),
            );

        nextScreen = trainerDoc.exists
            ? BookingScreen(trainer: Trainer.fromFirestore(trainerDoc))
            : const SelectTrainerScreen();
      }

      if (!mounted) {
        return;
      }

      navigator.pop();
      await navigator.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => nextScreen,
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } catch (e) {
      if (mounted) {
        navigator.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('error_loading_booking'.tr())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _selectedIndexNotifier.value = 4;
        });
      }
    }
  }

  // ==========================================
  // MAIN BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    String status =
        _subscriptionData?['status']?.toString().toLowerCase() ?? 'inactive';
    bool isActive = (status == 'active');

    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        final Color currentBg = isDark ? const Color(0xFF000000) : _bgColor;

        return Scaffold(
          backgroundColor: currentBg,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: _isLoading
                    ? const Center(child: CustomLoadingIndicator())
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RepaintBoundary(child: _buildTopAppBar()),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'billing_and_plans'.tr(),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? const Color(0xFFF5F5F5)
                                          : _navBgColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'manage_elite_membership'.tr(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? const Color(0xFFA8A8A8)
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  RepaintBoundary(
                                    child: _buildCurrentPlanCard(),
                                  ),
                                  const SizedBox(height: 14),

                                  // SWITCH / UPGRADE PLAN ACTION
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const PackageSelectScreen(),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.swap_horiz_rounded,
                                        color: isDark
                                            ? const Color(0xFF3B82F6)
                                            : _navBgColor,
                                        size: 20,
                                      ),
                                      label: Text(
                                        'Change or Upgrade Plan',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFF3B82F6)
                                              : _navBgColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: isDark
                                              ? const Color(
                                                  0xFF3B82F6,
                                                ).withValues(alpha: 0.5)
                                              : _navBgColor.withValues(
                                                  alpha: 0.3,
                                                ),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E1E1E)
                                            : Colors.white,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  Text(
                                    'payment_method'.tr(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? const Color(0xFFF5F5F5)
                                          : _navBgColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  RepaintBoundary(
                                    child: _buildPaymentMethodCard(),
                                  ),
                                  const SizedBox(height: 28),

                                  Text(
                                    'payment_history'.tr(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? const Color(0xFFF5F5F5)
                                          : _navBgColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  RepaintBoundary(
                                    child: _buildPaymentHistoryList(),
                                  ),
                                  const SizedBox(height: 32),

                                  if (isActive) _buildCancelButton(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              if (!isKeyboardOpen)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomNavBar(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopAppBar() {
    final bool isDark = _isDarkMode;
    final Color textMain = isDark ? const Color(0xFFF5F5F5) : _textMain;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: textMain,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'subscription_title'.tr(),
                    style: TextStyle(
                      color: textMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: textMain,
                size: 24,
              ),
              onPressed: () async {
                HapticFeedback.selectionClick();
                await Future.delayed(const Duration(milliseconds: 50));

                if (!mounted) {
                  return;
                }

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, a, b) => const NotificationScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                            child: child,
                          );
                        },
                    transitionDuration: const Duration(milliseconds: 150),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    String planName =
        _subscriptionData?['planName']?.toString() ?? 'no_active_plan'.tr();
    String packageName = _subscriptionData?['packageName']?.toString() ?? '';
    String price = _subscriptionData?['price']?.toString() ?? '0';

    // Prevent displaying duplicate names like "Premium - Premium"
    if (planName.toLowerCase() == packageName.toLowerCase()) {
      packageName = '';
    }

    String rawStatus = _subscriptionData?['status']?.toString() ?? 'Inactive';
    String translatedStatus = rawStatus.toLowerCase() == 'inactive'
        ? 'status_inactive'.tr()
        : rawStatus;

    String formattedDate = 'not_applicable_short'.tr();
    if (_subscriptionData?['nextBillingDate'] != null) {
      DateTime dt = (_subscriptionData!['nextBillingDate'] as Timestamp)
          .toDate();
      formattedDate = DateFormat('MMM dd, yyyy').format(dt);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _meshGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              Expanded(
                child: Text(
                  'current_plan'.tr(),
                  style: const TextStyle(
                    color: _navBgColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _navBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  translatedStatus.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            planName,
            style: const TextStyle(
              color: _navBgColor,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (packageName.isNotEmpty)
                Flexible(
                  child: Text(
                    '$packageName - ',
                    style: const TextStyle(
                      color: _navBgColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(
                '₹$price ',
                style: const TextStyle(
                  color: _navBgColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Flexible(
                child: Text(
                  'per_month'.tr(),
                  style: const TextStyle(
                    color: _navBgColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'next_billing_date'.tr(),
                      style: const TextStyle(
                        color: _navBgColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: _navBgColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'auto_renew'.tr(),
                        style: const TextStyle(
                          color: _navBgColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'renew_monthly'.tr(),
                        style: TextStyle(
                          color: _navBgColor.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 28,
                    width: 48,
                    child: CupertinoSwitch(
                      value: _autoRenew,
                      onChanged: _toggleAutoRenew,
                      activeTrackColor: _navBgColor,
                      inactiveTrackColor: Colors.black.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    final bool isDark = _isDarkMode;
    String methodInfo =
        _subscriptionData?['paymentMethod']?.toString() ??
        'no_payment_method_linked'.tr();

    IconData getMethodIcon() {
      String lower = methodInfo.toLowerCase();
      if (lower.contains('razorpay')) {
        return Icons.payment_rounded;
      }
      if (lower.contains('upi') || lower.contains('paypal')) {
        return Icons.paypal_rounded;
      }
      if (lower.contains('apple')) {
        return Icons.apple_rounded;
      }
      return Icons.credit_card_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF262626)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : _iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    getMethodIcon(),
                    color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    methodInfo,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showChangePaymentMethodDialog,
            child: Text(
              'change_btn'.tr(),
              style: const TextStyle(
                color: _redButton,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: _redButton,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryList() {
    final bool isDark = _isDarkMode;
    if (_paymentHistory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: const Color(0xFF262626)) : null,
        ),
        child: Text(
          'no_recent_payments'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? const Color(0xFFA8A8A8) : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF262626)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_paymentHistory.length, (index) {
          var item = _paymentHistory[index];

          DateTime dt = item['date'] != null
              ? (item['date'] as Timestamp).toDate()
              : DateTime.now();
          String month = DateFormat('MMM').format(dt);
          String fullDate = DateFormat('MMM dd').format(dt);
          String amount = item['amount']?.toString() ?? '0';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : _iconBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              month.toUpperCase(),
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF3B82F6)
                                    : _navBgColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['packageName']?.toString() ??
                                      'default_package'.tr(),
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFF5F5F5)
                                        : _textMain,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$fullDate • ${item['method']?.toString() ?? 'UPI'}',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFA8A8A8)
                                        : Colors.grey.shade500,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹$amount',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['status']?.toString() ?? 'status_paid'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (index != _paymentHistory.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF262626)
                      : Colors.grey.shade100,
                  indent: 84,
                  endIndent: 20,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _cancelSubscription,
        style: ElevatedButton.styleFrom(
          backgroundColor: _redButton,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 22),
        label: Text(
          'cancel_subscription'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final bool isDark = _isDarkMode;
    final Color navBg = isDark ? const Color(0xFF121212) : _navBgColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(40),
        border: isDark
            ? Border.all(color: const Color(0xFF262626), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: _selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                index: 0,
                icon: Icons.home_filled,
                label: 'home_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const HomeDashboardScreen()),
              ),
              _NavItem(
                index: 1,
                icon: Icons.calendar_today_rounded,
                label: 'booking_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: _navigateToBooking,
              ),
              _NavItem(
                index: 2,
                icon: Icons.bar_chart_rounded,
                label: 'stats_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ProgressScreen()),
              ),
              _NavItem(
                index: 3,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'chats_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ChatScreen()),
              ),
              _NavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                label: 'profile_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ProfileScreen()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index, selectedIndex;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = selectedIndex == index;
    return Expanded(
      flex: isSelected ? 4 : 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            padding: isSelected
                ? const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0)
                : const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.white70,
                  size: 20,
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
