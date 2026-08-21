import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'trainer_selection_screen.dart';
import 'progress_screen.dart';
import 'home_dashboard_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class _Formatters {
  static final Map<String, DateFormat> _time = {};
  static final Map<String, DateFormat> _dbDate = {};
  static final Map<String, DateFormat> _full = {};
  static final Map<String, DateFormat> _monthYear = {};
  static final Map<String, DateFormat> _dayName = {};
  static final Map<String, DateFormat> _dayNum = {};

  static DateFormat time(String loc) =>
      _time.putIfAbsent(loc, () => DateFormat('h:mm a', loc));
  static DateFormat dbDate(String loc) =>
      _dbDate.putIfAbsent(loc, () => DateFormat('yyyy-MM-dd', loc));
  static DateFormat full(String loc) =>
      _full.putIfAbsent(loc, () => DateFormat('EEEE, MMM d', loc));
  static DateFormat monthYear(String loc) =>
      _monthYear.putIfAbsent(loc, () => DateFormat('MMMM yyyy', loc));
  static DateFormat dayName(String loc) =>
      _dayName.putIfAbsent(loc, () => DateFormat('EEE', loc));
  static DateFormat dayNum(String loc) =>
      _dayNum.putIfAbsent(loc, () => DateFormat('dd', loc));
}

class BookingScreen extends StatefulWidget {
  final Trainer? trainer;
  final String? trainerId;

  const BookingScreen({super.key, this.trainer, this.trainerId});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Trainer? _trainer;
  bool _isLoadingTrainer = false;

  DateTime? _selectedDate;
  String? _selectedSession;
  TimeOfDay? _selectedTime;

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(1);
  final ScrollController _dateScrollController = ScrollController();

  bool _isChecking = false;
  bool _isNavigating = false;
  String _availabilityStatus = 'none';

  List<Map<String, dynamic>> _trainerSessions = [];
  late List<DateTime> _cachedVisibleDates;

  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _activeBlue = Color(0xFF003AA3);
  static const Color _redButtonColor = Color(0xFFBB0013);

  @override
  void initState() {
    super.initState();

    if (widget.trainer != null) {
      _trainer = widget.trainer;
      _initializeScreen();
    } else if (widget.trainerId != null) {
      _isLoadingTrainer = true;
      _fetchTrainerAndInitialize(widget.trainerId!);
    }
  }

  void _initializeScreen() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    _cachedVisibleDates = [];

    for (int i = -15; i <= 30; i++) {
      DateTime date = today.add(Duration(days: i));
      if (date.weekday != DateTime.sunday) {
        _cachedVisibleDates.add(date);
      }
    }

    _selectedDate = today.weekday == DateTime.sunday
        ? today.add(const Duration(days: 1))
        : today;

    _loadTrainerSpecializations();
    _selectedTime = const TimeOfDay(hour: 8, minute: 30);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  Future<void> _fetchTrainerAndInitialize(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trainers')
          .doc(id)
          .get(const GetOptions(source: Source.cache))
          .catchError(
            (_) =>
                FirebaseFirestore.instance.collection('trainers').doc(id).get(),
          );

      if (doc.exists && mounted) {
        _trainer = Trainer.fromFirestore(doc);
        _initializeScreen();
      }
    } catch (e) {
      debugPrint('Error fetching trainer: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTrainer = false);
      }
    }
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    _dateScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    if (!_dateScrollController.hasClients || _selectedDate == null) {
      return;
    }

    int index = _cachedVisibleDates.indexWhere(
      (date) =>
          date.year == _selectedDate!.year &&
          date.month == _selectedDate!.month &&
          date.day == _selectedDate!.day,
    );

    if (index == -1) {
      return;
    }

    const double itemWidth = 70.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double centerOfItem = 24.0 + (index * itemWidth) + (58.0 / 2);
    double targetOffset = centerOfItem - (screenWidth / 2);

    targetOffset = targetOffset.clamp(
      0.0,
      _dateScrollController.position.maxScrollExtent,
    );

    _dateScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleStandardNavigation(Widget screen, int index) async {
    if (_isNavigating) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isNavigating = true);

    _selectedIndexNotifier.value = index;

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, b) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 150),
      ),
    );

    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  String _formatTimeStrict(TimeOfDay time, String locale) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return _Formatters.time(locale).format(dt);
  }

  void _loadTrainerSpecializations() {
    if (_trainer != null && _trainer!.specializations.isNotEmpty) {
      _trainerSessions = _trainer!.specializations.map((spec) {
        return {'name': spec, ..._getVisualsForSpecialization(spec)};
      }).toList();
    } else {
      _trainerSessions = [
        {
          'name': 'general_training'.tr(),
          'sub': 'customized_workout'.tr(),
          'icon': Icons.fitness_center,
        },
      ];
    }
    _selectedSession = _trainerSessions.first['name'];
  }

  Map<String, dynamic> _getVisualsForSpecialization(String spec) {
    final String lowerSpec = spec.toLowerCase();
    if (lowerSpec.contains('strength') ||
        lowerSpec.contains('power') ||
        lowerSpec.contains('weight')) {
      return {'sub': 'focused_power_form'.tr(), 'icon': Icons.fitness_center};
    } else if (lowerSpec.contains('hiit') ||
        lowerSpec.contains('cardio') ||
        lowerSpec.contains('cycling') ||
        lowerSpec.contains('running')) {
      return {
        'sub': 'max_calorie_burn'.tr(),
        'icon': Icons.directions_run_rounded,
      };
    }
    return {
      'sub': 'personalized_training'.tr(),
      'icon': Icons.sports_gymnastics,
    };
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedTime = picked;
      _availabilityStatus = 'none';
    });
  }

  Future<void> _checkAvailability() async {
    if (_selectedTime == null || _selectedDate == null || _trainer == null) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isChecking = true;
      _availabilityStatus = 'none';
    });

    try {
      final DateTime now = DateTime.now();
      final DateTime selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (selectedDateTime.isBefore(now)) {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _availabilityStatus = 'past';
          });
        }
        return;
      }

      final String locale = context.locale.languageCode;
      final String dbDate = _Formatters.dbDate(locale).format(_selectedDate!);
      final String dbTime = _formatTimeStrict(_selectedTime!, locale);

      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('trainerId', isEqualTo: _trainer!.id)
          .where('date', isEqualTo: dbDate)
          .where('time', isEqualTo: dbTime)
          .get();

      final bool isTaken = snapshot.docs.any(
        (doc) => doc.data()['status'] != 'cancelled',
      );

      if (mounted) {
        setState(() {
          _isChecking = false;
          _availabilityStatus = isTaken ? 'taken' : 'available';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _availabilityStatus = 'error';
        });
      }
    }
  }

  void _showConfirmationBottomSheet(String locale) {
    HapticFeedback.selectionClick();

    final String formattedDate = _Formatters.full(
      locale,
    ).format(_selectedDate!);
    final String formattedTime = _formatTimeStrict(_selectedTime!, locale);
    final Map<String, dynamic> activeSessionData = _trainerSessions.firstWhere(
      (s) => s['name'] == _selectedSession,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        bool localIsBooking = false;
        bool isSuccess = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(36),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutBack,
                        child: isSuccess
                            ? _buildSuccessView(context)
                            : _buildConfirmView(
                                context,
                                activeSessionData,
                                formattedDate,
                                formattedTime,
                                localIsBooking,
                                locale,
                                (bool state) =>
                                    setModalState(() => localIsBooking = state),
                                () {
                                  HapticFeedback.heavyImpact();
                                  setModalState(() => isSuccess = true);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConfirmView(
    BuildContext context,
    Map<String, dynamic> activeSessionData,
    String formattedDate,
    String formattedTime,
    bool isBooking,
    String locale,
    Function(bool) setBookingState,
    VoidCallback onSuccess,
  ) {
    return Padding(
      key: const ValueKey('confirm_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7BA6F5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'selected_session'.tr(),
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'confirm_session_title'.tr(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  activeSessionData['icon'],
                  color: Colors.blueAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedSession ?? '',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeSessionData['sub'],
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: Colors.grey.shade500,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'date'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey.shade500,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'time'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$formattedTime (60M)',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),
          _BouncingButton(
            onTap: isBooking
                ? null
                : () async {
                    setBookingState(true);
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null && _trainer != null) {
                        await FirebaseFirestore.instance
                            .collection('bookings')
                            .add({
                              'userId': user.uid,
                              'trainerId': _trainer!.id,
                              'trainerName': _trainer!.name,
                              'date': _Formatters.dbDate(
                                locale,
                              ).format(_selectedDate!),
                              'time': _formatTimeStrict(_selectedTime!, locale),
                              'sessionType': _selectedSession,
                              'status': 'confirmed',
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                      }
                      if (!context.mounted) {
                        return;
                      }
                      onSuccess();
                    } catch (e) {
                      if (!context.mounted) {
                        return;
                      }
                      setBookingState(false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('failed_to_book'.tr())),
                      );
                    }
                  },
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _redButtonColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: isBooking
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'confirm_session_btn'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _BouncingButton(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 1.5),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'edit_session'.tr(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Padding(
      key: const ValueKey('success_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: const [
              Icon(
                Icons.verified,
                color: Color.fromARGB(255, 78, 255, 131),
                size: 85,
              ),
              Icon(Icons.check, color: Colors.black, size: 40, weight: 800),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'successful'.tr(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'session_booked_success'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          _BouncingButton(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, a, b) => const HomeDashboardScreen(),
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
                (route) => false,
              );
            },
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _redButtonColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(
                'done'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
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
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'booking_title'.tr(),
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTrainer || _trainer == null) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: _activeBlue),
        ),
      );
    }

    final String locale = context.locale.languageCode;
    final String monthYear = _Formatters.monthYear(
      locale,
    ).format(_selectedDate!);

    return Scaffold(
      backgroundColor: _bgColor,
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopAppBar(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'schedule'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _textMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          monthYear,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _textMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    height: 88,
                    width: double.infinity,
                    child: SingleChildScrollView(
                      controller: _dateScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: _cachedVisibleDates.map((date) {
                          final bool isSelected =
                              _selectedDate!.year == date.year &&
                              _selectedDate!.month == date.month &&
                              _selectedDate!.day == date.day;
                          final String dayName = _Formatters.dayName(
                            locale,
                          ).format(date);
                          final String dayNumber = _Formatters.dayNum(
                            locale,
                          ).format(date);

                          return _BouncingButton(
                            onTap: () {
                              setState(() {
                                _selectedDate = date;
                                _availabilityStatus = 'none';
                              });
                              _scrollToSelectedDate();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.only(right: 12),
                              width: 58,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? _activeBlue : Colors.white,
                                borderRadius: BorderRadius.circular(35),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _activeBlue.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dayName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade500,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      dayNumber,
                                      style: TextStyle(
                                        color: isSelected
                                            ? _activeBlue
                                            : _textMain,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 44),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'available_sessions'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _SessionSelectionList(
                    trainerSessions: _trainerSessions,
                    onSessionSelected: (sessionName) {
                      setState(() {
                        _selectedSession = sessionName;
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
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
                        Text(
                          'select_time'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _BouncingButton(
                                onTap: _pickTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _bgColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedTime == null
                                            ? 'choose'.tr()
                                            : _formatTimeStrict(
                                                _selectedTime!,
                                                locale,
                                              ),
                                        style: const TextStyle(
                                          color: _textMain,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _BouncingButton(
                              onTap: _isChecking ? null : _checkAvailability,
                              child: Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _redButtonColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: _isChecking
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'check'.tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),

                        if (_availabilityStatus == 'available') ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'time_available'.tr(),
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_availabilityStatus == 'taken') ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'slot_booked'.tr(),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_availabilityStatus == 'past') ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.access_time_filled,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'cannot_book_past'.tr(),
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_availabilityStatus == 'available') ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _BouncingButton(
                        onTap: () => _showConfirmationBottomSheet(locale),
                        child: Container(
                          width: double.infinity,
                          height: 55,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _redButtonColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'proceed_to_book'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          RepaintBoundary(
            child: Align(
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
                          label: 'home_nav'.tr(),
                          selectedIndex: selectedIndex,
                          onTap: () => _handleStandardNavigation(
                            const HomeDashboardScreen(),
                            0,
                          ),
                        ),
                        _NavItem(
                          index: 1,
                          icon: Icons.calendar_today_rounded,
                          label: 'booking_nav'.tr(),
                          selectedIndex: selectedIndex,
                          onTap: () {},
                        ),
                        _NavItem(
                          index: 2,
                          icon: Icons.bar_chart_rounded,
                          label: 'stats_nav'.tr(),
                          selectedIndex: selectedIndex,
                          onTap: () => _handleStandardNavigation(
                            const ProgressScreen(),
                            2,
                          ),
                        ),
                        _NavItem(
                          index: 3,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'chats_nav'.tr(),
                          selectedIndex: selectedIndex,
                          onTap: () =>
                              _handleStandardNavigation(const ChatScreen(), 3),
                        ),
                        _NavItem(
                          index: 4,
                          icon: Icons.person_outline_rounded,
                          label: 'profile_nav'.tr(),
                          selectedIndex: selectedIndex,
                          onTap: () => _handleStandardNavigation(
                            const ProfileScreen(),
                            4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSelectionList extends StatefulWidget {
  final List<Map<String, dynamic>> trainerSessions;
  final Function(String) onSessionSelected;

  const _SessionSelectionList({
    required this.trainerSessions,
    required this.onSessionSelected,
  });

  @override
  State<_SessionSelectionList> createState() => _SessionSelectionListState();
}

class _SessionSelectionListState extends State<_SessionSelectionList> {
  String? _localSelectedSession;

  @override
  void initState() {
    super.initState();
    if (widget.trainerSessions.isNotEmpty) {
      _localSelectedSession = widget.trainerSessions.first['name'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: widget.trainerSessions.map((session) {
            final bool isSelected = _localSelectedSession == session['name'];
            return _BouncingButton(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _localSelectedSession = session['name']);
                widget.onSessionSelected(session['name']);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.fromLTRB(6, 6, 20, 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD4FF4E) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFD4FF4E,
                            ).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        session['icon'],
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      session['name'],
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
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
    final bool isSelected = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
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
