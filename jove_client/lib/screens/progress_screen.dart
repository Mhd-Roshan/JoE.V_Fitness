import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  // Caching today's date so it isn't recalculated on every single frame
  late final String _todayDate;

  @override
  void initState() {
    super.initState();
    _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final String uid = currentUser?.uid ?? '';
    // includeMetadataChanges ensures immediate cache emission, reducing transition lag
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true);
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseActivityData(
    dynamic dbData,
    List<String> labels,
  ) {
    List<Map<String, dynamic>> defaultData = labels
        .map((label) => {'label': label, 'value': 0.0})
        .toList();

    if (dbData != null && dbData is Map) {
      return defaultData.map((e) {
        String label = e['label'];
        double val = 0.0;
        if (dbData[label] != null) {
          val = num.parse(dbData[label].toString()).toDouble();
        }
        return {'label': label, 'value': val > 1.0 ? 1.0 : val};
      }).toList();
    }

    return defaultData;
  }

  List<Map<String, dynamic>> _getChartData(Map<String, dynamic> userData) {
    if (_selectedTimeframe == 'Monthly') {
      return _parseActivityData(userData['monthlyActivity'], const [
        'W1',
        'W2',
        'W3',
        'W4',
      ]);
    } else if (_selectedTimeframe == 'Yearly') {
      return _parseActivityData(userData['yearlyActivity'], const [
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
      ]);
    } else {
      return _parseActivityData(userData['weeklyActivity'], const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ]);
    }
  }

  Future<void> _showGoalDialog(int initialAmount) async {
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
              const Text(
                'How many Liters of water do you want to drink daily?',
                style: TextStyle(color: Colors.black87),
              ),
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
                'Save Goal',
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
    if (goal == 0) {
      _showGoalDialog(amount);
      return;
    }

    final uid = currentUser?.uid;
    if (uid != null) {
      int newWaterLevel = currentWater + amount;
      if (newWaterLevel < 0) newWaterLevel = 0;

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'dailyHydration': {_todayDate: newWaterLevel},
        }, SetOptions(merge: true));
        HapticFeedback.lightImpact();
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

  Future<void> _navigateToBooking(Map<String, dynamic> userData) async {
    _selectedIndexNotifier.value = 1;

    try {
      String? trainerId = userData['assignedTrainerId'];

      if (trainerId == null || trainerId.isEmpty) {
        if (!mounted) return;
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, a, b) => const SelectTrainerScreen(),
            transitionsBuilder: (context, a, b, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
        if (mounted) _selectedIndexNotifier.value = 2;
        return;
      }

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

      if (!mounted) return;

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
        _selectedIndexNotifier.value = 2;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading booking data.')),
      );
      _selectedIndexNotifier.value = 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          // If completely empty (no cache, no network), show minimal skeleton to prevent layout jumps
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          Map<String, dynamic> dailyHydrationMap =
              userData['dailyHydration'] != null
              ? Map<String, dynamic>.from(userData['dailyHydration'])
              : {};
          int currentWater = dailyHydrationMap[_todayDate] ?? 0;
          int waterGoal = userData['hydrationGoal'] ?? 0;

          Map<String, dynamic> dailyWeightMap = userData['dailyWeight'] != null
              ? Map<String, dynamic>.from(userData['dailyWeight'])
              : {};
          double currentWeight = 70.0;
          if (dailyWeightMap[_todayDate] != null) {
            currentWeight = num.parse(
              dailyWeightMap[_todayDate].toString(),
            ).toDouble();
          } else if (userData['weight'] != null) {
            currentWeight = num.parse(userData['weight'].toString()).toDouble();
          }

          List<Map<String, dynamic>> chartData = _getChartData(userData);

          return Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- TOP APP BAR ---
                      _buildTopAppBar(),
                      const SizedBox(height: 10),

                      // --- ACTIVITY LEVEL SECTION ---
                      _buildActivityLevelChart(chartData),
                      const SizedBox(height: 24),

                      // --- HYDRATION & WEIGHT ROW ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            // Hydration Card
                            Expanded(
                              child: _buildHydrationCard(
                                currentWater,
                                waterGoal,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Weight Card with Slider
                            Expanded(
                              child: _WeightCard(
                                initialWeight: currentWeight,
                                onWeightChanged: _updateWeight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24), // Extra padding at bottom
                    ],
                  ),
                ),
              ),

              // --- BOTTOM NAV BAR ---
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
                    onTap: () {
                      setState(() {
                        _selectedTimeframe = tf;
                      });
                    },
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

  // UPDATED Hydration Card - Taller & Smoother
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
      height: 175, // Increased Height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
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
                            fontSize:
                                14, // Slightly larger font to fit taller card
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
                                fontSize: 18, // Slightly larger
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
                          width: 48, // Slightly larger button
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
                        pageBuilder: (context, a, b) =>
                            const HomeDashboardScreen(),
                        transitionsBuilder: (context, a, b, child) =>
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
// CUSTOM WEIGHT CARD WITH SCROLLING RULER - Taller
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
  late double _currentWeight;

  final double _minWeight = 20.0;
  final double _maxWeight = 250.0;
  final double _pixelsPerTick = 8.0;

  double get _pixelsPerKg => _pixelsPerTick * 10.0;

  @override
  void initState() {
    super.initState();
    _currentWeight = widget.initialWeight.clamp(_minWeight, _maxWeight);

    double initialOffset = (_currentWeight - _minWeight) * _pixelsPerKg;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Handle external updates so it stays in sync smoothly
  @override
  void didUpdateWidget(covariant _WeightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialWeight != oldWidget.initialWeight &&
        (widget.initialWeight - _currentWeight).abs() > 0.1) {
      _currentWeight = widget.initialWeight.clamp(_minWeight, _maxWeight);
      double offset = (_currentWeight - _minWeight) * _pixelsPerKg;
      // Animate smoothly to new position if updated externally
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 175, // Increased Height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
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
              // Top Title and Current Value
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
                        fontSize: 14, // Larger font
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
                            Text(
                              _currentWeight.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 18, // Larger font
                                fontWeight: FontWeight.w900,
                              ),
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

              // Ruler Section
              SizedBox(
                height: 70, // Slightly taller ruler area
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification) {
                          double offset = _scrollController.offset;
                          double calculatedWeight =
                              _minWeight + (offset / _pixelsPerKg);
                          double newWeight = calculatedWeight.clamp(
                            _minWeight,
                            _maxWeight,
                          );
                          newWeight = double.parse(
                            newWeight.toStringAsFixed(1),
                          );

                          // Optimization: Only rebuild if the rounded weight actually changed
                          if (newWeight != _currentWeight) {
                            setState(() {
                              _currentWeight = newWeight;
                            });
                          }
                        } else if (notification is ScrollEndNotification) {
                          widget.onWeightChanged(_currentWeight);
                          HapticFeedback.selectionClick();
                        }
                        return true;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                if (isMajorTick) const SizedBox(height: 4),
                                Container(
                                  width: 2,
                                  height: isMajorTick ? 24 : 14, // Taller ticks
                                  decoration: BoxDecoration(
                                    color: isMajorTick
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                const SizedBox(
                                  height: 10,
                                ), // Padding from bottom
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Orange Center Pointer Indicator
                    Positioned(
                      bottom: 10, // Aligns with the ticks
                      child: Container(
                        width: 4,
                        height: 32, // Taller pointer
                        decoration: BoxDecoration(
                          color: Colors.orange.shade500,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.4),
                              blurRadius: 4,
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
        duration: const Duration(milliseconds: 200), // Sped up animation
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
