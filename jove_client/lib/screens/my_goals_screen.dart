import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class MyGoalsScreen extends StatefulWidget {
  const MyGoalsScreen({super.key});

  @override
  State<MyGoalsScreen> createState() => _MyGoalsScreenState();
}

class _MyGoalsScreenState extends State<MyGoalsScreen> {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _primaryBlue = Color(0xFF00215F);

  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Stream only for the global goals list to prevent full-screen rebuilds
  late final Stream<QuerySnapshot> _availableGoalsStream;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);

  List<String> _selectedGoals = [];
  bool _isLoadingUserData = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Cache the stream so it doesn't recreate on rebuilds
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

  // Fetch the user's data ONLY ONCE.
  // We handle updates locally for a smoother, instant UI response.
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
        if (data['fitnessGoals'] != null) {
          _selectedGoals = List<String>.from(data['fitnessGoals']);
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

  // --- OPTIMISTIC AUTO-SAVE LOGIC ---
  Future<void> _toggleGoal(String goal) async {
    HapticFeedback.lightImpact();

    final bool isAdding = !_selectedGoals.contains(goal);

    // 1. Instantly update UI (Optimistic Update)
    setState(() {
      if (isAdding) {
        _selectedGoals.add(goal);
      } else {
        _selectedGoals.remove(goal);
      }
    });

    if (currentUser == null) {
      return;
    }

    // 2. Sync with Firebase in the background
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({'fitnessGoals': _selectedGoals}, SetOptions(merge: true));
    } catch (e) {
      // 3. Revert UI if the network request fails
      if (mounted) {
        setState(() {
          if (isAdding) {
            _selectedGoals.remove(goal);
          } else {
            _selectedGoals.add(goal);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_saving_goal'.tr()), // TRANSLATED
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
          SnackBar(content: Text('error_loading_booking'.tr())), // TRANSLATED
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
    return Scaffold(
      backgroundColor: _bgColor,
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _isLoadingUserData
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryBlue),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _availableGoalsStream,
                    builder: (context, goalsSnapshot) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          bottom: 120,
                        ), // Space for Nav Bar
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
                                'whats_your_fitness_goal'.tr(), // TRANSLATED
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6B6B6B),
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // GOALS LIST RENDERED FROM FIREBASE
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

          // --- BOTTOM NAV BAR ---
          Align(alignment: Alignment.bottomCenter, child: _buildBottomNavBar()),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI COMPONENTS
  // ===========================================================================

  Widget _buildGoalsList(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: _primaryBlue),
      );
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'no_goals_found'.tr(), // TRANSLATED
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Column(
      children: snapshot.data!.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String title = data['title'] ?? 'unknown_goal'.tr(); // TRANSLATED

        return GoalCard(
          title: title,
          isSelected: _selectedGoals.contains(title),
          onTap: () => _toggleGoal(title),
        );
      }).toList(),
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: _textMain,
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
                'my_goals'.tr(), // TRANSLATED
                style: const TextStyle(
                  color: _textMain,
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
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _textMain,
                size: 24,
              ),
              onPressed: () => HapticFeedback.lightImpact(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryBlue,
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

// Extracted into a Stateless Widget for Maximum Performance
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

  IconData _getIconForGoal(String title) {
    String lowerTitle = title.toLowerCase();

    if (lowerTitle.contains('muscle') || lowerTitle.contains('strength')) {
      return Icons.fitness_center_rounded;
    }
    if (lowerTitle.contains('weight') || lowerTitle.contains('fat')) {
      return Icons.monitor_weight_outlined;
    }
    if (lowerTitle.contains('medical') || lowerTitle.contains('injury')) {
      return Icons.medical_services_outlined;
    }
    if (lowerTitle.contains('lifestyle') || lowerTitle.contains('health')) {
      return Icons.self_improvement_rounded;
    }
    if (lowerTitle.contains('stress') || lowerTitle.contains('balance')) {
      return Icons.directions_run_rounded;
    }
    if (lowerTitle.contains('cardio') || lowerTitle.contains('stamina')) {
      return Icons.favorite_border_rounded;
    }

    return Icons.track_changes_rounded;
  }

  @override
  Widget build(BuildContext context) {
    IconData dynamicIcon = _getIconForGoal(title);
    const Color primaryBlue = Color(0xFF00215F);
    const Color textMain = Color(0xFF1A1A1A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              dynamicIcon,
              color: isSelected ? Colors.white : textMain,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title, // This string comes directly from the Firebase document 'title' field
                style: TextStyle(
                  color: isSelected ? Colors.white : textMain,
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
                  color: isSelected ? Colors.transparent : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              width: 22,
              height: 22,
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: primaryBlue)
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
    return GestureDetector(
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
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white70,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
