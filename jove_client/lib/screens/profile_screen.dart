import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:easy_localization/easy_localization.dart';

import 'home_dashboard_screen.dart';
import 'progress_screen.dart';
import 'change_trainer_screen.dart';
import 'chat_screen.dart';
import 'personal_details_screen.dart';
import 'my_goals_screen.dart';
import 'health_profile_screen.dart';
import 'subscription_screen.dart';
import 'notification_settings_screen.dart';
import 'app_language_screen.dart';
import 'help_feedback_screen.dart';
import 'welcome_screen.dart'; // <-- ADDED WELCOME SCREEN IMPORT
import 'connected_devices_screen.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/package_required_modal.dart';
import '../services/main_tab_controller.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBottomNav;
  const ProfileScreen({super.key, this.showBottomNav = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _iconBg = Color(0xFFF0F2F5);

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);
  final ValueNotifier<Map<String, dynamic>> _userDataNotifier = ValueNotifier(
    {},
  );

  final User? currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  bool _hasPromptedFeedback = false;

  bool get _isDarkMode => AppThemeController.isDark;

  // OPTIMIZATION: Prevents redundant UI rebuilds if incoming Firestore data hasn't actually changed.
  String _lastDataHash = '';

  @override
  void initState() {
    super.initState();
    _initUserDataListener();
  }

  void _initUserDataListener() {
    if (currentUser == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots(
          includeMetadataChanges: false,
        ) // Ignore cache-only ping updates
        .listen((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data() as Map<String, dynamic>;
            final String newHash = data.toString();

            // Only rebuild the UI if the actual data values have changed
            if (_lastDataHash != newHash) {
              _lastDataHash = newHash;
              _userDataNotifier.value = data;
              AppThemeController.initFromUserData(data);

              // Process feedback in the background
              Future.microtask(() => _checkPackageExpirationForFeedback(data));
            }
          }
        });
  }

  void _toggleTheme() {
    AppThemeController.toggleTheme();
    setState(() {});
  }

  Widget _buildThemeToggle() {
    return GestureDetector(
      onTap: _toggleTheme,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 64,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF262626)
              : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDarkMode
                ? const Color(0xFF3F3F46)
                : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.35 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    size: 15,
                    color: _isDarkMode
                        ? Colors.grey.shade600
                        : const Color(0xFFF59E0B),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.nightlight_round,
                    size: 14,
                    color: _isDarkMode
                        ? const Color(0xFF818CF8)
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              alignment: _isDarkMode
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDarkMode ? const Color(0xFF121212) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  size: 14,
                  color: _isDarkMode
                      ? const Color(0xFF818CF8)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    _userDataNotifier.dispose();
    _userSubscription?.cancel();
    super.dispose();
  }

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'ml':
        return 'Malayalam';
      case 'hi':
        return 'Hindi';
      case 'ta':
        return 'Tamil';
      case 'en':
      default:
        return 'English (US)';
    }
  }

  // --- RATING & FEEDBACK LOGIC ---
  void _checkPackageExpirationForFeedback(Map<String, dynamic> userData) {
    if (_hasPromptedFeedback || !mounted) return;

    Timestamp? endDate =
        userData['packageEndDate'] ??
        userData['subscription']?['nextBillingDate'];
    bool hasReviewed = userData['hasReviewedCurrentTrainer'] ?? false;
    String trainerName =
        userData['assignedTrainerName'] ?? 'your_trainer_fallback'.tr();

    if (endDate != null && !hasReviewed) {
      bool isExpired = DateTime.now().isAfter(endDate.toDate());

      if (isExpired) {
        _hasPromptedFeedback = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showTrainerFeedbackBottomSheet(trainerName);
        });
      }
    }
  }

  void _showTrainerFeedbackBottomSheet(String trainerName) {
    int rating = 0;
    final TextEditingController reviewController = TextEditingController();
    final bool isDark = _isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
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
                  Text(
                    'package_complete'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'how_was_experience'.tr(
                      namedArgs: {'trainerName': trainerName},
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setModalState(() => rating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                    ),
                    decoration: InputDecoration(
                      hintText: "write_review_hint".tr(),
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E1E) : _iconBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: isDark
                            ? const BorderSide(color: Color(0xFF262626))
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: isDark
                            ? const BorderSide(color: Color(0xFF262626))
                            : BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final navigator = Navigator.of(context);
                        if (currentUser != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser!.uid)
                              .set({
                                'hasReviewedCurrentTrainer': true,
                              }, SetOptions(merge: true));
                        }
                        navigator.pop();
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
                        'submit_feedback'.tr(),
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
      },
    );
  }

  // --- NAVIGATION LOGIC ---
  void _navigate(Widget screen) {
    HapticFeedback.selectionClick();
    int index = 4;
    if (screen is HomeDashboardScreen) {
      index = 0;
    } else if (screen is ProgressScreen) {
      index = 2;
    } else if (screen is ChatScreen) {
      index = 3;
    } else if (screen is ProfileScreen) {
      index = 4;
    }
    
    Navigator.popUntil(context, (route) => route.isFirst);
    MainTabController.switchTab(index);
  }

  void _pushScreen(Widget screen) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    });
  }

  Future<void> _navigateToBooking() async {
    HapticFeedback.selectionClick();
    Navigator.popUntil(context, (route) => route.isFirst);
    MainTabController.switchTab(1);
  }

  // --- UPDATED SIGN OUT LOGIC ---
  Future<void> _handleSignOut() async {
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
              "sign_out".tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF5F5F5) : _textMain,
              ),
            ),
            content: Text(
              "sign_out_confirm_msg".tr(),
              style: TextStyle(
                color: isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade700,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "btn_cancel".tr(),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400, // Light red for dialog
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  "sign_out".tr(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    // Safety check: Don't continue if the dialog was dismissed or context is dead
    if (!confirm || !mounted) return;

    // Clear session securely
    await GoogleSignIn().signOut().catchError((_) => null);
    await FirebaseAuth.instance.signOut();

    // Second safety check after async operation
    if (!mounted) return;

    // Push WelcomeScreen and remove all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const WelcomeScreen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (route) => false,
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                child: RepaintBoundary(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildTopAppBar(),
                        const SizedBox(height: 16),

                        ValueListenableBuilder<Map<String, dynamic>>(
                          valueListenable: _userDataNotifier,
                          builder: (context, userData, _) {
                            String rawFullName =
                                userData['fullName'] ??
                                currentUser?.displayName ??
                                '';
                            String fullName = rawFullName.trim().isNotEmpty
                                ? rawFullName
                                : 'client_user'.tr();
                            String package =
                                userData['packageName'] ??
                                (userData['subscription'] != null
                                    ? userData['subscription']['planName']
                                    : null) ??
                                'premium_package'.tr();
                            String photoUrl =
                                userData['photoURL'] ??
                                currentUser?.photoURL ??
                                '';
                            String trainerName =
                                userData['assignedTrainerName'] ??
                                'unassigned'.tr();

                            String appLangCode =
                                userData['appLanguage'] ?? 'en';
                            String appLangDisplay = _getLanguageDisplayName(
                              appLangCode,
                            );

                            final connectedDeviceMap =
                                userData['connectedDevice']
                                    as Map<String, dynamic>?;
                            final String connectedDeviceDisplay =
                                connectedDeviceMap?['name'] != null
                                ? connectedDeviceMap!['name']
                                      .toString()
                                      .split(' ')
                                      .first
                                : 'Connect';

                            bool isPackageExpired = false;
                            final nextBillingDate = userData['subscription']?['nextBillingDate'];
                            if (nextBillingDate != null) {
                              isPackageExpired = DateTime.now().isAfter(
                                (nextBillingDate as Timestamp).toDate(),
                              );
                            }

                            final bool hasActiveSubscription = !isPackageExpired &&
                                (userData['hasActiveSubscription'] == true ||
                                    (userData['subscription'] is Map &&
                                        userData['subscription']['status'] == 'Active'));

                            return Column(
                              children: [
                                RepaintBoundary(
                                  child: _buildProfileHeader(
                                    fullName,
                                    package,
                                    photoUrl,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                _buildSectionTitle('account_section'.tr()),
                                _buildMenuCard([
                                  _MenuItemData(
                                    icon: Icons.person_outline_rounded,
                                    title: 'personal_details'.tr(),
                                    onTap: () => _pushScreen(
                                      const PersonalDetailsScreen(),
                                    ),
                                  ),
                                  _MenuItemData(
                                    icon: Icons.emoji_events_outlined,
                                    title: 'my_goals'.tr(),
                                    onTap: () =>
                                        _pushScreen(const MyGoalsScreen()),
                                  ),
                                  _MenuItemData(
                                    icon: Icons.health_and_safety_outlined,
                                    title: 'health_profile'.tr(),
                                    onTap: () => _pushScreen(
                                      const HealthProfileScreen(),
                                    ),
                                  ),
                                  _MenuItemData(
                                    icon: Icons.watch_outlined,
                                    title: 'Connected Devices & Smart Bands',
                                    trailingText: connectedDeviceDisplay,
                                    onTap: () => _pushScreen(
                                      const ConnectedDevicesScreen(),
                                    ),
                                  ),
                                  _MenuItemData(
                                    icon: Icons.credit_card_outlined,
                                    title: 'subscription_billing'.tr(),
                                    onTap: () =>
                                        _pushScreen(const SubscriptionScreen()),
                                  ),
                                  _MenuItemData(
                                    icon: Icons.swap_horiz_rounded,
                                    title: 'change_trainer'.tr(),
                                    trailingText: trainerName,
                                    onTap: () {
                                      if (!hasActiveSubscription) {
                                        showPackageRequiredSheet(context, featureName: 'Trainer Change');
                                      } else {
                                        _pushScreen(const ChangeTrainerScreen());
                                      }
                                    },
                                  ),
                                ]),

                                const SizedBox(height: 24),

                                _buildSectionTitle('preference_section'.tr()),
                                _buildMenuCard([
                                  _MenuItemData(
                                    icon: Icons.notifications_none_rounded,
                                    title: 'notifications'.tr(),
                                    onTap: () => _pushScreen(
                                      const NotificationSettingsScreen(),
                                    ),
                                  ),
                                  _MenuItemData(
                                    icon: Icons.flag_outlined,
                                    title: 'app_languages'.tr(),
                                    trailingText: appLangDisplay,
                                    onTap: () =>
                                        _pushScreen(const AppLanguageScreen()),
                                  ),
                                  _MenuItemData(
                                    icon: Icons.help_outline_rounded,
                                    title: 'Help & Feedback',
                                    onTap: () =>
                                        _pushScreen(const HelpFeedbackScreen()),
                                  ),
                                ]),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 32),
                        _buildSignOutButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              if (widget.showBottomNav && !isKeyboardOpen)
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
    final Color textMain = _isDarkMode ? const Color(0xFFF5F5F5) : _textMain;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'view_profile'.tr(),
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
          const SizedBox(width: 12),
          _buildThemeToggle(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name, String package, String photoUrl) {
    final Color textMain = _isDarkMode ? const Color(0xFFF5F5F5) : _textMain;
    final Color textSub = _isDarkMode
        ? const Color(0xFFA8A8A8)
        : Colors.grey.shade600;
    final Color ringColor = _isDarkMode
        ? const Color(0xFF262626)
        : _navBgColor.withValues(alpha: 0.1);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 3),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: _isDarkMode
                ? const Color(0xFF262626)
                : Colors.grey.shade300,
            onBackgroundImageError: photoUrl.isNotEmpty ? (_, _) {} : null,
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textMain,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  package,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textSub,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final Color sectionColor = _isDarkMode
        ? const Color(0xFFF5F5F5)
        : _navBgColor;

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: sectionColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItemData> items) {
    final Color cardBg = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color iconBg = _isDarkMode ? const Color(0xFF262626) : _iconBg;
    final Color iconColor = _isDarkMode ? Colors.white : _navBgColor;
    final Color textMain = _isDarkMode ? const Color(0xFFF5F5F5) : _textMain;
    final Color textSub = _isDarkMode
        ? const Color(0xFFA8A8A8)
        : Colors.grey.shade500;
    final Color chevronBg = _isDarkMode
        ? const Color(0xFF1F1F1F)
        : Colors.grey.shade100;
    final Color chevronColor = _isDarkMode
        ? Colors.grey.shade500
        : Colors.grey.shade400;
    final Color dividerColor = _isDarkMode
        ? const Color(0xFF1F1F1F)
        : Colors.grey.shade100;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: _isDarkMode
            ? Border.all(color: const Color(0xFF262626), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            return Column(
              children: [
                InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, size: 20, color: iconColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.trailingText != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.trailingText!,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textSub,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: chevronBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: chevronColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index != items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dividerColor,
                    indent: 56,
                    endIndent: 16,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    final Color lightRed = _isDarkMode
        ? const Color(0xFFEF4444)
        : Colors.red.shade400;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: lightRed, // Makes ripple effect and text red
            side: BorderSide(color: lightRed, width: 1.5), // Light red outline
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: Icon(Icons.logout_rounded, color: lightRed, size: 22),
          label: Text(
            'sign_out'.tr(),
            style: TextStyle(
              color: lightRed,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: _handleSignOut,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final Color navBg = _isDarkMode ? const Color(0xFF121212) : _navBgColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(40),
        border: _isDarkMode
            ? Border.all(color: const Color(0xFF262626), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.35 : 0.15),
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
                onTap: () {}, // Already on Profile
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;
  _MenuItemData({
    required this.icon,
    required this.title,
    this.trailingText,
    required this.onTap,
  });
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
        onTap: onTap,
        child: Container(
          color: Colors.transparent, // Expands touch area safely
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
