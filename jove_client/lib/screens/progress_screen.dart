import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'notification_screen.dart'; // <-- ADDED NOTIFICATION SCREEN IMPORT
import '../theme/app_theme_controller.dart';
import '../widgets/package_required_modal.dart';
import '../services/main_tab_controller.dart';

class ProgressScreen extends StatefulWidget {
  final bool showBottomNav;
  const ProgressScreen({super.key, this.showBottomNav = true});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _activeBlue = Color(0xFF003AA3);
  static const Color _limeGreen = Color(0xFFD4FF4E);

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(2);
  final PageController _pageController = PageController(keepPage: true);
  int _currentActivityPage = 0;

  String _selectedTimeframe = 'Weekly';
  final List<String> _timeframes = const ['Weekly', 'Monthly', 'Yearly'];

  final User? currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  Map<String, dynamic>? _cachedUserData;
  bool _hasActiveSubscription = false;

  late final String _todayDate;
  final Set<String> _shownDialogs = {};
  bool _hasPromptedDailyGoals = false;

  // --- Pre-calculated Dates ---
  late final List<DateTime> _past14Days;
  late final List<String> _past14DateKeys;

  late DateTime _selectedHistoryDate;
  late List<DateTime> _historyDays;
  late List<String> _historyDateKeys;
  late List<String> _historyDayNames;
  late List<String> _historyDayNums;
  late String _historyHeaderMonth;

  // --- Processed Chart Data ---
  String _cachedTrendPercentage = '0%';
  List<Map<String, dynamic>> _cachedChartData = [];
  Map<String, dynamic> _currentDailySteps = {};

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _todayDate = DateFormat('yyyy-MM-dd').format(now);

    // Calculate dates ONCE on init
    _past14Days = List.generate(15, (i) => now.subtract(Duration(days: i)));
    _past14DateKeys = _past14Days
        .map((d) => DateFormat('yyyy-MM-dd').format(d))
        .toList();

    _selectedHistoryDate = now;
    _updateHistoryDates(_selectedHistoryDate);

    _listenToUserData();
  }

  void _listenToUserData() {
    final String uid = currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return;
    }

    // Listen to stream in the background, NOT in the build method
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          if (!mounted || !snapshot.exists) {
            return;
          }

          // Removed the unnecessary cast here
          final data = snapshot.data() ?? {};

          // Extract steps and process chart data ONLY when Firestore actually updates
          _currentDailySteps = data['dailySteps'] != null
              ? Map<String, dynamic>.from(data['dailySteps'])
              : {};

          int todayStepsGoal =
              (data['dailyStepsGoals'] as Map?)?[_todayDate] ??
              data['stepsGoal'] ??
              10000;
          _recalculateChartAndTrend(
            todayStepsGoal > 0 ? todayStepsGoal : 10000,
          );

          final bool hasActiveSub =
              data['hasActiveSubscription'] == true ||
              (data['subscription'] is Map &&
                  data['subscription']['status'] == 'Active');

          setState(() {
            _cachedUserData = data;
            _hasActiveSubscription = hasActiveSub;
          });

          // Check if today's daily goals have been prompted (only for full package members)
          if (!_hasPromptedDailyGoals) {
            _hasPromptedDailyGoals = true;
            if (hasActiveSub) {
              String? lastGoalSetDate = data['dailyGoalSetDate']?.toString();
              if (lastGoalSetDate != _todayDate) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showDailyGoalSetupSheet(data);
                  }
                });
              }
            }
          }
        });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _selectedIndexNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _updateHistoryDates(DateTime date) {
    _historyDays = List.generate(15, (i) => date.subtract(Duration(days: i)));
    _historyDateKeys = _historyDays
        .map((d) => DateFormat('yyyy-MM-dd').format(d))
        .toList();
    _historyDayNames = _historyDays
        .map((d) => DateFormat('MMM').format(d).toUpperCase())
        .toList();
    _historyDayNums = _historyDays
        .map((d) => DateFormat('dd').format(d))
        .toList();
    _historyHeaderMonth = DateFormat('MMMM yyyy').format(date).toUpperCase();
  }

  String _getLocalizedTimeframe(String tf) {
    switch (tf) {
      case 'Weekly':
        return 'tf_weekly'.tr();
      case 'Monthly':
        return 'tf_monthly'.tr();
      case 'Yearly':
        return 'tf_yearly'.tr();
      default:
        return tf;
    }
  }

  void _recalculateChartAndTrend(int stepGoal) {
    _cachedTrendPercentage = _calculateActivityTrend(_currentDailySteps);
    _cachedChartData = _getChartData(_currentDailySteps, stepGoal);
  }

  void _onTimeframeChanged(String tf) {
    if (_selectedTimeframe == tf) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTimeframe = tf;
      _recalculateChartAndTrend(_cachedUserData?['stepsGoal'] ?? 10000);
    });
  }

  String _calculateActivityTrend(Map<String, dynamic> dailySteps) {
    int currentPeriod = 0;
    int previousPeriod = 0;
    int daysToLookBack = _selectedTimeframe == 'Weekly'
        ? 7
        : _selectedTimeframe == 'Monthly'
        ? 30
        : 365;

    DateTime now = DateTime.now();

    for (int i = 0; i < daysToLookBack; i++) {
      String k1 = (i < 15)
          ? _past14DateKeys[i]
          : DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      String k2 = DateFormat(
        'yyyy-MM-dd',
      ).format(now.subtract(Duration(days: i + daysToLookBack)));

      currentPeriod += (dailySteps[k1] as num?)?.toInt() ?? 0;
      previousPeriod += (dailySteps[k2] as num?)?.toInt() ?? 0;
    }

    if (previousPeriod == 0) {
      return currentPeriod > 0 ? '+100%' : '0%';
    }

    double diff = ((currentPeriod - previousPeriod) / previousPeriod) * 100;
    return '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}%';
  }

  List<Map<String, dynamic>> _getChartData(
    Map<String, dynamic> dailySteps,
    int stepGoal,
  ) {
    DateTime now = DateTime.now();
    // Prevent divide by zero if somehow goal is 0
    final safeGoal = stepGoal > 0 ? stepGoal : 10000;

    if (_selectedTimeframe == 'Monthly') {
      List<double> weeks = [0, 0, 0, 0];
      for (int i = 1; i <= now.day; i++) {
        String dateKey = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month, i));
        int wIndex = ((i - 1) / 7).floor().clamp(0, 3);
        weeks[wIndex] += (dailySteps[dateKey] ?? 0);
      }
      return [
        {'label': 'W1', 'value': (weeks[0] / (safeGoal * 7)).clamp(0.0, 1.0)},
        {'label': 'W2', 'value': (weeks[1] / (safeGoal * 7)).clamp(0.0, 1.0)},
        {'label': 'W3', 'value': (weeks[2] / (safeGoal * 7)).clamp(0.0, 1.0)},
        {'label': 'W4', 'value': (weeks[3] / (safeGoal * 7)).clamp(0.0, 1.0)},
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
      const List<String> monthLabels = [
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
      return List.generate(
        12,
        (i) => {
          'label': monthLabels[i],
          'value': (months[i] / (safeGoal * 30)).clamp(0.0, 1.0),
        },
      );
    } else {
      List<Map<String, dynamic>> res = [];
      String loc = context.locale.toString();
      for (int i = 6; i >= 0; i--) {
        res.add({
          'label': DateFormat.E(loc).format(_past14Days[i]),
          'value': ((dailySteps[_past14DateKeys[i]] ?? 0) / safeGoal).clamp(
            0.0,
            1.0,
          ),
        });
      }
      return res;
    }
  }

  // --- GOALS & SUCCESS DIALOGS ---
  void _showSuccessDialog({
    required String goalName,
    required String currentValue,
    required String goalValue,
  }) {
    if (!mounted) {
      return;
    }
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
            child: SingleChildScrollView(
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
                  Text(
                    'goal_achieved'.tr(),
                    style: const TextStyle(
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
                        TextSpan(text: 'msg_completed_part1'.tr()),
                        TextSpan(
                          text: '$goalName ${'msg_completed_part2'.tr()}',
                          style: const TextStyle(
                            color: _textMain,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: 'msg_current_status'.tr()),
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
                      child: Text(
                        'btn_done'.tr(),
                        style: const TextStyle(
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
          ),
        );
      },
    );
  }

  Future<void> _showHydrationGoalDialog(int initialAmount) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Hydration Goal');
      return;
    }
    int currentGoal =
        (_cachedUserData?['dailyHydrationGoals'] as Map?)?[_todayDate] ??
        _cachedUserData?['hydrationGoal'] ??
        2000;
    double currentGoalL = currentGoal > 0 ? (currentGoal / 1000) : 2.0;
    TextEditingController controller = TextEditingController(
      text: currentGoalL.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
    );
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'set_hydration_goal'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w800, color: _textMain),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: 'L',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'btn_cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B4D8),
            ),
            onPressed: () async {
              int newGoalMl = ((double.tryParse(controller.text) ?? 2.0) * 1000)
                  .toInt();
              if (currentUser?.uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .set({
                      'dailyHydrationGoals': {_todayDate: newGoalMl},
                      'dailyGoalSetDate': _todayDate,
                      'hydrationGoal': newGoalMl,
                    }, SetOptions(merge: true));
              }
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
              _changeWater(0, initialAmount, newGoalMl);
            },
            child: Text(
              'btn_save'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSleepGoalDialog(int initialMinutes) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Sleep Goal');
      return;
    }
    double currentGoal =
        (_cachedUserData?['dailySleepGoals'] as Map?)?[_todayDate]
            ?.toDouble() ??
        (_cachedUserData?['sleepGoal'] as num?)?.toDouble() ??
        8.0;
    TextEditingController controller = TextEditingController(
      text: currentGoal.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
    );
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'set_sleep_goal'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w800, color: _textMain),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: 'hrs',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'btn_cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A67D8),
            ),
            onPressed: () async {
              double parsedGoal = double.tryParse(controller.text) ?? 8.0;
              if (currentUser?.uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .set({
                      'dailySleepGoals': {_todayDate: parsedGoal},
                      'dailyGoalSetDate': _todayDate,
                      'sleepGoal': parsedGoal,
                    }, SetOptions(merge: true));
              }
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
              _updateSleep(initialMinutes, initialMinutes, parsedGoal);
            },
            child: Text(
              'btn_save'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStepsGoalDialog(int initialSteps) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Steps Goal');
      return;
    }
    int currentGoal =
        (_cachedUserData?['dailyStepsGoals'] as Map?)?[_todayDate] ??
        _cachedUserData?['stepsGoal'] ??
        10000;
    TextEditingController controller = TextEditingController(
      text: currentGoal.toString(),
    );
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'set_steps_goal'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w800, color: _textMain),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: 'steps',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'btn_cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen),
            onPressed: () async {
              int parsedGoal = int.tryParse(controller.text) ?? 10000;
              if (currentUser?.uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .set({
                      'dailyStepsGoals': {_todayDate: parsedGoal},
                      'dailyGoalSetDate': _todayDate,
                      'stepsGoal': parsedGoal,
                    }, SetOptions(merge: true));
              }
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
              _updateSteps(initialSteps, initialSteps, parsedGoal);
            },
            child: Text(
              'btn_save'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- DAILY GOAL SETUP SHEET & BANNER ---
  Future<void> _showDailyGoalSetupSheet(Map<String, dynamic> userData) async {
    if (!mounted) return;
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Daily Goals');
      return;
    }

    int currentStepsGoal =
        (userData['dailyStepsGoals'] as Map?)?[_todayDate] ??
        userData['stepsGoal'] ??
        10000;
    if (currentStepsGoal <= 0) currentStepsGoal = 10000;

    int currentHydrationGoal =
        (userData['dailyHydrationGoals'] as Map?)?[_todayDate] ??
        userData['hydrationGoal'] ??
        2000;
    if (currentHydrationGoal <= 0) currentHydrationGoal = 2000;

    double currentSleepGoal =
        (userData['dailySleepGoals'] as Map?)?[_todayDate]?.toDouble() ??
        (userData['sleepGoal'] as num?)?.toDouble() ??
        8.0;
    if (currentSleepGoal <= 0) currentSleepGoal = 8.0;

    int selectedSteps = currentStepsGoal;
    int selectedHydration = currentHydrationGoal;
    double selectedSleep = currentSleepGoal;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Set Today's Goals",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _textMain,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'EEEE, MMM d, yyyy',
                                ).format(DateTime.now()),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1. STEPS GOAL
                    _buildGoalSettingItem(
                      icon: Icons.directions_run_rounded,
                      iconColor: const Color(0xFF2E7D32),
                      bgColor: const Color(0xFFE8F5E9),
                      title: "Daily Steps Goal",
                      valueDisplay: "$selectedSteps steps",
                      onDecrement: () {
                        if (selectedSteps > 1000) {
                          setModalState(() => selectedSteps -= 1000);
                        }
                      },
                      onIncrement: () {
                        if (selectedSteps < 50000) {
                          setModalState(() => selectedSteps += 1000);
                        }
                      },
                      presets: [6000, 8000, 10000, 12000, 15000],
                      presetLabels: ["6k", "8k", "10k", "12k", "15k"],
                      selectedPreset: selectedSteps,
                      onPresetSelected: (val) =>
                          setModalState(() => selectedSteps = val as int),
                    ),
                    const SizedBox(height: 14),

                    // 2. HYDRATION GOAL
                    _buildGoalSettingItem(
                      icon: Icons.water_drop_rounded,
                      iconColor: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFE0F2FE),
                      title: "Daily Hydration Target",
                      valueDisplay:
                          "${(selectedHydration / 1000).toStringAsFixed(1)} L",
                      onDecrement: () {
                        if (selectedHydration > 500) {
                          setModalState(() => selectedHydration -= 250);
                        }
                      },
                      onIncrement: () {
                        if (selectedHydration < 8000) {
                          setModalState(() => selectedHydration += 250);
                        }
                      },
                      presets: [1500, 2000, 2500, 3000, 3500],
                      presetLabels: ["1.5L", "2.0L", "2.5L", "3.0L", "3.5L"],
                      selectedPreset: selectedHydration,
                      onPresetSelected: (val) =>
                          setModalState(() => selectedHydration = val as int),
                    ),
                    const SizedBox(height: 14),

                    // 3. SLEEP GOAL
                    _buildGoalSettingItem(
                      icon: Icons.nightlight_round,
                      iconColor: const Color(0xFF7E22CE),
                      bgColor: const Color(0xFFF3E8FF),
                      title: "Daily Sleep Target",
                      valueDisplay: "${selectedSleep.toStringAsFixed(1)} hrs",
                      onDecrement: () {
                        if (selectedSleep > 4.0) {
                          setModalState(() => selectedSleep -= 0.5);
                        }
                      },
                      onIncrement: () {
                        if (selectedSleep < 14.0) {
                          setModalState(() => selectedSleep += 0.5);
                        }
                      },
                      presets: [6.0, 7.0, 8.0, 9.0, 10.0],
                      presetLabels: ["6h", "7h", "8h", "9h", "10h"],
                      selectedPreset: selectedSleep,
                      onPresetSelected: (val) => setModalState(
                        () => selectedSleep = (val as num).toDouble(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SAVE BUTTON
                    _BouncingButton(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        if (currentUser?.uid != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser!.uid)
                              .set({
                                'dailyStepsGoals': {_todayDate: selectedSteps},
                                'dailyHydrationGoals': {
                                  _todayDate: selectedHydration,
                                },
                                'dailySleepGoals': {_todayDate: selectedSleep},
                                'dailyGoalSetDate': _todayDate,
                                'stepsGoal': selectedSteps,
                                'hydrationGoal': selectedHydration,
                                'sleepGoal': selectedSleep,
                              }, SetOptions(merge: true));
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text("Today's fitness goals have been set!"),
                                ],
                              ),
                              backgroundColor: const Color(0xFF2E7D32),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        height: 54,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBB0013),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFBB0013,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          "Save Today's Goals",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
      },
    );
  }

  Widget _buildGoalSettingItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String valueDisplay,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required List<dynamic> presets,
    required List<String> presetLabels,
    required dynamic selectedPreset,
    required ValueChanged<dynamic> onPresetSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _circleStepperBtn(Icons.remove, onDecrement),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      valueDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: iconColor,
                      ),
                    ),
                  ),
                  _circleStepperBtn(Icons.add, onIncrement),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(presets.length, (i) {
              final val = presets[i];
              final label = presetLabels[i];
              final bool isSelected = selectedPreset == val;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPresetSelected(val);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? iconColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? iconColor : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _circleStepperBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 15, color: _textMain),
      ),
    );
  }

  Widget _buildDailyGoalsBanner({
    required Map<String, dynamic> userData,
    required bool hasSetGoalsToday,
    required int stepsGoal,
    required int hydrationGoal,
    required double sleepGoal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: _BouncingButton(
        onTap: () => _showDailyGoalSetupSheet(userData),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: hasSetGoalsToday
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasSetGoalsToday
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFFFCCD5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: hasSetGoalsToday
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFFE4E6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasSetGoalsToday
                      ? Icons.verified_rounded
                      : Icons.flag_circle_rounded,
                  color: hasSetGoalsToday
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFE11D48),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSetGoalsToday
                          ? "Today's Goals Active"
                          : "Set Today's Fitness Goals",
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: hasSetGoalsToday
                            ? const Color(0xFF15803D)
                            : const Color(0xFFBE123C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasSetGoalsToday
                          ? "👟 ${stepsGoal > 0 ? NumberFormat('#,###').format(stepsGoal) : '10k'}  •  💧 ${(hydrationGoal / 1000).toStringAsFixed(1)}L  •  💤 ${sleepGoal.toStringAsFixed(1)}h"
                          : "Tap to customize your daily activity targets for today.",
                      style: TextStyle(
                        fontSize: 12,
                        color: hasSetGoalsToday
                            ? const Color(0xFF166534)
                            : const Color(0xFF9F1239),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasSetGoalsToday
                      ? Colors.white
                      : const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasSetGoalsToday
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFE11D48),
                  ),
                ),
                child: Text(
                  hasSetGoalsToday ? "Edit" : "Set Goals",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hasSetGoalsToday
                        ? const Color(0xFF15803D)
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CORE FIRESTORE LOGGING ---
  Future<void> _saveProgressToFirestore({
    double? weight,
    int? hydration,
    double? sleep,
    int? steps,
  }) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Fitness Tracking');
      return;
    }
    if (currentUser?.uid == null) {
      return;
    }
    final String uid = currentUser!.uid;
    final DocumentReference userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);
    final DocumentReference historyRef = userRef
        .collection('progress_history')
        .doc(_todayDate);

    Map<String, dynamic> userUpdates = {};
    Map<String, dynamic> historyUpdates = {
      'date': _todayDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (weight != null) {
      userUpdates['weight'] = weight;
      userUpdates['dailyWeight'] = {_todayDate: weight};
      historyUpdates['weight'] = weight;
    }
    if (hydration != null) {
      userUpdates['dailyHydration'] = {_todayDate: hydration};
      historyUpdates['hydration'] = hydration;
    }
    if (sleep != null) {
      userUpdates['sleep'] = sleep;
      userUpdates['dailySleep'] = {_todayDate: sleep};
      historyUpdates['sleep'] = sleep;
    }
    if (steps != null) {
      userUpdates['steps'] = steps;
      userUpdates['dailySteps'] = {_todayDate: steps};
      historyUpdates['steps'] = steps;
    }

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.set(userRef, userUpdates, SetOptions(merge: true));
      batch.set(historyRef, historyUpdates, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint("Error saving progress: $e");
    }
  }

  Future<void> _changeWater(int currentWater, int amount, int goal) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Hydration Tracking');
      return;
    }
    if (goal <= 0) {
      _showHydrationGoalDialog(amount);
      return;
    }

    int newWaterLevel = (currentWater + amount)
        .clamp(0, double.infinity)
        .toInt();
    HapticFeedback.lightImpact();
    await _saveProgressToFirestore(hydration: newWaterLevel);

    String key = 'hydration_$_todayDate';
    if (currentWater < goal &&
        newWaterLevel >= goal &&
        !_shownDialogs.contains(key)) {
      _shownDialogs.add(key);
      _showSuccessDialog(
        goalName: 'hydration_title'.tr(),
        currentValue:
            '${(newWaterLevel / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L',
        goalValue:
            '${(goal / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L',
      );
    }
  }

  Future<void> _updateWeight(double newWeight) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Weight Tracking');
      return;
    }
    await _saveProgressToFirestore(weight: newWeight);
  }

  Future<void> _updateSleep(
    int oldMinutes,
    int newMinutes,
    double goalHrs,
  ) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Sleep Tracking');
      return;
    }
    if (goalHrs <= 0) {
      _showSleepGoalDialog(newMinutes);
      return;
    }

    double hours = double.parse((newMinutes / 60.0).toStringAsFixed(2));
    await _saveProgressToFirestore(sleep: hours);

    double oldHrs = oldMinutes / 60.0;
    String key = 'sleep_$_todayDate';
    if (oldHrs < goalHrs && hours >= goalHrs && !_shownDialogs.contains(key)) {
      _shownDialogs.add(key);
      _showSuccessDialog(
        goalName: 'sleep_title'.tr(),
        currentValue:
            '${hours.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} hrs',
        goalValue:
            '${goalHrs.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} hrs',
      );
    }
  }

  Future<void> _updateSteps(int oldSteps, int newSteps, int goal) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Steps Tracking');
      return;
    }
    if (goal <= 0) {
      _showStepsGoalDialog(newSteps);
      return;
    }

    await _saveProgressToFirestore(steps: newSteps);

    String key = 'steps_$_todayDate';
    if (oldSteps < goal && newSteps >= goal && !_shownDialogs.contains(key)) {
      _shownDialogs.add(key);
      _showSuccessDialog(
        goalName: 'steps_title'.tr(),
        currentValue: '$newSteps ${'unit_steps'.tr().trim()}',
        goalValue: '$goal ${'unit_steps'.tr().trim()}',
      );
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (_cachedUserData == null) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CustomLoadingIndicator()),
      );
    }

    final userData = _cachedUserData!;
    int currentHydration =
        (userData['dailyHydration'] as Map?)?[_todayDate] ?? 0;
    int currentSteps = (userData['dailySteps'] as Map?)?[_todayDate] ?? 0;
    double currentSleep =
        (userData['dailySleep'] as Map?)?[_todayDate]?.toDouble() ?? 0.0;
    double currentWeight =
        (userData['dailyWeight'] as Map?)?[_todayDate]?.toDouble() ??
        (userData['weight']?.toDouble() ?? 70.0);

    // Today's Daily Goals
    int todayHydrationGoal =
        (userData['dailyHydrationGoals'] as Map?)?[_todayDate] ??
        userData['hydrationGoal'] ??
        0;
    int todayStepsGoal =
        (userData['dailyStepsGoals'] as Map?)?[_todayDate] ??
        userData['stepsGoal'] ??
        0;
    double todaySleepGoal =
        (userData['dailySleepGoals'] as Map?)?[_todayDate]?.toDouble() ??
        (userData['sleepGoal'] as num?)?.toDouble() ??
        0.0;

    String? lastGoalSetDate = userData['dailyGoalSetDate']?.toString();
    bool hasSetGoalsToday = lastGoalSetDate == _todayDate;

    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : _bgColor,
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopAppBar(),
                      const SizedBox(height: 10),

                      SizedBox(
                        height: 380,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (idx) =>
                              setState(() => _currentActivityPage = idx),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            RepaintBoundary(child: _buildActivityLevelChart()),
                            RepaintBoundary(
                              child: _buildHistoricalLog(userData),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [0, 1]
                            .map(
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: _currentActivityPage == i ? 16 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentActivityPage == i
                                      ? _activeBlue
                                      : (isDark
                                            ? const Color(0xFF333333)
                                            : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 18),

                      // Daily Goal Setting Prompt / Status Banner (between Activity Level and Cards)
                      _buildDailyGoalsBanner(
                        userData: userData,
                        hasSetGoalsToday: hasSetGoalsToday,
                        stepsGoal: todayStepsGoal,
                        hydrationGoal: todayHydrationGoal,
                        sleepGoal: todaySleepGoal,
                      ),

                      const SizedBox(height: 18),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: RepaintBoundary(
                                child: _buildHydrationCard(
                                  currentHydration,
                                  todayHydrationGoal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: RepaintBoundary(
                                child: _WeightCard(
                                  initialWeight: currentWeight,
                                  onWeightChanged: _updateWeight,
                                ),
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
                              child: RepaintBoundary(
                                child: _SleepCard(
                                  initialMinutes: (currentSleep * 60).round(),
                                  goalHours: todaySleepGoal,
                                  onSleepChanged: (mins) => _updateSleep(
                                    (currentSleep * 60).round(),
                                    mins,
                                    todaySleepGoal,
                                  ),
                                  onSetupGoal: () => _showSleepGoalDialog(
                                    (currentSleep * 60).round(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: RepaintBoundary(
                                child: _StepsCard(
                                  initialSteps: currentSteps,
                                  goalSteps: todayStepsGoal,
                                  onStepsChanged: (steps) => _updateSteps(
                                    currentSteps,
                                    steps,
                                    todayStepsGoal,
                                  ),
                                  onSetupGoal: () =>
                                      _showStepsGoalDialog(currentSteps),
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
              if (widget.showBottomNav && !isKeyboardOpen) _buildBottomNavBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'progress_title'.tr(),
              style: TextStyle(
                color: AppThemeController.isDark
                    ? const Color(0xFFF5F5F5)
                    : _textMain,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppThemeController.isDark
                  ? const Color(0xFF262626)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: AppThemeController.isDark
                    ? const Color(0xFFF5F5F5)
                    : _textMain,
                size: 24,
              ),
              onPressed: () {
                // --- UPDATED NOTIFICATION ROUTING ---
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

  Widget _buildActivityLevelChart() {
    bool isPositive = !_cachedTrendPercentage.startsWith('-');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeController.isDark
            ? const Color(0xFF121212)
            : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppThemeController.isDark
              ? const Color(0xFF262626)
              : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppThemeController.isDark ? 0.25 : 0.03,
            ),
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
              color: AppThemeController.isDark
                  ? const Color(0xFF1E1E1E)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _timeframes.map((tf) {
                bool isSelected = _selectedTimeframe == tf;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onTimeframeChanged(tf),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (AppThemeController.isDark
                                  ? const Color(0xFF2A2A2A)
                                  : Colors.white)
                            : Colors.transparent,
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
                        _getLocalizedTimeframe(tf),
                        style: TextStyle(
                          color: isSelected
                              ? (AppThemeController.isDark
                                    ? const Color(0xFFF5F5F5)
                                    : _textMain)
                              : Colors.grey.shade600,
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
              Expanded(
                child: Text(
                  'activity_level'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppThemeController.isDark
                        ? const Color(0xFFF5F5F5)
                        : _textMain,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPositive
                      ? _limeGreen.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _cachedTrendPercentage,
                  style: TextStyle(
                    color: isPositive ? Colors.black87 : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _cachedChartData.map((data) {
              double barWidth = _cachedChartData.length > 7 ? 12.0 : 20.0;
              bool isToday =
                  data['label'] ==
                  DateFormat.E(
                    context.locale.toString(),
                  ).format(DateTime.now());
              return Flexible(
                child: Column(
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
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutExpo,
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
                        fontSize: _cachedChartData.length > 7 ? 10 : 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalLog(Map<String, dynamic> userData) {
    Map<String, dynamic> dWeight = userData['dailyWeight'] ?? {};
    Map<String, dynamic> dHydration = userData['dailyHydration'] ?? {};
    Map<String, dynamic> dSleep = userData['dailySleep'] ?? {};
    Map<String, dynamic> dSteps = userData['dailySteps'] ?? {};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 0),
      decoration: BoxDecoration(
        color: AppThemeController.isDark
            ? const Color(0xFF121212)
            : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppThemeController.isDark
              ? const Color(0xFF262626)
              : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppThemeController.isDark ? 0.25 : 0.03,
            ),
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
              Text(
                _historyHeaderMonth,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _activeBlue,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedHistoryDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && mounted) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedHistoryDate = picked;
                      _updateHistoryDates(picked);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _activeBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 22,
                    color: _activeBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemExtent: 68.0,
              padding: const EdgeInsets.only(bottom: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: 15,
              itemBuilder: (context, i) {
                String dateKey = _historyDateKeys[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 35,
                        child: Column(
                          children: [
                            Text(
                              _historyDayNames[i],
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _historyDayNums[i],
                              style: const TextStyle(
                                color: _activeBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCol(
                          'Weight',
                          dWeight[dateKey] != null
                              ? '${(dWeight[dateKey] as num).toStringAsFixed(1)}kg'
                              : '-',
                        ),
                      ),
                      Expanded(
                        child: _statCol(
                          'Water',
                          dHydration[dateKey] != null
                              ? '${((dHydration[dateKey] as num) / 1000).toStringAsFixed(1)}L'
                              : '-',
                        ),
                      ),
                      Expanded(
                        child: _statCol(
                          'Steps',
                          dSteps[dateKey] != null
                              ? NumberFormat('#,###').format(dSteps[dateKey])
                              : '-',
                        ),
                      ),
                      Expanded(
                        child: _statCol(
                          'Sleep',
                          dSleep[dateKey] != null
                              ? '${(dSleep[dateKey] as num).toStringAsFixed(1)}h'
                              : '-',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            val,
            style: const TextStyle(
              color: _activeBlue,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHydrationCard(int currentWater, int goal) {
    const Color waterColor = Color(0xFF00B4D8);
    double fillPercentage = goal > 0
        ? (currentWater / goal).clamp(0.0, 1.0)
        : 0.0;
    bool isWaterHigh = fillPercentage > 0.55;

    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppThemeController.isDark
            ? const Color(0xFF121212)
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppThemeController.isDark
              ? const Color(0xFF262626)
              : waterColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppThemeController.isDark ? 0.25 : 0.03,
            ),
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
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
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
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              color: isWaterHigh
                                  ? Colors.white
                                  : (AppThemeController.isDark
                                        ? const Color(0xFFF5F5F5)
                                        : _textMain),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            child: Text(
                              'hydration_title'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                color: isWaterHigh
                                    ? Colors.white70
                                    : Colors.grey.shade500,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              child: Text(
                                'label_current'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                color: isWaterHigh
                                    ? Colors.white
                                    : (AppThemeController.isDark
                                          ? const Color(0xFFF5F5F5)
                                          : _textMain),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${(currentWater / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (goal <= 0)
                      Center(
                        child: GestureDetector(
                          onTap: () => _showHydrationGoalDialog(currentWater),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'btn_set_goal'.tr(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: waterColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildBottomNavBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppThemeController.isDark
              ? const Color(0xFF121212)
              : const Color.fromARGB(255, 0, 33, 95),
          borderRadius: BorderRadius.circular(40),
          border: AppThemeController.isDark
              ? Border.all(color: const Color(0xFF262626), width: 1.2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppThemeController.isDark ? 0.35 : 0.15,
              ),
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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    MainTabController.switchTab(0);
                  },
                ),
                _NavItem(
                  index: 1,
                  icon: Icons.calendar_today_rounded,
                  label: 'booking_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    MainTabController.switchTab(1);
                  },
                ),
                _NavItem(
                  index: 2,
                  icon: Icons.bar_chart_rounded,
                  label: 'stats_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: () {},
                ),
                _NavItem(
                  index: 3,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'chats_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    MainTabController.switchTab(3);
                  },
                ),
                _NavItem(
                  index: 4,
                  icon: Icons.person_outline_rounded,
                  label: 'profile_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    MainTabController.switchTab(4);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

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
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
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
    if (!_isUserScrolling && widget.initialWeight != oldWidget.initialWeight) {
      double newClamped = widget.initialWeight.clamp(_minWeight, _maxWeight);
      if ((newClamped - _weightNotifier.value).abs() > 0.1 &&
          _scrollController.hasClients) {
        _scrollController.animateTo(
          (newClamped - _minWeight) * _pixelsPerKg,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppThemeController.isDark
            ? const Color(0xFF121212)
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppThemeController.isDark
              ? const Color(0xFF262626)
              : Colors.orange.shade200.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppThemeController.isDark ? 0.25 : 0.03,
            ),
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
                    Expanded(
                      child: Text(
                        'weight_title'.tr(),
                        style: TextStyle(
                          color: AppThemeController.isDark
                              ? const Color(0xFFF5F5F5)
                              : const Color(0xFF1A1A1A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'label_current'.tr(),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              ValueListenableBuilder<double>(
                                valueListenable: _weightNotifier,
                                builder: (context, weight, child) {
                                  return Text(
                                    weight.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: AppThemeController.isDark
                                          ? const Color(0xFFF5F5F5)
                                          : const Color(0xFF1A1A1A),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'unit_kg'.tr(),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 105,
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
                        itemExtent: _pixelsPerTick,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                if (isMajorTick) const SizedBox(height: 6),
                                Container(
                                  width: isMajorTick ? 2.5 : 1.5,
                                  height: isMajorTick ? 36 : 20,
                                  decoration: BoxDecoration(
                                    color: isMajorTick
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 4,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade700,
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
  final int _maxMins = 720;
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
      setState(() => _currentMins = widget.initialMinutes.clamp(0, _maxMins));
    }
  }

  void _handlePan(Offset localPosition, Size size) {
    if (widget.goalHours <= 0) {
      return;
    }

    Offset center = Offset(size.width / 2, size.height / 2);
    double angle = math.atan2(
      localPosition.dy - center.dy,
      localPosition.dx - center.dx,
    );
    double normalized = angle + (math.pi / 2);
    if (normalized < 0) {
      normalized += 2 * math.pi;
    }

    int mins = ((normalized / (2 * math.pi)) * _maxMins).round();
    mins = (mins / 15).round() * 15;

    if (mins != _currentMins) {
      HapticFeedback.selectionClick();
      setState(() => _currentMins = mins.clamp(0, _maxMins));
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
          color: AppThemeController.isDark
              ? const Color(0xFF121212)
              : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppThemeController.isDark
                ? const Color(0xFF262626)
                : _sleepPurple.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppThemeController.isDark ? 0.25 : 0.03,
              ),
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
                  Expanded(
                    child: Text(
                      'sleep_title'.tr(),
                      style: TextStyle(
                        color: AppThemeController.isDark
                            ? const Color(0xFFF5F5F5)
                            : const Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'label_current'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${h}h ${m}m',
                          style: TextStyle(
                            color: AppThemeController.isDark
                                ? const Color(0xFFF5F5F5)
                                : const Color(0xFF1A1A1A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.goalHours <= 0
                  ? Center(
                      child: Text(
                        'btn_set_goal'.tr(),
                        style: const TextStyle(
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

  static final Paint _trackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 12
    ..strokeCap = StrokeCap.round;
  static final Paint _activePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 12
    ..strokeCap = StrokeCap.round;
  static final List<TextPainter> _textPainters = _initTextPainters();

  _SleepDialPainter({
    required this.progress,
    required this.trackColor,
    required this.activeColor,
    required this.radius,
  }) {
    _trackPaint.color = trackColor;
  }

  static List<TextPainter> _initTextPainters() {
    List<TextPainter> painters = [];
    for (int i = 0; i < 12; i++) {
      if (i % 3 == 0) {
        String text = i == 0 ? '12' : (i == 3 ? '3' : (i == 6 ? '6' : '9'));
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();
        painters.add(tp);
      } else {
        painters.add(TextPainter());
      }
    }
    return painters;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, radius, _trackPaint);

    final sweepAngle = progress * 2 * math.pi;
    final gradient = const SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [Color(0xFF5A67D8), Color(0xFF9F7AEA)],
      stops: [0.0, 1.0],
    );

    _activePaint.shader = gradient.createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        _activePaint,
      );
    }

    for (int i = 0; i < 12; i++) {
      double angle = -math.pi / 2 + (i * 2 * math.pi / 12);
      if (i % 3 != 0) {
        canvas.drawLine(
          Offset(
            center.dx + (radius - 12) * math.cos(angle),
            center.dy + (radius - 12) * math.sin(angle),
          ),
          Offset(
            center.dx + (radius - 8) * math.cos(angle),
            center.dy + (radius - 8) * math.sin(angle),
          ),
          Paint()
            ..color = Colors.grey.shade400
            ..strokeWidth = 1.0,
        );
      } else {
        final textPainter = _textPainters[i];
        textPainter.paint(
          canvas,
          Offset(
            center.dx + (radius - 22) * math.cos(angle) - textPainter.width / 2,
            center.dy +
                (radius - 22) * math.sin(angle) -
                textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SleepDialPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.radius != radius;
}

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
  bool _isUserScrolling = false;
  static const Color _stepsColor = Colors.lightGreen;

  @override
  void initState() {
    super.initState();
    _currentSteps = widget.initialSteps;
    _scrollController = FixedExtentScrollController(
      initialItem: (_currentSteps ~/ _stepIncrement),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StepsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isUserScrolling &&
        widget.initialSteps != oldWidget.initialSteps &&
        widget.initialSteps != _currentSteps) {
      _currentSteps = widget.initialSteps;
      if (_scrollController.hasClients) {
        _scrollController.animateToItem(
          (_currentSteps ~/ _stepIncrement),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.goalSteps <= 0) {
          widget.onSetupGoal();
        }
      },
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: AppThemeController.isDark
              ? const Color(0xFF121212)
              : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppThemeController.isDark
                ? const Color(0xFF262626)
                : _stepsColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppThemeController.isDark ? 0.25 : 0.03,
              ),
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
                  Expanded(
                    child: Text(
                      'steps_title'.tr(),
                      style: TextStyle(
                        color: AppThemeController.isDark
                            ? const Color(0xFFF5F5F5)
                            : const Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'label_current'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$_currentSteps',
                          style: TextStyle(
                            color: AppThemeController.isDark
                                ? const Color(0xFFF5F5F5)
                                : const Color(0xFF1A1A1A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.goalSteps <= 0
                  ? Center(
                      child: Text(
                        'btn_set_goal'.tr(),
                        style: const TextStyle(
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
                            if (notification is ScrollStartNotification) {
                              _isUserScrolling = true;
                            } else if (notification is ScrollEndNotification) {
                              _isUserScrolling = false;
                              widget.onStepsChanged(_currentSteps);
                            }
                            return true;
                          },
                          child: ListWheelScrollView.useDelegate(
                            controller: _scrollController,
                            itemExtent: 50,
                            physics: const FixedExtentScrollPhysics(),
                            perspective: 0.005,
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              setState(
                                () => _currentSteps = index * _stepIncrement,
                              );
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                bool isSelected =
                                    (index * _stepIncrement) == _currentSteps;
                                return Center(
                                  child: RichText(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                                ? (AppThemeController.isDark
                                                      ? const Color(0xFFF5F5F5)
                                                      : const Color(0xFF1A1A1A))
                                                : Colors.grey.shade500,
                                          ),
                                        ),
                                        if (isSelected)
                                          TextSpan(
                                            text: 'unit_steps'.tr(),
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
                              childCount: ((_maxSteps ~/ _stepIncrement) + 1),
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

class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _BouncingButton({required this.child, required this.onTap});
  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
