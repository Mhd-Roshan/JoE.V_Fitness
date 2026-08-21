import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'change_trainer_screen.dart';
import 'chat_screen.dart';
import 'personal_details_screen.dart';
import 'my_goals_screen.dart';
import 'health_profile_screen.dart';
import 'subscription_screen.dart';
import 'notification_settings_screen.dart';
import 'app_language_screen.dart';
import 'support_screen.dart'; // <-- ADDED SUPPORT SCREEN IMPORT

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _redButton = Color(0xFFBB0013);
  static const Color _iconBg = Color(0xFFF0F2F5);

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);
  final ValueNotifier<Map<String, dynamic>> _userDataNotifier = ValueNotifier(
    {},
  );

  final User? currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  bool _isNavigating = false;
  bool _hasPromptedFeedback = false;

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

              // Process feedback in the background
              Future.microtask(() => _checkPackageExpirationForFeedback(data));
            }
          }
        });
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'package_complete'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _navBgColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'how_was_experience'.tr(
                      namedArgs: {'trainerName': trainerName},
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
                    decoration: InputDecoration(
                      hintText: "write_review_hint".tr(),
                      filled: true,
                      fillColor: _iconBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
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
                        backgroundColor: _navBgColor,
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
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.selectionClick();

    // OPTIMIZATION: 50ms delay lets the button ripple effect finish before freezing the UI for navigation
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
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
    });
  }

  void _pushScreen(Widget screen) {
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
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
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _navBgColor)),
    );

    try {
      final String? trainerId = _userDataNotifier.value['assignedTrainerId'];
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
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('error_loading_booking'.tr())),
      );
    } finally {
      if (mounted) {
        _isNavigating = false;
        _selectedIndexNotifier.value = 4;
      }
    }
  }

  Future<void> _handleSignOut() async {
    HapticFeedback.mediumImpact();

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "sign_out".tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text("sign_out_confirm_msg".tr()),
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
                  backgroundColor: _redButton,
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

    if (confirm) {
      // ignore: use_build_context_synchronously
      final navigator = Navigator.of(context);
      await FirebaseAuth.instance.signOut();
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RepaintBoundary(
              // Decouples scroll updates from background repaints
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
                        // Profile Info
                        String fullName =
                            userData['fullName'] ??
                            currentUser?.displayName ??
                            'client_user'.tr();
                        String package =
                            userData['packageName'] ?? 'premium_package'.tr();
                        String photoUrl =
                            userData['photoURL'] ?? currentUser?.photoURL ?? '';
                        String trainerName =
                            userData['assignedTrainerName'] ??
                            'unassigned'.tr();

                        String appLangCode = userData['appLanguage'] ?? 'en';
                        String appLangDisplay = _getLanguageDisplayName(
                          appLangCode,
                        );

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
                                onTap: () =>
                                    _pushScreen(const PersonalDetailsScreen()),
                              ),
                              _MenuItemData(
                                icon: Icons.emoji_events_outlined,
                                title: 'my_goals'.tr(),
                                onTap: () => _pushScreen(const MyGoalsScreen()),
                              ),
                              _MenuItemData(
                                icon: Icons.health_and_safety_outlined,
                                title: 'health_profile'.tr(),
                                onTap: () =>
                                    _pushScreen(const HealthProfileScreen()),
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
                                onTap: () =>
                                    _pushScreen(const ChangeTrainerScreen()),
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
                                title: 'support'.tr(),
                                onTap: () => _pushScreen(
                                  const SupportScreen(),
                                ), // <-- NAVIGATES TO SUPPORT NOW
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

          Align(alignment: Alignment.bottomCenter, child: _buildBottomNavBar()),
        ],
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: _textMain,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.canPop(context)
                        ? Navigator.pop(context)
                        : _navigate(const HomeDashboardScreen());
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'view_profile'.tr(),
                    style: const TextStyle(
                      color: _textMain,
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
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _textMain,
                size: 24,
              ),
              onPressed: () => _pushScreen(const NotificationSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name, String package, String photoUrl) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _navBgColor.withValues(alpha: 0.1),
              width: 3,
            ),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.shade300,
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
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _textMain,
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
                    color: Colors.grey.shade600,
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
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _navBgColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItemData> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // OPTIMIZATION: Native Material + Clip.antiAlias eliminates staggered repaints and guarantees perfect ripples
      child: Material(
        color: Colors.white,
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
                            color: _iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, size: 20, color: _navBgColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textMain,
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
                                color: Colors.grey.shade500,
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
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
                    color: Colors.grey.shade100,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _redButton,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
          label: Text(
            'sign_out'.tr(),
            style: const TextStyle(
              color: Colors.white,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _navBgColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
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
    return Flexible(
      flex: isSelected ? 3 : 1,
      fit: FlexFit.loose,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: isSelected
              ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0)
              : const EdgeInsets.all(10.0),
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
                      fontSize: 13,
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
    );
  }
}
