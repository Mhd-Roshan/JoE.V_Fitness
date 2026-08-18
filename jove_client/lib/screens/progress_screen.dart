import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Hide TextDirection from intl to prevent conflicts with Flutter's TextDirection
import 'package:intl/intl.dart' hide TextDirection;

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'trainer_selection_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _activeBlue = Color(0xFF003AA3);
  static const Color _limeGreen = Color(0xFFD4FF4E);

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(2);

  String _selectedTimeframe = 'Weekly';
  final List<String> _timeframes = const ['Weekly', 'Monthly', 'Yearly'];

  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<DocumentSnapshot> _userStream;

  late final String _todayDate;

  // Tracks which goals have already shown a dialog today to prevent repeating
  final Set<String> _shownDialogs = {};

  bool _isNavigating = false;

  // Controls when to render heavy UI to guarantee smooth page transitions
  bool _isScreenReady = false;

  @override
  void initState() {
    super.initState();
    _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final String uid = currentUser?.uid ?? '';
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true);

    // LAG FIX: Wait for the FadeTransition (150ms) to complete before building heavy charts.
    // This keeps the animation at 60/120 FPS.
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _isScreenReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  // --- DYNAMIC CHART DATA (NO DUMMY DATA) ---
  List<Map<String, dynamic>> _getChartData(Map<String, dynamic> userData) {
    Map<String, dynamic> dailySteps = userData['dailySteps'] != null
        ? Map<String, dynamic>.from(userData['dailySteps'])
        : {};

    int stepGoal = userData['stepsGoal'] != null && userData['stepsGoal'] > 0
        ? userData['stepsGoal']
        : 10000;

    DateTime now = DateTime.now();

    if (_selectedTimeframe == 'Monthly') {
      List<double> weeks = [0, 0, 0, 0];
      for (int i = 1; i <= now.day; i++) {
        DateTime d = DateTime(now.year, now.month, i);
        String dateKey = DateFormat('yyyy-MM-dd').format(d);
        int steps = dailySteps[dateKey] ?? 0;
        int wIndex = ((i - 1) / 7).floor().clamp(0, 3);
        weeks[wIndex] += steps;
      }
      return [
        {'label': 'W1', 'value': (weeks[0] / (stepGoal * 7)).clamp(0.0, 1.0)},
        {'label': 'W2', 'value': (weeks[1] / (stepGoal * 7)).clamp(0.0, 1.0)},
        {'label': 'W3', 'value': (weeks[2] / (stepGoal * 7)).clamp(0.0, 1.0)},
        {'label': 'W4', 'value': (weeks[3] / (stepGoal * 7)).clamp(0.0, 1.0)},
      ];
    } else if (_selectedTimeframe == 'Yearly') {
      List<double> months = List.filled(12, 0.0);
      dailySteps.forEach((key, val) {
        try {
          DateTime d = DateTime.parse(key);
          if (d.year == now.year) {
            months[d.month - 1] += (val as num).toDouble();
          }
        } catch (_) {}
      });
      List<String> monthLabels = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return List.generate(12, (i) {
        return {
          'label': monthLabels[i],
          'value': (months[i] / (stepGoal * 30)).clamp(0.0, 1.0),
        };
      });
    } else {
      List<Map<String, dynamic>> res = [];
      for (int i = 6; i >= 0; i--) {
        DateTime d = now.subtract(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(d);
        int steps = dailySteps[dateKey] ?? 0;
        res.add({
          'label': DateFormat('E').format(d),
          'value': (steps / stepGoal).clamp(0.0, 1.0),
        });
      }
      return res;
    }
  }

  // --- SUCCESS DIALOG (BOTTOM SHEET) ---
  void _showSuccessDialog({
    required String goalName,
    required String currentValue,
    required String goalValue,
  }) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDDF5D8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF146C2E),
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Goal Achieved',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textMain,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'You have completed your '),
                      TextSpan(
                        text: '$goalName goal!\n',
                        style: const TextStyle(
                          color: _textMain,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: 'Current Status: '),
                      TextSpan(
                        text: '$currentValue / $goalValue',
                        style: const TextStyle(
                          color: _activeBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- HYDRATION GOAL ---
  Future<void> _showHydrationGoalDialog(int initialAmount) async {
    TextEditingController controller = TextEditingController(text: "2.0");
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Set Hydration Goal',
            style: TextStyle(fontWeight: FontWeight.w800, color: _textMain),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How many Liters of water do you aim for daily?'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: 'L',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00B4D8),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                double parsedGoal = double.tryParse(controller.text) ?? 2.0;
                int newGoalMl = (parsedGoal * 1000).toInt();
                final uid = currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .set({
                        'hydrationGoal': newGoalMl,
                      }, SetOptions(merge: true));
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  _changeWater(0, initialAmount, newGoalMl);
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- SLEEP GOAL ---
  Future<void> _showSleepGoalDialog(int initialMinutes) async {
    TextEditingController controller = TextEditingController(text: "8.0");
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Set Sleep Goal',
            style: TextStyle(fontWeight: FontWeight.w800, color: _textMain),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How many hours of sleep do you aim for?'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: 'hrs',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF5A67D8),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A67D8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                double parsedGoalHrs = double.tryParse(controller.text) ?? 8.0;
                final uid = currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .set({
                        'sleepGoal': parsedGoalHrs,
                      }, SetOptions(merge: true));
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  _updateSleep(initialMinutes, initialMinutes, parsedGoalHrs);
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- STEPS GOAL ---
  Future<void> _showStepsGoalDialog(int initialSteps) async {
    TextEditingController controller = TextEditingController(text: "10000");
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Set Steps Goal',
            style: TextStyle(fontWeight: FontWeight.w800, color: _textMain),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How many steps do you aim for daily?'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'steps',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.lightGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                int parsedGoal = int.tryParse(controller.text) ?? 10000;
                final uid = currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .set({'stepsGoal': parsedGoal}, SetOptions(merge: true));
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  _updateSteps(initialSteps, initialSteps, parsedGoal);
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeWater(int currentWater, int amount, int goal) async {
    if (goal <= 0) {
      _showHydrationGoalDialog(amount);
      return;
    }
    final uid = currentUser?.uid;
    if (uid != null) {
      int newWaterLevel = (currentWater + amount)
          .clamp(0, double.infinity)
          .toInt();
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'dailyHydration': {_todayDate: newWaterLevel},
        }, SetOptions(merge: true));
        HapticFeedback.lightImpact();

        String key = 'hydration_$_todayDate';
        if (currentWater < goal && newWaterLevel >= goal) {
          if (!_shownDialogs.contains(key)) {
            _shownDialogs.add(key);
            _showSuccessDialog(
              goalName: 'Hydration',
              currentValue:
                  '${(newWaterLevel / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L',
              goalValue:
                  '${(goal / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update hydration.')),
          );
        }
      }
    }
  }

  Future<void> _updateWeight(double newWeight) async {
    final uid = currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'weight': newWeight,
          'dailyWeight': {_todayDate: newWeight},
        }, SetOptions(merge: true));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update weight.')),
          );
        }
      }
    }
  }

  Future<void> _updateSleep(
    int oldMinutes,
    int newMinutes,
    double goalHrs,
  ) async {
    if (goalHrs <= 0) {
      _showSleepGoalDialog(newMinutes);
      return;
    }

    final uid = currentUser?.uid;
    if (uid != null) {
      double hours = newMinutes / 60.0;
      hours = double.parse(hours.toStringAsFixed(2));

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'sleep': hours,
          'dailySleep': {_todayDate: hours},
        }, SetOptions(merge: true));

        double oldHrs = oldMinutes / 60.0;
        String key = 'sleep_$_todayDate';
        if (oldHrs < goalHrs && hours >= goalHrs) {
          if (!_shownDialogs.contains(key)) {
            _shownDialogs.add(key);
            _showSuccessDialog(
              goalName: 'Sleep',
              currentValue:
                  '${hours.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} hrs',
              goalValue:
                  '${goalHrs.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} hrs',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update sleep.')),
          );
        }
      }
    }
  }

  Future<void> _updateSteps(int oldSteps, int newSteps, int goal) async {
    if (goal <= 0) {
      _showStepsGoalDialog(newSteps);
      return;
    }
    final uid = currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'steps': newSteps,
          'dailySteps': {_todayDate: newSteps},
        }, SetOptions(merge: true));

        String key = 'steps_$_todayDate';
        if (oldSteps < goal && newSteps >= goal) {
          if (!_shownDialogs.contains(key)) {
            _shownDialogs.add(key);
            _showSuccessDialog(
              goalName: 'Steps',
              currentValue: '$newSteps steps',
              goalValue: '$goal steps',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update steps.')),
          );
        }
      }
    }
  }

  // --- OPTIMIZED NAVIGATION (FIXES LAG) ---
  Future<void> _navigateToBooking(Map<String, dynamic> userData) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    // Shows instant visual feedback so the UI doesn't feel stuck
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _activeBlue)),
    );

    try {
      String? trainerId = userData['assignedTrainerId'];

      Widget nextScreen;
      if (trainerId == null || trainerId.isEmpty) {
        nextScreen = const SelectTrainerScreen();
      } else {
        // Fetch from cache first for instantaneous loads, fallback to server
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

        if (trainerDoc.exists) {
          nextScreen = BookingScreen(
            trainer: Trainer.fromFirestore(trainerDoc),
          );
        } else {
          nextScreen = const SelectTrainerScreen();
        }
      }

      if (!mounted) return;

      // Pop the loading dialog
      Navigator.pop(context);

      // Use pushReplacement to stop the navigation stack from leaking memory
      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a, b) => nextScreen,
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop dialog on error
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading booking.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _selectedIndexNotifier.value = 2; // Reset visually if needed
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return Stack(
            children: [
              SafeArea(
                child: (!_isScreenReady || !snapshot.hasData)
                    // Visual trick: Show an empty background with just the App Bar during transition
                    // This eliminates the heavy stutter completely without showing a slow loading spinner.
                    ? Column(children: [_buildTopAppBar()])
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 120),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopAppBar(),
                            const SizedBox(height: 10),

                            // Using RepaintBoundary isolates heavy painting logic, making scrolls smooth
                            RepaintBoundary(
                              child: _buildActivityLevelChart(
                                _getChartData(userData),
                              ),
                            ),
                            const SizedBox(height: 24),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: RepaintBoundary(
                                      child: _buildHydrationCard(
                                        (userData['dailyHydration']
                                                as Map<
                                                  dynamic,
                                                  dynamic
                                                >?)?[_todayDate] ??
                                            0,
                                        userData['hydrationGoal'] ?? 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: RepaintBoundary(
                                      child: _WeightCard(
                                        initialWeight: num.parse(
                                          (userData['dailyWeight'] != null
                                                  ? userData['dailyWeight'][_todayDate]
                                                        ?.toString()
                                                  : null) ??
                                              userData['weight']?.toString() ??
                                              '70.0',
                                        ).toDouble(),
                                        onWeightChanged: _updateWeight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: RepaintBoundary(
                                      child: _SleepCard(
                                        initialMinutes:
                                            (num.parse(
                                                      (userData['dailySleep'] !=
                                                                  null
                                                              ? userData['dailySleep'][_todayDate]
                                                                    ?.toString()
                                                              : null) ??
                                                          userData['sleep']
                                                              ?.toString() ??
                                                          '0.0',
                                                    ).toDouble() *
                                                    60)
                                                .round(),
                                        goalHours: num.parse(
                                          userData['sleepGoal']?.toString() ??
                                              '0.0',
                                        ).toDouble(),
                                        onSleepChanged: (mins) => _updateSleep(
                                          (num.parse(
                                                    (userData['dailySleep'] !=
                                                                null
                                                            ? userData['dailySleep'][_todayDate]
                                                                  ?.toString()
                                                            : null) ??
                                                        userData['sleep']
                                                            ?.toString() ??
                                                        '0.0',
                                                  ).toDouble() *
                                                  60)
                                              .round(),
                                          mins,
                                          num.parse(
                                            userData['sleepGoal']?.toString() ??
                                                '0.0',
                                          ).toDouble(),
                                        ),
                                        onSetupGoal: () => _showSleepGoalDialog(
                                          (num.parse(
                                                    (userData['dailySleep'] !=
                                                                null
                                                            ? userData['dailySleep'][_todayDate]
                                                                  ?.toString()
                                                            : null) ??
                                                        userData['sleep']
                                                            ?.toString() ??
                                                        '0.0',
                                                  ).toDouble() *
                                                  60)
                                              .round(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: RepaintBoundary(
                                      child: _StepsCard(
                                        initialSteps:
                                            (userData['dailySteps']
                                                as Map<
                                                  dynamic,
                                                  dynamic
                                                >?)?[_todayDate] ??
                                            userData['steps'] ??
                                            0,
                                        goalSteps: userData['stepsGoal'] ?? 0,
                                        onStepsChanged: (steps) => _updateSteps(
                                          (userData['dailySteps']
                                                  as Map<
                                                    dynamic,
                                                    dynamic
                                                  >?)?[_todayDate] ??
                                              userData['steps'] ??
                                              0,
                                          steps,
                                          userData['stepsGoal'] ?? 0,
                                        ),
                                        onSetupGoal: () => _showStepsGoalDialog(
                                          (userData['dailySteps']
                                                  as Map<
                                                    dynamic,
                                                    dynamic
                                                  >?)?[_todayDate] ??
                                              userData['steps'] ??
                                              0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
              _buildBottomNavBar(userData),
            ],
          );
        },
      ),
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
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HomeDashboardScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'Progress',
                style: TextStyle(
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
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelChart(List<Map<String, dynamic>> chartData) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
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
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _timeframes.map((tf) {
                bool isSelected = _selectedTimeframe == tf;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTimeframe = tf),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        tf,
                        style: TextStyle(
                          color: isSelected ? _textMain : Colors.grey.shade600,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
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
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: chartData.map((data) {
                double barWidth = chartData.length > 7 ? 12.0 : 20.0;
                bool isToday =
                    data['label'] == DateFormat('E').format(DateTime.now());
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: barWidth,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutQuart,
                          width: barWidth,
                          height: 100 * (data['value'] as double),
                          decoration: BoxDecoration(
                            color: isToday
                                ? _activeBlue
                                : _activeBlue.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data['label'],
                      style: TextStyle(
                        color: isToday ? _activeBlue : Colors.grey.shade500,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                        fontSize: chartData.length > 7 ? 10 : 12,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationCard(int currentWater, int goal) {
    const Color waterColor = Color(0xFF00B4D8);
    double fillPercentage = goal > 0
        ? (currentWater / goal).clamp(0.0, 1.0)
        : 0.0;
    bool isWaterHigh = fillPercentage > 0.55;
    String formattedLiters = (currentWater / 1000).toString().replaceAll(
      RegExp(r'\.0$'),
      '',
    );

    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: waterColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  height: constraints.maxHeight * fillPercentage,
                  width: double.infinity,
                  color: waterColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          style: TextStyle(
                            color: isWaterHigh ? Colors.white : _textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          child: const Text('Hydration'),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 400),
                              style: TextStyle(
                                color: isWaterHigh
                                    ? Colors.white70
                                    : Colors.grey.shade500,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              child: const Text('Current'),
                            ),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 400),
                              style: TextStyle(
                                color: isWaterHigh ? Colors.white : _textMain,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              child: Text('${formattedLiters}L'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => _changeWater(currentWater, 250, goal),
                        onLongPress: () =>
                            _changeWater(currentWater, -250, goal),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: waterColor,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomNavBar(Map<String, dynamic> userData) {
    return Align(
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
                _NavItem(
                  index: 0,
                  icon: Icons.home_filled,
                  label: 'Home',
                  selectedIndex: selectedIndex,
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (c, a, b) => const HomeDashboardScreen(),
                        transitionsBuilder: (c, a, b, child) =>
                            FadeTransition(opacity: a, child: child),
                        transitionDuration: const Duration(milliseconds: 150),
                      ),
                      (route) => false,
                    );
                  },
                ),
                _NavItem(
                  index: 1,
                  icon: Icons.calendar_today_rounded,
                  label: 'Booking',
                  selectedIndex: selectedIndex,
                  onTap: () => _navigateToBooking(userData),
                ),
                _NavItem(
                  index: 2,
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  selectedIndex: selectedIndex,
                  onTap: () {},
                ),
                _NavItem(
                  index: 3,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chats',
                  selectedIndex: selectedIndex,
                  onTap: () => _selectedIndexNotifier.value = 3,
                ),
                _NavItem(
                  index: 4,
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  selectedIndex: selectedIndex,
                  onTap: () => _selectedIndexNotifier.value = 4,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// CUSTOM WEIGHT CARD WITH SCROLLING RULER (OPTIMIZED)
// ---------------------------------------------------------
class _WeightCard extends StatefulWidget {
  final double initialWeight;
  final ValueChanged<double> onWeightChanged;

  const _WeightCard({
    required this.initialWeight,
    required this.onWeightChanged,
  });

  @override
  State<_WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<_WeightCard> {
  late ScrollController _scrollController;
  late ValueNotifier<double> _weightNotifier;

  final double _minWeight = 20.0;
  final double _maxWeight = 250.0;

  // INCREASED SIZE: Spacing between lines is now 10 pixels
  final double _pixelsPerTick = 10.0;
  double get _pixelsPerKg => _pixelsPerTick * 10.0;

  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    double initialClamped = widget.initialWeight.clamp(_minWeight, _maxWeight);
    _weightNotifier = ValueNotifier<double>(initialClamped);

    _scrollController = ScrollController(
      initialScrollOffset: (initialClamped - _minWeight) * _pixelsPerKg,
    );

    // Using a listener instead of setState makes the ruler buttery smooth
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    double exactWeight = _minWeight + (_scrollController.offset / _pixelsPerKg);
    double roundedWeight = double.parse(
      exactWeight.clamp(_minWeight, _maxWeight).toStringAsFixed(1),
    );

    if (_weightNotifier.value != roundedWeight) {
      _weightNotifier.value = roundedWeight;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _weightNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _WeightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only animate to new server weight if the user isn't currently dragging it
    if (!_isUserScrolling && widget.initialWeight != oldWidget.initialWeight) {
      double newClamped = widget.initialWeight.clamp(_minWeight, _maxWeight);
      if ((newClamped - _weightNotifier.value).abs() > 0.1 &&
          _scrollController.hasClients) {
        _scrollController.animateTo(
          (newClamped - _minWeight) * _pixelsPerKg,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.orange.shade200.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weight',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            // ValueListenableBuilder isolates updates, stopping lag
                            ValueListenableBuilder<double>(
                              valueListenable: _weightNotifier,
                              builder: (context, weight, child) {
                                return Text(
                                  weight.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'kg',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // INCREASED SIZE: Ruler container is now taller
              SizedBox(
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification) {
                          _isUserScrolling = true;
                        } else if (notification is ScrollEndNotification) {
                          _isUserScrolling = false;
                          widget.onWeightChanged(_weightNotifier.value);
                          HapticFeedback.selectionClick();
                        }
                        return true;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        // Intentionally removed cacheExtent entirely so it complies with the newest Flutter versions seamlessly
                        itemCount: ((_maxWeight - _minWeight) * 10).toInt() + 1,
                        padding: EdgeInsets.symmetric(horizontal: halfWidth),
                        itemBuilder: (context, index) {
                          bool isMajorTick = index % 10 == 0;
                          return SizedBox(
                            width: _pixelsPerTick,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isMajorTick)
                                  Text(
                                    '${(_minWeight + (index ~/ 10)).toInt()}',
                                    style: TextStyle(
                                      fontSize:
                                          13, // Larger font for visibility
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                if (isMajorTick) const SizedBox(height: 6),
                                Container(
                                  width: isMajorTick ? 2.5 : 1.5,
                                  // INCREASED SIZE: Taller ticks for better visibility
                                  height: isMajorTick ? 36 : 20,
                                  decoration: BoxDecoration(
                                    color: isMajorTick
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ), // Padding from bottom
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // DARK ORANGE NEEDLE, INCREASED SIZE
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 4,
                        height: 48, // Taller needle
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade700, // Dark Orange
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.shade700.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// CUSTOM SLEEP CARD WITH CIRCULAR DIAL (HALF WIDTH)
// ---------------------------------------------------------
class _SleepCard extends StatefulWidget {
  final int initialMinutes;
  final double goalHours;
  final ValueChanged<int> onSleepChanged;
  final VoidCallback onSetupGoal;

  const _SleepCard({
    required this.initialMinutes,
    required this.goalHours,
    required this.onSleepChanged,
    required this.onSetupGoal,
  });

  @override
  State<_SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends State<_SleepCard> {
  late int _currentMins;
  bool _isDragging = false;

  final int _maxMins = 720; // 12 hours max on dial
  static const Color _sleepPurple = Color(0xFF5A67D8);

  @override
  void initState() {
    super.initState();
    _currentMins = widget.initialMinutes.clamp(0, _maxMins);
  }

  @override
  void didUpdateWidget(covariant _SleepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.initialMinutes != oldWidget.initialMinutes) {
      setState(() {
        _currentMins = widget.initialMinutes.clamp(0, _maxMins);
      });
    }
  }

  void _handlePan(Offset localPosition, Size size) {
    if (widget.goalHours <= 0) return;

    Offset center = Offset(size.width / 2, size.height / 2);
    double dx = localPosition.dx - center.dx;
    double dy = localPosition.dy - center.dy;

    double angle = math.atan2(dy, dx);
    double normalized = angle + (math.pi / 2);

    if (normalized < 0) {
      normalized += 2 * math.pi;
    }

    int mins = ((normalized / (2 * math.pi)) * _maxMins).round();
    mins = (mins / 15).round() * 15; // Snap to 15-minute increments

    if (mins != _currentMins) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentMins = mins.clamp(0, _maxMins);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int h = _currentMins ~/ 60;
    int m = _currentMins % 60;

    return GestureDetector(
      onTap: () {
        if (widget.goalHours <= 0) {
          widget.onSetupGoal();
        }
      },
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _sleepPurple.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sleep',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Current',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${h}h ${m}m',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: widget.goalHours <= 0
                  ? const Center(
                      child: Text(
                        'Set Goal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _sleepPurple,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        double progress = _currentMins / _maxMins;
                        double angle = -math.pi / 2 + (progress * 2 * math.pi);

                        double radius = (size.height / 2) - 15;

                        double knobX =
                            (size.width / 2) + radius * math.cos(angle) - 14;
                        double knobY =
                            (size.height / 2) + radius * math.sin(angle) - 14;

                        return Stack(
                          children: [
                            GestureDetector(
                              onPanStart: (_) => _isDragging = true,
                              onPanUpdate: (details) =>
                                  _handlePan(details.localPosition, size),
                              onPanEnd: (_) {
                                _isDragging = false;
                                widget.onSleepChanged(_currentMins);
                              },
                              child: CustomPaint(
                                size: size,
                                painter: _SleepDialPainter(
                                  progress: progress,
                                  trackColor: Colors.grey.shade100,
                                  activeColor: _sleepPurple,
                                  radius: radius,
                                ),
                              ),
                            ),
                            Positioned(
                              left: knobX,
                              top: knobY,
                              child: IgnorePointer(
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _sleepPurple,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _sleepPurple.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.nights_stay_rounded,
                                    color: _sleepPurple,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepDialPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color activeColor;
  final double radius;

  _SleepDialPainter({
    required this.progress,
    required this.trackColor,
    required this.activeColor,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = progress * 2 * math.pi;
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: const [Color(0xFF5A67D8), Color(0xFF9F7AEA)],
      stops: const [0.0, 1.0],
    );
    final activePaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < 12; i++) {
      double angle = -math.pi / 2 + (i * 2 * math.pi / 12);
      bool isMajor = i % 3 == 0;

      if (!isMajor) {
        double innerR = radius - 12;
        double outerR = radius - 8;
        canvas.drawLine(
          Offset(
            center.dx + innerR * math.cos(angle),
            center.dy + innerR * math.sin(angle),
          ),
          Offset(
            center.dx + outerR * math.cos(angle),
            center.dy + outerR * math.sin(angle),
          ),
          Paint()
            ..color = Colors.grey.shade400
            ..strokeWidth = 1.0,
        );
      } else {
        String text = i == 0
            ? '12'
            : i == 3
            ? '3'
            : i == 6
            ? '6'
            : '9';
        textPainter.text = TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();

        double labelR = radius - 22;
        Offset labelOffset = Offset(
          center.dx + labelR * math.cos(angle) - textPainter.width / 2,
          center.dy + labelR * math.sin(angle) - textPainter.height / 2,
        );
        textPainter.paint(canvas, labelOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SleepDialPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.radius != radius;
  }
}

// ---------------------------------------------------------
// CUSTOM STEPS CARD WITH WHEEL SCROLL (0, 1, 2...)
// ---------------------------------------------------------
class _StepsCard extends StatefulWidget {
  final int initialSteps;
  final int goalSteps;
  final ValueChanged<int> onStepsChanged;
  final VoidCallback onSetupGoal;

  const _StepsCard({
    required this.initialSteps,
    required this.goalSteps,
    required this.onStepsChanged,
    required this.onSetupGoal,
  });

  @override
  State<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<_StepsCard> {
  late FixedExtentScrollController _scrollController;
  late int _currentSteps;

  final int _stepIncrement = 1;
  final int _maxSteps = 50000;
  static const Color _stepsColor = Colors.lightGreen;

  @override
  void initState() {
    super.initState();
    _currentSteps = widget.initialSteps;
    int initialItem = (_currentSteps ~/ _stepIncrement);
    _scrollController = FixedExtentScrollController(initialItem: initialItem);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StepsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSteps != oldWidget.initialSteps &&
        widget.initialSteps != _currentSteps) {
      _currentSteps = widget.initialSteps;
      if (_scrollController.hasClients) {
        int newItem = (_currentSteps ~/ _stepIncrement);
        _scrollController.animateToItem(
          newItem,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = (_maxSteps ~/ _stepIncrement) + 1;

    return GestureDetector(
      onTap: () {
        if (widget.goalSteps <= 0) {
          widget.onSetupGoal();
        }
      },
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _stepsColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Steps',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Current',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$_currentSteps',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: widget.goalSteps <= 0
                  ? const Center(
                      child: Text(
                        'Set Goal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _stepsColor,
                        ),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 16,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _stepsColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _stepsColor.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollEndNotification) {
                              widget.onStepsChanged(_currentSteps);
                            }
                            return true;
                          },
                          child: ListWheelScrollView.useDelegate(
                            controller: _scrollController,
                            itemExtent: 40,
                            physics: const FixedExtentScrollPhysics(),
                            perspective: 0.005,
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _currentSteps = index * _stepIncrement;
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                bool isSelected =
                                    (index * _stepIncrement) == _currentSteps;
                                return Center(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${index * _stepIncrement}',
                                          style: TextStyle(
                                            fontSize: isSelected ? 24 : 18,
                                            fontWeight: isSelected
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFF1A1A1A)
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                        if (isSelected)
                                          TextSpan(
                                            text: ' steps',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: totalItems,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// NAV ITEM WIDGET
// ---------------------------------------------------------
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
