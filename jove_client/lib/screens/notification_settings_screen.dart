import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'change_trainer_screen.dart';
import 'trainer_selection_screen.dart';
import 'notification_screen.dart'; // <-- ADDED NOTIFICATION IMPORT
import '../theme/app_theme_controller.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Theme Colors (Matching Profile Screen Exactly)
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F); // Deep Blue
  static const Color _iconBg = Color(0xFFF0F2F5); // Added for Profile UI Match
  static const Color _cyanAccent = Color(0xFF00C4FF); // Cyan for Switches

  bool get _isDarkMode => AppThemeController.isDark;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(
    4,
  ); // Profile tab

  // OPTIMIZATION: Individual Notifiers for each switch to prevent full-screen rebuilds
  final ValueNotifier<bool> _trainerOnTheWay1 = ValueNotifier(false);
  final ValueNotifier<bool> _bookingConfirmations = ValueNotifier(false);
  final ValueNotifier<bool> _trainerOnTheWay2 = ValueNotifier(false);
  final ValueNotifier<bool> _dailyLogReminder = ValueNotifier(false);
  final ValueNotifier<bool> _renewalAlert = ValueNotifier(false);

  bool _isLoading = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _fetchNotificationSettings();
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    _trainerOnTheWay1.dispose();
    _bookingConfirmations.dispose();
    _trainerOnTheWay2.dispose();
    _dailyLogReminder.dispose();
    _renewalAlert.dispose();
    super.dispose();
  }

  // --- OPTIMIZED FIREBASE LOGIC ---
  Future<void> _fetchNotificationSettings() async {
    if (currentUser == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid);

      // OPTIMIZATION: Try cache first for instant UI loading
      DocumentSnapshot userDoc;
      try {
        userDoc = await docRef.get(const GetOptions(source: Source.cache));
        if (!userDoc.exists) throw Exception("Cache miss");
      } catch (_) {
        userDoc = await docRef.get(const GetOptions(source: Source.server));
      }

      var userData = userDoc.data() as Map<String, dynamic>? ?? {};
      var prefs =
          userData['notificationPreferences'] as Map<String, dynamic>? ?? {};

      // Update notifiers without calling setState for the whole screen
      _trainerOnTheWay1.value = prefs['trainerOnTheWay1'] ?? false;
      _bookingConfirmations.value = prefs['bookingConfirmations'] ?? false;
      _trainerOnTheWay2.value = prefs['trainerOnTheWay2'] ?? false;
      _dailyLogReminder.value = prefs['dailyLogReminder'] ?? false;
      _renewalAlert.value = prefs['renewalAlert'] ?? false;
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePreference(
    String key,
    ValueNotifier<bool> notifier,
    bool newValue,
  ) async {
    HapticFeedback.lightImpact();

    if (currentUser == null) return;

    // Optimistic UI Update: Instantly change the switch
    final bool oldValue = notifier.value;
    notifier.value = newValue;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
            'notificationPreferences': {key: newValue},
          }, SetOptions(merge: true));
    } catch (e) {
      // Revert if network fails
      notifier.value = oldValue;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_update_preference'.tr()), // TRANSLATED
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // --- NAVIGATION LOGIC ---
  void _navigate(Widget screen) {
    if (_isNavigating) return;
    _isNavigating = true;
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
      if (mounted) _isNavigating = false;
    });
  }

  Future<void> _navigateToBooking() async {
    if (_isNavigating || currentUser == null) return;
    _isNavigating = true;
    HapticFeedback.selectionClick();

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.black12,
      barrierDismissible: false,
      builder: (context) => const Center(child: CustomLoadingIndicator()),
    );

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>? ?? {};
      String? trainerId = userData['assignedTrainerId'];

      Widget nextScreen;
      if (trainerId == null || trainerId.isEmpty) {
        nextScreen = const ChangeTrainerScreen();
      } else {
        // Cache first logic for instant transition
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
            : const ChangeTrainerScreen();
      }

      navigator.pop(); // Close loading dialog safely

      await navigator.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => nextScreen,
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } catch (e) {
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('error_loading_booking'.tr())), // TRANSLATED
      );
    } finally {
      if (mounted) {
        _isNavigating = false;
        _selectedIndexNotifier.value = 4;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

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
                            const SizedBox(height: 8),

                            // --- SESSION ALERT SECTION ---
                            _buildSectionTitle(
                              'session_alert_title'.tr(),
                            ), // TRANSLATED
                            _buildCard([
                              _buildSwitchItem(
                                icon: Icons.route_outlined,
                                title: 'trainer_on_the_way'.tr(), // TRANSLATED
                                subtitle: 'trainer_on_the_way_desc'
                                    .tr(), // TRANSLATED
                                notifier: _trainerOnTheWay1,
                                prefKey: 'trainerOnTheWay1',
                              ),
                              _buildSwitchItem(
                                icon: Icons.calendar_today_outlined,
                                title: 'booking_confirmations'
                                    .tr(), // TRANSLATED
                                subtitle: 'booking_confirmations_desc'
                                    .tr(), // TRANSLATED
                                notifier: _bookingConfirmations,
                                prefKey: 'bookingConfirmations',
                              ),
                              _buildSwitchItem(
                                icon: Icons.access_time_outlined,
                                title: 'trainer_on_the_way'.tr(), // TRANSLATED
                                subtitle: 'trainer_on_the_way_desc'
                                    .tr(), // TRANSLATED
                                notifier: _trainerOnTheWay2,
                                prefKey: 'trainerOnTheWay2',
                                showDivider: false,
                              ),
                            ]),

                            const SizedBox(height: 24),

                            // --- PROGRESS & DIET SECTION ---
                            _buildSectionTitle(
                              'progress_diet_title'.tr(),
                            ), // TRANSLATED
                            _buildCard([
                              _buildSwitchItem(
                                icon: Icons.show_chart_rounded,
                                title: 'daily_log_reminder'.tr(), // TRANSLATED
                                subtitle: 'daily_log_reminder_desc'
                                    .tr(), // TRANSLATED
                                notifier: _dailyLogReminder,
                                prefKey: 'dailyLogReminder',
                                showDivider: false,
                              ),
                            ]),

                            const SizedBox(height: 24),

                            // --- BILLING SECTION ---
                            _buildSectionTitle(
                              'billing_title'.tr(),
                            ), // TRANSLATED
                            _buildCard([
                              _buildSwitchItem(
                                icon: Icons.credit_card_outlined,
                                title: 'renewal_payment_alert'
                                    .tr(), // TRANSLATED
                                subtitle: 'renewal_payment_alert_desc'
                                    .tr(), // TRANSLATED
                                notifier: _renewalAlert,
                                prefKey: 'renewalAlert',
                                showDivider: false,
                              ),
                            ]),

                            const SizedBox(height: 32),
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

  // --- UPDATED APP BAR WITH NOTIFICATION ICON LOGIC ---
  Widget _buildTopAppBar() {
    final bool isDark = _isDarkMode;
    final Color textMain = isDark ? const Color(0xFFF5F5F5) : _textMain;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: textMain, size: 20),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'notifications_title'.tr(), // TRANSLATED
                style: TextStyle(
                  color: textMain,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
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
              onPressed: () {
                HapticFeedback.selectionClick();
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, a, b) =>
                            const NotificationScreen(),
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
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final bool isDark = _isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    final bool isDark = _isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20), // Matched Profile: 20px
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ValueNotifier<bool> notifier,
    required String prefKey,
    bool showDivider = true,
  }) {
    final bool isDark = _isDarkMode;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon wrapped in background container like Profile Screen
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : _iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: isDark
                      ? Border.all(color: const Color(0xFF262626))
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFA8A8A8)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // OPTIMIZATION: Only this tiny widget rebuilds when toggled
              ValueListenableBuilder<bool>(
                valueListenable: notifier,
                builder: (context, value, _) {
                  return SizedBox(
                    height: 28,
                    width: 48,
                    child: CupertinoSwitch(
                      value: value,
                      onChanged: (val) =>
                          _togglePreference(prefKey, notifier, val),
                      activeTrackColor: isDark
                          ? const Color(0xFF3B82F6)
                          : _cyanAccent,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF262626) : Colors.grey.shade100,
            indent: 56,
            endIndent: 16,
          ), // Matched Profile indent
      ],
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
                label: 'home_nav'.tr(), // TRANSLATED
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const HomeDashboardScreen()),
              ),
              _NavItem(
                index: 1,
                icon: Icons.calendar_today_rounded,
                label: 'booking_nav'.tr(), // TRANSLATED
                selectedIndex: selectedIndex,
                onTap: _navigateToBooking,
              ),
              _NavItem(
                index: 2,
                icon: Icons.bar_chart_rounded,
                label: 'stats_nav'.tr(), // TRANSLATED
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ProgressScreen()),
              ),
              _NavItem(
                index: 3,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'chats_nav'.tr(), // TRANSLATED
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ChatScreen()),
              ),
              _NavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                label: 'profile_nav'.tr(), // TRANSLATED
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
