import 'dart:ui'; // Needed for ImageFilter.blur (frosted glass)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trainer_selection_screen.dart'; // Ensure this points to where your Trainer class is
import 'home_dashboard_screen.dart'; // Change to your actual home screen import

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

  final bool _showAllSessions = false;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(1);

  bool _isChecking = false;
  String _availabilityStatus = 'none';

  List<Map<String, dynamic>> _trainerSessions = [];

  // CACHED DATES FOR PERFORMANCE
  late List<DateTime> _cachedVisibleDates;

  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);

  // Custom colors requested
  static const Color _activeBlue = Color(0xFF003AA3); // Current selection color
  static const Color _redButtonColor = Color(0xFFBB0013); // Button color
  static const Color _limeGreen = Color(
    0xFFD4FF4E,
  ); // Light vibrant green for sessions

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    // Generate dates once to optimize speed and smoothness
    _cachedVisibleDates = List.generate(
      15,
      (index) => _selectedDate!.add(Duration(days: index - 2)),
    );

    _loadTrainerSpecializations();
    _selectedTime = const TimeOfDay(hour: 8, minute: 30);
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  String _formatTimeStrict(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  void _loadTrainerSpecializations() {
    if (widget.trainer.specializations.isNotEmpty) {
      _trainerSessions = widget.trainer.specializations.map((spec) {
        return {'name': spec, ..._getVisualsForSpecialization(spec)};
      }).toList();
    } else {
      _trainerSessions = [
        {
          'name': 'General Training',
          'sub': 'Customized workout session',
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
      return {'sub': 'Focused on power and form', 'icon': Icons.fitness_center};
    } else if (lowerSpec.contains('hiit') ||
        lowerSpec.contains('cardio') ||
        lowerSpec.contains('cycling') ||
        lowerSpec.contains('running')) {
      return {
        'sub': 'Maximum calorie burn',
        'icon': Icons.directions_run_rounded,
      };
    }
    return {'sub': 'Personalized training', 'icon': Icons.sports_gymnastics};
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _availabilityStatus = 'none'; // Reset status when time changes
      });
    }
  }

  void _checkAvailability() {
    if (_selectedTime == null || _selectedDate == null) return;
    setState(() {
      _isChecking = true;
    });

    // Reduced delay for faster, snappier feel
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _availabilityStatus = 'available'; // Shows the proceed button
      });
    });
  }

  // --- SINGLE STATEFUL BOTTOM SHEET (Handles both Confirm & Success Views) ---
  void _showConfirmationBottomSheet() {
    String formattedDate = DateFormat('EEEE, MMM d').format(_selectedDate!);
    String formattedTime = _formatTimeStrict(_selectedTime!);
    Map<String, dynamic> activeSessionData = _trainerSessions.firstWhere(
      (s) => s['name'] == _selectedSession,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Crucial for frosted glass to show
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        bool localIsBooking = false;
        bool isSuccess = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Frosted blur
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.9,
                  ), // Semi-transparent white
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
                      // Native-style Drag Handle
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

                      // ANIMATED SWITCHER: Swaps Confirm UI for Success UI smoothly
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
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

  // --- VIEW 1: CONFIRMATION UI ---
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
              'Selected session',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Confirm Session',
            style: TextStyle(
              color: Colors.black, // Dark text on white bg
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
                        color: Colors.black, // Dark text
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeSessionData['sub'],
                      style: TextStyle(
                        color: Colors.grey.shade600, // Dark grey text
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
          Divider(color: Colors.grey.shade200, height: 1), // Light divider
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
                        'Date',
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
                      color: Colors.black, // Dark text
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
                        'Time',
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
                      color: Colors.black, // Dark text
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Proceed Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isBooking
                  ? null
                  : () async {
                      setBookingState(true); // Show loading spinner
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
                        if (!context.mounted) return;

                        // Stop loading and transition to Success View
                        onSuccess();
                      } catch (e) {
                        if (!context.mounted) return;
                        setBookingState(false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to book session.'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _redButtonColor, // #BB0013
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirm session',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Edit Button (Blue Outline)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Colors.blue, // Blue border
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(
                Icons.edit,
                color: Colors.blue, // Blue icon
                size: 18,
              ),
              label: const Text(
                'Edit session',
                style: TextStyle(
                  color: Colors.blue, // Blue text
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Safe area bottom padding
          SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // --- VIEW 2: SUCCESS UI ---
  Widget _buildSuccessView(BuildContext context) {
    return Padding(
      key: const ValueKey('success_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          // Wavy Icon design layered perfectly
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.verified,
                color: const Color.fromARGB(255, 78, 255, 131),
                size: 85,
              ),
              const Icon(
                Icons.check,
                color: Colors.black,
                size: 40,
                weight: 800,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Main Title
          const Text(
            'Successful',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle
          Text(
            'Your session is successfully booked.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          // Done Button (Red Background)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to Home screen smoothly when Done is clicked
                Navigator.pushAndRemoveUntil(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const HomeDashboardScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _redButtonColor, // Changed to #BB0013
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
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
          // Safe area bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String monthYear = DateFormat('MMMM yyyy').format(_selectedDate!);

    List<Map<String, dynamic>> displayedSessions = _showAllSessions
        ? _trainerSessions
        : _trainerSessions.take(3).toList();

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
                  // --- TOP APP BAR & TITLE WITH NOTIFICATION ICON ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
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
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Booking',
                              style: TextStyle(
                                color: _textMain,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        // Transparent Circular Notification Icon
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
                  ),

                  // --- SCHEDULE & DATE HEADER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Schedule',
                          style: TextStyle(
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

                  // --- PILL SHAPED DATE SELECTOR ---
                  SizedBox(
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

                          String dayName = DateFormat('EEE').format(date);
                          String dayNumber = DateFormat('dd').format(date);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDate = date;
                                _availabilityStatus = 'none';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.only(right: 12),
                              width: 58,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? _activeBlue : Colors.white,
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

                  const SizedBox(height: 44),

                  // --- AVAILABLE SESSIONS ---
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Available Sessions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Optimized Horizontal List for Sessions (Pill Style)
                  SizedBox(
                    height: 52,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: displayedSessions.map((session) {
                          bool isSelected = _selectedSession == session['name'];

                          return GestureDetector(
                            onTap: () => setState(
                              () => _selectedSession = session['name'],
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.fromLTRB(6, 6, 20, 6),
                              decoration: BoxDecoration(
                                color: isSelected ? _limeGreen : Colors.white,
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

                  const SizedBox(height: 32),

                  // --- SELECT TIME SECTION (In a Container Box) ---
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
                        const Text(
                          'Select Time',
                          style: TextStyle(
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
                                            ? 'Choose'
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
                                  backgroundColor: _redButtonColor, // #BB0013
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
                                    : const Text(
                                        'Check',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),

                        // --- STATUS & PROCEED TO BOOK (Inside the time box) ---
                        if (_availabilityStatus == 'available') ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Time is available!',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _showConfirmationBottomSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _redButtonColor, // #BB0013
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Proceed to Book',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Custom Bottom Navigation Bar
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
                      _NavItem(
                        index: 0,
                        icon: Icons.home_filled,
                        label: 'Home',
                        selectedIndex: selectedIndex,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      _NavItem(
                        index: 1,
                        icon: Icons.calendar_today_rounded,
                        label: 'Booking',
                        selectedIndex: selectedIndex,
                        onTap: () {},
                      ),
                      _NavItem(
                        index: 2,
                        icon: Icons.bar_chart_rounded,
                        label: 'Stats',
                        selectedIndex: selectedIndex,
                        onTap: () {
                          _selectedIndexNotifier.value = 2;
                          Navigator.pop(context);
                        },
                      ),
                      _NavItem(
                        index: 3,
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chats',
                        selectedIndex: selectedIndex,
                        onTap: () {
                          _selectedIndexNotifier.value = 3;
                          Navigator.pop(context);
                        },
                      ),
                      _NavItem(
                        index: 4,
                        icon: Icons.person_outline_rounded,
                        label: 'Profile',
                        selectedIndex: selectedIndex,
                        onTap: () {
                          _selectedIndexNotifier.value = 4;
                          Navigator.pop(context);
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
