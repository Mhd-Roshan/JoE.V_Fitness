import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import '../widgets/package_required_modal.dart';
import '../theme/app_theme_controller.dart';

class MyGoalsScreen extends StatefulWidget {
  const MyGoalsScreen({super.key});

  @override
  State<MyGoalsScreen> createState() => _MyGoalsScreenState();
}

class _MyGoalsScreenState extends State<MyGoalsScreen> {
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _primaryBlue = Color(0xFF00215F);

  bool get _isDarkMode => AppThemeController.isDark;

  final User? currentUser = FirebaseAuth.instance.currentUser;

  static const List<String> _defaultGoals = [
    'Muscle Building & Strength',
    'Weight & Fat Loss',
    'Cardio & Stamina',
    'Healthy Lifestyle & Flexibility',
    'Stress Relief & Mental Wellness',
    'Injury Recovery & Rehabilitation',
  ];

  late final Stream<QuerySnapshot> _availableGoalsStream;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);

  List<String> _selectedGoals = [];
  bool _isLoadingUserData = true;
  bool _isNavigating = false;
  bool _hasActiveSubscription = false;

  @override
  void initState() {
    super.initState();
    _availableGoalsStream = FirebaseFirestore.instance
        .collection('fitness_goals')
        .snapshots();
    _fetchUserSelectedGoals();
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  // --- IMPROVED DATA FETCHING ---
  Future<void> _fetchUserSelectedGoals() async {
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoadingUserData = false);
      }
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;

        _hasActiveSubscription = data['hasActiveSubscription'] == true ||
            (data['subscription'] is Map &&
                data['subscription']['status'] == 'Active');

        // Safely check multiple possible keys used during assessment
        var rawGoals =
            data['fitnessGoals'] ??
            data['goals'] ??
            data['selectedGoals'] ??
            [];

        if (rawGoals is List) {
          // Parse safely and trim trailing spaces
          _selectedGoals = rawGoals.map((e) => e.toString().trim()).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching user goals: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingUserData = false);
      }
    }
  }

  // --- ROBUST SELECTION CHECK ---
  bool _isGoalSelected(String goal) {
    return _selectedGoals.any(
      (g) => g.trim().toLowerCase() == goal.trim().toLowerCase(),
    );
  }

  // --- PERSISTENT SELECTION TOGGLE ---
  Future<void> _toggleGoal(String goal) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Fitness Goals');
      return;
    }

    HapticFeedback.lightImpact();

    final bool isAdding = !_isGoalSelected(goal);
    final String cleanGoal = goal.trim();

    setState(() {
      if (isAdding) {
        _selectedGoals.add(cleanGoal);
      } else {
        _selectedGoals.removeWhere(
          (g) => g.toLowerCase() == cleanGoal.toLowerCase(),
        );
      }
    });

    if (currentUser == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
            'fitnessGoals': _selectedGoals,
            'goals': _selectedGoals, // Sync to 'goals' as well for redundancy
          }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isAdding) {
            _selectedGoals.removeWhere(
              (g) => g.toLowerCase() == cleanGoal.toLowerCase(),
            );
          } else {
            _selectedGoals.add(cleanGoal);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_saving_goal'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _primaryBlue)),
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
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('error_loading_booking'.tr())),
        );
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

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        final Color currentBg = isDark ? const Color(0xFF000000) : _bgColor;

        return Scaffold(
          backgroundColor: currentBg,
          extendBody: true,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: _isLoadingUserData
                    ? Center(
                        child: CircularProgressIndicator(
                          color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: _availableGoalsStream,
                        builder: (context, goalsSnapshot) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 120),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                RepaintBoundary(child: _buildTopAppBar()),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                  ),
                                  child: Text(
                                    'whats_your_fitness_goal'.tr(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFFA8A8A8) : const Color(0xFF6B6B6B),
                                      height: 1.2,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildGoalsList(goalsSnapshot),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (!isKeyboardOpen)
                Align(alignment: Alignment.bottomCenter, child: _buildBottomNavBar()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalsList(AsyncSnapshot<QuerySnapshot> snapshot) {
    final bool isDark = _isDarkMode;
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: CircularProgressIndicator(
          color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
        ),
      );
    }

    List<String> goalTitles = [];
    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
      goalTitles = snapshot.data!.docs
          .map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['title']?.toString() ?? '';
          })
          .where((t) => t.isNotEmpty)
          .toList();
    }

    if (goalTitles.isEmpty) {
      goalTitles = _defaultGoals;
    }

    return Column(
      children: goalTitles.map((title) {
        return GoalCard(
          title: title,
          isSelected: _isGoalSelected(title),
          onTap: () => _toggleGoal(title),
        );
      }).toList(),
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
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: textMain,
                  size: 20,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    _navigate(const ProfileScreen());
                  }
                },
              ),
              const SizedBox(width: 8),
              Text(
                'my_goals'.tr(),
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
              color: isDark ? const Color(0xFF1E1E1E) : Colors.black.withValues(alpha: 0.05),
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

                // CORRECT MOUNTED CHECK
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

  Widget _buildBottomNavBar() {
    final bool isDark = _isDarkMode;
    final Color navBg = isDark ? const Color(0xFF121212) : _primaryBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(40),
        border: isDark ? Border.all(color: const Color(0xFF262626), width: 1.2) : null,
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

// ===========================================================================
// GOAL CARD WIDGET
// ===========================================================================

class GoalCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  IconData _getIconForGoal(String goalTitle) {
    final lower = goalTitle.toLowerCase();
    if (lower.contains('muscle') || lower.contains('strength')) {
      return Icons.fitness_center_rounded;
    }
    if (lower.contains('fat') || lower.contains('weight')) {
      return Icons.local_fire_department_rounded;
    }
    if (lower.contains('cardio') || lower.contains('stamina')) {
      return Icons.directions_run_rounded;
    }
    if (lower.contains('flexibility') || lower.contains('healthy')) {
      return Icons.self_improvement_rounded;
    }
    if (lower.contains('stress') || lower.contains('wellness')) {
      return Icons.spa_rounded;
    }
    if (lower.contains('injury') || lower.contains('recovery')) {
      return Icons.healing_rounded;
    }
    return Icons.star_rounded;
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF00215F);
    const textMain = Color(0xFF1A1A1A);
    final bool isDark = AppThemeController.isDark;
    final IconData dynamicIcon = _getIconForGoal(title);

    final Color cardBg = isSelected
        ? (isDark ? const Color(0xFF1D4ED8) : primaryBlue)
        : (isDark ? const Color(0xFF121212) : Colors.white);
    final Color borderColor = isSelected
        ? (isDark ? const Color(0xFF3B82F6) : primaryBlue)
        : (isDark ? const Color(0xFF262626) : Colors.grey.shade200);
    final Color contentColor = isSelected
        ? Colors.white
        : (isDark ? const Color(0xFFF5F5F5) : textMain);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? const Color(0xFF3B82F6) : primaryBlue).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              dynamicIcon,
              color: contentColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: contentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  width: 1.5,
                ),
              ),
              width: 22,
              height: 22,
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: isDark ? const Color(0xFF1D4ED8) : primaryBlue,
                    )
                  : null,
            ),
          ],
        ),
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
