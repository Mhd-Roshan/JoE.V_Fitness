import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS (Handles DateFormat automatically)

import 'trainer_selection_screen.dart';
import 'progress_screen.dart';
import 'home_dashboard_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class BookingScreen extends StatefulWidget {
  final Trainer trainer;

  const BookingScreen({super.key, required this.trainer});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _selectedDate;
  String? _selectedSession;
  TimeOfDay? _selectedTime;

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(1);

  bool _isChecking = false;
  bool _isNavigating = false;
  String _availabilityStatus = 'none';

  List<Map<String, dynamic>> _trainerSessions = [];

  late List<DateTime> _cachedVisibleDates;
  final ScrollController _sessionsScrollController = ScrollController();
  bool _userInteractedWithSessions = false;

  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _activeBlue = Color(0xFF003AA3);
  static const Color _redButtonColor = Color(0xFFBB0013);
  static const Color _limeGreen = Color(0xFFD4FF4E);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    _cachedVisibleDates = List.generate(
      15,
      (index) => _selectedDate!.add(Duration(days: index - 2)),
    );

    _loadTrainerSpecializations();
    _selectedTime = const TimeOfDay(hour: 8, minute: 30);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startSessionAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    _sessionsScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleStandardNavigation(Widget screen, int index) async {
    if (_isNavigating) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isNavigating = true);
    _selectedIndexNotifier.value = index;

    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, b) => screen,
        transitionsBuilder: (context, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 150),
      ),
    );

    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  void _startSessionAutoScroll() {
    Future.delayed(const Duration(seconds: 1), _scrollSessionsForward);
  }

  void _scrollSessionsForward() {
    if (!mounted ||
        !_sessionsScrollController.hasClients ||
        _userInteractedWithSessions) {
      return;
    }

    final maxScroll = _sessionsScrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      _sessionsScrollController
          .animateTo(
            maxScroll,
            duration: const Duration(seconds: 3), // Sped up for smoother feel
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (mounted && !_userInteractedWithSessions) {
              Future.delayed(
                const Duration(seconds: 1),
                _scrollSessionsBackward,
              );
            }
          });
    }
  }

  void _scrollSessionsBackward() {
    if (!mounted ||
        !_sessionsScrollController.hasClients ||
        _userInteractedWithSessions) {
      return;
    }

    _sessionsScrollController
        .animateTo(
          0,
          duration: const Duration(seconds: 3), // Sped up for smoother feel
          curve: Curves.easeInOut,
        )
        .then((_) {
          if (mounted && !_userInteractedWithSessions) {
            Future.delayed(const Duration(seconds: 1), _scrollSessionsForward);
          }
        });
  }

  String _formatTimeStrict(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a', context.locale.languageCode).format(dt);
  }

  void _loadTrainerSpecializations() {
    if (widget.trainer.specializations.isNotEmpty) {
      _trainerSessions = widget.trainer.specializations.map((spec) {
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
    String lowerSpec = spec.toLowerCase();
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

    if (!mounted) {
      return;
    }

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _availabilityStatus = 'none';
      });
    }
  }

  Future<void> _checkAvailability() async {
    if (_selectedTime == null || _selectedDate == null) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isChecking = true;
      _availabilityStatus = 'none';
    });

    try {
      DateTime now = DateTime.now();
      DateTime selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (selectedDateTime.isBefore(now)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isChecking = false;
          _availabilityStatus = 'past';
        });
        return;
      }

      String dbDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      String dbTime = _formatTimeStrict(_selectedTime!);

      var snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('trainerId', isEqualTo: widget.trainer.id)
          .where('date', isEqualTo: dbDate)
          .where('time', isEqualTo: dbTime)
          .get();

      bool isTaken = snapshot.docs.any((doc) {
        var data = doc.data();
        return data['status'] != 'cancelled';
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _isChecking = false;
        _availabilityStatus = isTaken ? 'taken' : 'available';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isChecking = false;
        _availabilityStatus = 'error';
      });
    }
  }

  void _showConfirmationBottomSheet() {
    HapticFeedback.selectionClick();
    String formattedDate = DateFormat(
      'EEEE, MMM d',
      context.locale.languageCode,
    ).format(_selectedDate!);
    String formattedTime = _formatTimeStrict(_selectedTime!);
    Map<String, dynamic> activeSessionData = _trainerSessions.firstWhere(
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
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(36),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
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
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                            child: SizeTransition(
                              sizeFactor: animation,
                              child: child,
                            ),
                          );
                        },
                        child: isSuccess
                            ? _buildSuccessView(context)
                            : _buildConfirmView(
                                context,
                                activeSessionData,
                                formattedDate,
                                formattedTime,
                                localIsBooking,
                                (bool bookingState) {
                                  setModalState(() {
                                    localIsBooking = bookingState;
                                  });
                                },
                                () {
                                  HapticFeedback.heavyImpact();
                                  setModalState(() {
                                    isSuccess = true;
                                  });
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

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isBooking
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      setBookingState(true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          String dbDate = DateFormat(
                            'yyyy-MM-dd',
                          ).format(_selectedDate!);
                          String dbTime = _formatTimeStrict(_selectedTime!);
                          await FirebaseFirestore.instance
                              .collection('bookings')
                              .add({
                                'userId': user.uid,
                                'trainerId': widget.trainer.id,
                                'trainerName': widget.trainer.name,
                                'date': dbDate,
                                'time': dbTime,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: _redButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
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

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blue, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
              label: Text(
                'edit_session'.tr(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pushAndRemoveUntil(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, a, b) => const HomeDashboardScreen(),
                    transitionsBuilder: (context, a, b, child) =>
                        FadeTransition(opacity: a, child: child),
                    transitionDuration: const Duration(milliseconds: 150),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _redButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
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
              onPressed: () {
                HapticFeedback.lightImpact();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Localized Month-Year string
    String monthYear = DateFormat(
      'MMMM yyyy',
      context.locale.languageCode,
    ).format(_selectedDate!);
    List<Map<String, dynamic>> displayedSessions = _trainerSessions;

    return Scaffold(
      backgroundColor: _bgColor,
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

                  RepaintBoundary(
                    child: SizedBox(
                      height: 88,
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: _cachedVisibleDates.map((date) {
                            bool isSelected =
                                _selectedDate != null &&
                                _selectedDate!.year == date.year &&
                                _selectedDate!.month == date.month &&
                                _selectedDate!.day == date.day;
                            String dayName = DateFormat(
                              'EEE',
                              context.locale.languageCode,
                            ).format(date); // Localized day name
                            String dayNumber = DateFormat('dd').format(date);

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedDate = date;
                                  _availabilityStatus = 'none';
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.only(right: 12),
                                width: 58,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _activeBlue
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(35),
                                  border: isSelected
                                      ? Border.all(color: Colors.transparent)
                                      : Border.all(
                                          color: Colors.grey.shade300,
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
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.02,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
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

                  RepaintBoundary(
                    child: SizedBox(
                      height: 52,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo is UserScrollNotification) {
                            _userInteractedWithSessions = true;
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _sessionsScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: displayedSessions.map((session) {
                              bool isSelected =
                                  _selectedSession == session['name'];
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(
                                    () => _selectedSession = session['name'],
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    6,
                                    20,
                                    6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _limeGreen
                                        : Colors.white,
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
                                              color: _limeGreen.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.02,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
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
                                          color: _textMain,
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
                      ),
                    ),
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
                              child: GestureDetector(
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
                                            : _formatTimeStrict(_selectedTime!),
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
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isChecking
                                    ? null
                                    : _checkAvailability,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _redButtonColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
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
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  if (_availabilityStatus == 'available') ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _showConfirmationBottomSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _redButtonColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
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
                          onTap: () {
                            HapticFeedback.selectionClick();
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
