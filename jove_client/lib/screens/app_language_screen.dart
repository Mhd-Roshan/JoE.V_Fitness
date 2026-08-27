import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'change_trainer_screen.dart';
import 'trainer_selection_screen.dart';
import 'notification_screen.dart';
import '../theme/app_theme_controller.dart';

class AppLanguageScreen extends StatefulWidget {
  const AppLanguageScreen({super.key});

  @override
  State<AppLanguageScreen> createState() => _AppLanguageScreenState();
}

class _AppLanguageScreenState extends State<AppLanguageScreen> {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _iconBg = Color(0xFFF0F2F5);

  bool get _isDarkMode => AppThemeController.isDark;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);

  final ValueNotifier<String> _selectedLanguage = ValueNotifier<String>('en');

  bool _isLoading = true;
  bool _isNavigating = false;

  final List<Map<String, dynamic>> _languages = [
    {'title': 'English (US)', 'code': 'en', 'icon': Icons.translate_rounded},
    {
      'title': 'Malayalam (മലയാളം)',
      'code': 'ml',
      'icon': Icons.translate_rounded,
    },
    {'title': 'Hindi (हिन्दी)', 'code': 'hi', 'icon': Icons.translate_rounded},
    {'title': 'Tamil (தமிழ்)', 'code': 'ta', 'icon': Icons.translate_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLanguage();
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    _selectedLanguage.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLanguage() async {
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid);
      DocumentSnapshot userDoc;
      try {
        userDoc = await docRef.get(const GetOptions(source: Source.cache));
        if (!userDoc.exists) throw Exception("Cache miss");
      } catch (_) {
        userDoc = await docRef.get(const GetOptions(source: Source.server));
      }

      var userData = userDoc.data() as Map<String, dynamic>? ?? {};
      String lang = userData['appLanguage'] ?? 'en';

      _selectedLanguage.value = lang;

      if (mounted) {
        await context.setLocale(Locale(lang));
      }
    } catch (e) {
      debugPrint("Error fetching language: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setLanguage(String langCode) async {
    if (_selectedLanguage.value == langCode) return;

    HapticFeedback.selectionClick();
    if (currentUser == null) return;

    final String oldLang = _selectedLanguage.value;
    _selectedLanguage.value = langCode;

    if (mounted) {
      await context.setLocale(Locale(langCode));
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({'appLanguage': langCode}, SetOptions(merge: true));
    } catch (e) {
      _selectedLanguage.value = oldLang;
      if (mounted) {
        await context.setLocale(Locale(oldLang));
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_updating_language'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _navigate(Widget screen) {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.selectionClick();

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
        SnackBar(content: Text('error_loading_data'.tr())),
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
                    : RepaintBoundary(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RepaintBoundary(child: _buildTopAppBar()),
                              const SizedBox(height: 8),

                              _buildSectionTitle('select_language'.tr()),

                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: isDark
                                      ? Border.all(
                                          color: const Color(0xFF262626),
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.2 : 0.02,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: isDark
                                      ? const Color(0xFF121212)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  clipBehavior: Clip.antiAlias,
                                  child: ValueListenableBuilder<String>(
                                    valueListenable: _selectedLanguage,
                                    builder: (context, currentLang, _) {
                                      return Column(
                                        children: List.generate(_languages.length, (
                                          index,
                                        ) {
                                          final lang = _languages[index];
                                          final bool isSelected =
                                              currentLang == lang['code'];

                                          return Column(
                                            children: [
                                              InkWell(
                                                onTap: () =>
                                                    _setLanguage(lang['code']!),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 14,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF1E1E1E,
                                                                )
                                                              : _iconBg,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: isDark
                                                              ? Border.all(
                                                                  color: const Color(
                                                                    0xFF262626,
                                                                  ),
                                                                )
                                                              : null,
                                                        ),
                                                        child: Icon(
                                                          lang['icon']
                                                              as IconData,
                                                          size: 20,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF3B82F6,
                                                                )
                                                              : _navBgColor,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: Text(
                                                          lang['title']
                                                              as String,
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                isSelected
                                                                ? FontWeight
                                                                      .w900
                                                                : FontWeight
                                                                      .bold,
                                                            color: isSelected
                                                                ? (isDark
                                                                      ? const Color(
                                                                          0xFF3B82F6,
                                                                        )
                                                                      : _navBgColor)
                                                                : (isDark
                                                                      ? const Color(
                                                                          0xFFF5F5F5,
                                                                        )
                                                                      : _textMain),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (isSelected)
                                                        Icon(
                                                          Icons
                                                              .check_circle_rounded,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF3B82F6,
                                                                )
                                                              : _navBgColor,
                                                          size: 22,
                                                        )
                                                      else
                                                        Icon(
                                                          Icons.circle_outlined,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF444444,
                                                                )
                                                              : Colors
                                                                    .grey
                                                                    .shade300,
                                                          size: 22,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (index !=
                                                  _languages.length - 1)
                                                Divider(
                                                  height: 1,
                                                  thickness: 1,
                                                  color: isDark
                                                      ? const Color(0xFF262626)
                                                      : Colors.grey.shade100,
                                                  indent: 56,
                                                  endIndent: 16,
                                                ),
                                            ],
                                          );
                                        }),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                    'app_languages'.tr(),
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

  Widget _buildBottomNavBar() {
    final bool isDark = _isDarkMode;
    final Color navBg = isDark ? const Color(0xFF121212) : _navBgColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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

// --- BULLETPROOF OVERFLOW FIX ---
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
    // Uses strict Expanded to guarantee items divide space perfectly
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
                    // Allows text to shrink and apply '...' ellipsis
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
