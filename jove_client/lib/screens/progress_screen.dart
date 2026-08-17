import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Used for formatting numbers (e.g., 4,230)

// --- APP SCREENS ---
import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'trainer_selection_screen.dart'; // Needed to pass the Trainer data

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  // Theme Colors (Matching your app)
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _activeBlue = Color(0xFF003AA3);
  static const Color _limeGreen = Color(0xFFD4FF4E);

  // Bottom Nav Notifier (Defaults to 2 for "Stats")
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(2);

  // Toggle for chart (Weekly / Monthly)
  String _selectedTimeframe = 'Weekly';
  final List<String> _timeframes = ['Weekly', 'Monthly', 'Yearly'];

  // Firebase streams
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    // Initialize stream to listen to current user's document
    final String uid = currentUser?.uid ?? '';
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  // Safely parses weekly activity from Firebase. If null or missing, returns 0s.
  List<Map<String, dynamic>> _parseWeeklyActivity(dynamic dbData) {
    List<Map<String, dynamic>> defaultData = [
      {'day': 'Mon', 'value': 0.0},
      {'day': 'Tue', 'value': 0.0},
      {'day': 'Wed', 'value': 0.0},
      {'day': 'Thu', 'value': 0.0},
      {'day': 'Fri', 'value': 0.0},
      {'day': 'Sat', 'value': 0.0},
      {'day': 'Sun', 'value': 0.0},
    ];

    if (dbData != null && dbData is Map) {
      return defaultData.map((e) {
        String day = e['day'];
        // Safely parse any number type (int or double) from Firestore
        double val = 0.0;
        if (dbData[day] != null) {
          val = num.parse(dbData[day].toString()).toDouble();
        }
        return {
          'day': day,
          'value': val > 1.0 ? 1.0 : val, // Cap at 1.0 (100% height) for UI
        };
      }).toList();
    }

    return defaultData;
  }

  // --- BOOKING NAVIGATION LOGIC ---
  Future<void> _navigateToBooking() async {
    _selectedIndexNotifier.value = 1; // Visually switch to Booking tab

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.black)),
    );

    try {
      final uid = currentUser?.uid ?? '';
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = doc.data() ?? {};

      String? trainerId = userData['assignedTrainerId'];

      if (trainerId == null || trainerId.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, a, b) => const SelectTrainerScreen(),
            transitionsBuilder: (context, a, b, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
        // Reset nav bar when returning
        if (mounted) _selectedIndexNotifier.value = 2;
        return;
      }

      var trainerDoc = await FirebaseFirestore.instance
          .collection('trainers')
          .doc(trainerId)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (trainerDoc.exists) {
        Trainer assignedTrainer = Trainer.fromFirestore(trainerDoc);

        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, a, b) =>
                BookingScreen(trainer: assignedTrainer),
            transitionsBuilder: (context, a, b, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
      } else {
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, a, b) => const SelectTrainerScreen(),
            transitionsBuilder: (context, a, b, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
      }

      if (mounted) {
        _selectedIndexNotifier.value =
            2; // Reset nav back to Stats when returning
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading booking data.')),
      );
      _selectedIndexNotifier.value = 2; // Reset on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _userStream,
              builder: (context, snapshot) {
                // Handle Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }

                // Handle Error state
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading progress data.'),
                  );
                }

                // Extract real Firebase data safely
                var userData =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};

                // Parse Firebase values with fallbacks if they don't exist yet
                int calories = userData['calories'] ?? 0;
                int sessions =
                    userData['sessionsCompleted'] ?? userData['sessions'] ?? 0;
                int streak = userData['streak'] ?? 0;

                // Safely parse timeHours (Firestore might return int or double)
                double timeHours = 0.0;
                if (userData['workoutHours'] != null) {
                  timeHours = num.parse(
                    userData['workoutHours'].toString(),
                  ).toDouble();
                } else if (userData['time'] != null) {
                  timeHours = num.parse(userData['time'].toString()).toDouble();
                }

                // Format calories with commas (e.g., 4230 -> 4,230)
                String formattedCalories = NumberFormat(
                  '#,##0',
                ).format(calories);

                // Get Graph Data
                List<Map<String, dynamic>> weeklyData = _parseWeeklyActivity(
                  userData['weeklyActivity'],
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- TOP APP BAR ---
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Overview',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Your Progress',
                                  style: TextStyle(
                                    color: _textMain,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.share_outlined,
                                  color: _textMain,
                                ),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- TIMEFRAME SELECTOR (Pill Shaped) ---
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _timeframes.length,
                          itemBuilder: (context, index) {
                            bool isSelected =
                                _selectedTimeframe == _timeframes[index];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTimeframe = _timeframes[index];
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _activeBlue
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : Colors.grey.shade300,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: _activeBlue.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  _timeframes[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : _textMain,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- BAR CHART SECTION ---
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
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
                                const Text(
                                  'Activity Level',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _textMain,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _limeGreen.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '+14%',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Custom Bar Chart mapped to Firebase data
                            SizedBox(
                              height: 150,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: weeklyData.map((data) {
                                  // Highlight today automatically
                                  String currentDayString = DateFormat(
                                    'E',
                                  ).format(DateTime.now());
                                  bool isToday =
                                      data['day'] == currentDayString;

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        curve: Curves.easeOutQuart,
                                        width: 12,
                                        height: 110 * (data['value'] as double),
                                        decoration: BoxDecoration(
                                          color: isToday
                                              ? _activeBlue
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        data['day'],
                                        style: TextStyle(
                                          color: isToday
                                              ? _activeBlue
                                              : Colors.grey.shade400,
                                          fontWeight: isToday
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- STAT CARDS GRID (Real Firebase Data) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'Calories',
                                value: formattedCalories,
                                subtitle: 'kcal',
                                icon: Icons.local_fire_department_rounded,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Sessions',
                                value: sessions.toString(),
                                subtitle: 'completed',
                                icon: Icons.check_circle_outline_rounded,
                                color: _activeBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'Time',
                                value: timeHours.toStringAsFixed(
                                  1,
                                ), // e.g. 14.5
                                subtitle: 'hours',
                                icon: Icons.access_time_rounded,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Streak',
                                value: streak.toString(),
                                subtitle: 'days',
                                icon: Icons.bolt_rounded,
                                color: const Color.fromARGB(255, 204, 184, 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // --- Custom Bottom Navigation Bar ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 33, 95),
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
                      // Home Button
                      _NavItem(
                        index: 0,
                        icon: Icons.home_filled,
                        label: 'Home',
                        selectedIndex: selectedIndex,
                        onTap: () {
                          // Navigates smoothly to Home using the imported screen
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, a, b) =>
                                  const HomeDashboardScreen(),
                              transitionsBuilder: (context, a, b, child) =>
                                  FadeTransition(opacity: a, child: child),
                              transitionDuration: const Duration(
                                milliseconds: 150,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                      ),

                      // Booking Button (UPDATED to load Booking Screen directly)
                      _NavItem(
                        index: 1,
                        icon: Icons.calendar_today_rounded,
                        label: 'Booking',
                        selectedIndex: selectedIndex,
                        onTap: _navigateToBooking,
                      ),

                      // Stats Button (Current Page)
                      _NavItem(
                        index: 2,
                        icon: Icons.bar_chart_rounded,
                        label: 'Stats',
                        selectedIndex: selectedIndex,
                        onTap: () {}, // Do nothing, already here
                      ),

                      // Chats Button
                      _NavItem(
                        index: 3,
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chats',
                        selectedIndex: selectedIndex,
                        onTap: () {
                          _selectedIndexNotifier.value = 3;
                        },
                      ),
                      // Profile Button
                      _NavItem(
                        index: 4,
                        icon: Icons.person_outline_rounded,
                        label: 'Profile',
                        selectedIndex: selectedIndex,
                        onTap: () {
                          _selectedIndexNotifier.value = 4;
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Stat Cards
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: _textMain,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Nav Item specific to this file to prevent import conflicts
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0)
            : const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
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
