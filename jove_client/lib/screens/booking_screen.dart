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
  late List<DateTime> _next6Days;
  DateTime? _selectedDate;
  String? _selectedSession;
  TimeOfDay? _selectedTime;
  bool _showAllSessions = false;

  // Set default active tab to 'Booking' (Index 1)
  int _selectedIndex = 1;

  // Availability State variables
  bool _isChecking = false;
  bool _isBooking = false;
  String _availabilityStatus = 'none'; // 'none', 'available'

  // Colors based on the design
  static const Color _darkBlue = Color(0xFF00225D);
  static const Color _cyan = Color(0xFF00B4D8);
  static const Color _red = Color(0xFFBB0013);

  // Dynamic sessions
  List<Map<String, dynamic>> _trainerSessions = [];

  @override
  void initState() {
    super.initState();
    _generateNext6Days();
    _loadTrainerSpecializations();
    _selectedTime = const TimeOfDay(hour: 8, minute: 30); // Default UI time
  }

  // ==========================================
  // HELPER: STRICT TIME FORMATTING
  // ==========================================
  String _formatTimeStrict(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  // ==========================================
  // LOGIC: LOAD DYNAMIC SESSIONS
  // ==========================================
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
          'color': _cyan,
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
      return {
        'sub': 'Focused on power and form',
        'icon': Icons.fitness_center,
        'color': const Color(0xFF00B4D8),
      };
    } else if (lowerSpec.contains('hiit') || lowerSpec.contains('cardio')) {
      return {
        'sub': 'Maximum calorie burn',
        'icon': Icons.local_fire_department_outlined,
        'color': const Color(0xFFFF7A00),
      };
    }
    return {
      'sub': 'Personalized training',
      'icon': Icons.sports_gymnastics,
      'color': const Color(0xFF00225D),
    };
  }

  void _generateNext6Days() {
    _next6Days = [];
    DateTime today = DateTime.now();
    for (int i = 0; i < 6; i++) {
      _next6Days.add(today.add(Duration(days: i)));
    }
    _selectedDate = _next6Days.first;
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

  // ==========================================
  // LOGIC: CHECK AVAILABILITY (Bypassing Firebase for UI speed)
  // ==========================================
  void _checkAvailability() {
    if (_selectedTime == null || _selectedDate == null) return;
    setState(() {
      _isChecking = true;
    });

    // Simulate a quick UI check without needing real database dummy data
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _availabilityStatus = 'available';
      });
    });
  }

  // ==========================================
  // CONFIRM BOOKING MODAL (EXACTLY LIKE IMAGE)
  // ==========================================
  void _showConfirmationDialog() {
    String formattedDate = DateFormat('EEEE, MMM d').format(_selectedDate!);
    String formattedTime = _formatTimeStrict(_selectedTime!);
    Map<String, dynamic> activeSessionData = _trainerSessions.firstWhere(
      (s) => s['name'] == _selectedSession,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A), // Pure Dark Background
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Image Area with Gradient Overlay
                Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    // Background Image (Use trainer image if available, else placeholder)
                    Image.network(
                      widget.trainer.imageUrl.isNotEmpty
                          ? widget.trainer.imageUrl
                          : 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&q=80',
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    // Dark Gradient Fade
                    Container(
                      height: 260,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black54,
                            Color(0xFF0A0A0A),
                          ],
                        ),
                      ),
                    ),
                    // Text Overlay inside Image section
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7BA6F5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Selected session',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Confirm Session',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  activeSessionData['icon'],
                                  color: Colors.blueAccent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedSession ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      activeSessionData['sub'],
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13,
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
                  ],
                ),

                // Details Area (Date and Time)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Divider(color: Colors.grey.shade800, height: 1),
                      const SizedBox(height: 16),
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
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Date',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Time',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$formattedTime (60M)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Red Confirm Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isBooking
                              ? null
                              : _confirmBookingToFirebase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isBooking
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Confirm session',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Outline Edit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blueAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Edit session',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // LOGIC: WRITE TO FIREBASE (For Home Screen to Read)
  // ==========================================
  Future<void> _confirmBookingToFirebase() async {
    setState(() => _isBooking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String dbDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        String dbTime = _formatTimeStrict(_selectedTime!);

        await FirebaseFirestore.instance.collection('bookings').add({
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

      if (!mounted) return;
      // Close dialog and return Home smoothly
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to book session.')));
      setState(() => _isBooking = false);
    }
  }

  // ==========================================
  // CUSTOM STATIC NAV ITEM (NO OVERFLOW)
  // ==========================================
  Widget _buildStaticNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.pop(context);
          return;
        }
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 10.0 : 6.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF01BCE3) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 22,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String monthYear = DateFormat('MMM yyyy').format(_selectedDate!);
    List<Map<String, dynamic>> displayedSessions = _showAllSessions
        ? _trainerSessions
        : _trainerSessions.take(3).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ==========================================
          // 1. TOP APP BAR (EXACTLY MATCHING HOME DASHBOARD)
          // ==========================================
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top:
                  MediaQuery.of(context).padding.top +
                  8, // Responsive to notches
              left: 24,
              right: 24,
              bottom: 20, // Extra space at bottom to look identical
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF003297), // Exact Home Screen Dark Blue
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF01BCE3), // Exact Cyan thick border
                  width: 6,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Booking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900, // Matched font weight
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(6), // Exact matching padding
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.15,
                    ), // Matching overlay color
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none,
                    color: Color(0xFF01BCE3), // Exact Home Screen Cyan icon
                    size: 24, // Matched icon size
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==========================================
                  // 2. SCHEDULE DATE
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Schedule Date',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _darkBlue,
                        ),
                      ),
                      Text(
                        monthYear,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _darkBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 85,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _next6Days.length,
                      itemBuilder: (context, index) {
                        DateTime date = _next6Days[index];
                        bool isSelected = _selectedDate == date;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                              _availabilityStatus = 'none';
                            });
                          },
                          child: Container(
                            width: 65,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _darkBlue : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? _cyan
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE').format(date).toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? _cyan
                                        : Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d').format(date),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : _darkBlue,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ==========================================
                  // 3. ALL SESSIONS (No Checkmarks)
                  // ==========================================
                  const Text(
                    'All Sessions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  ...displayedSessions.map((session) {
                    bool isSelected = _selectedSession == session['name'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedSession = session['name']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.grey.shade50
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(
                                    0xFFFF7A00,
                                  ) // Orange Border highlight
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: session['color'],
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                session['icon'],
                                color: session['color'],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: _darkBlue,
                                    ),
                                  ),
                                  Text(
                                    session['sub'],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  if (!_showAllSessions && _trainerSessions.length > 3)
                    GestureDetector(
                      onTap: () => setState(() => _showAllSessions = true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'See all',
                            style: TextStyle(
                              color: _red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // ==========================================
                  // 4. SELECT TIME
                  // ==========================================
                  const Text(
                    'Select Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter the time',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedTime == null
                                            ? 'Select Time'
                                            : _formatTimeStrict(_selectedTime!),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.access_time,
                                        color: Colors.grey,
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
                                  backgroundColor: _red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (_availabilityStatus == 'none') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: _darkBlue,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Note : Type your preferred time or use the picker. Availability will be confirmed instantly.',
                                    style: TextStyle(
                                      color: _darkBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_availabilityStatus == 'available') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
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
                        ],
                      ],
                    ),
                  ),

                  // ==========================================
                  // 5. FIXED POSITION CONFIRM BUTTON (BOTTOM OF PAGE)
                  // ==========================================
                  if (_availabilityStatus == 'available') ...[
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _showConfirmationDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Proceed to Book',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ==========================================
      // NO-ANIMATION STATIC BOTTOM NAV BAR (Matches Home)
      // ==========================================
      bottomNavigationBar: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF001233),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStaticNavItem(0, Icons.home_filled, 'Home'),
            _buildStaticNavItem(1, Icons.calendar_month, 'Booking'), // Active
            _buildStaticNavItem(2, Icons.insert_chart_rounded, 'Stats'),
            _buildStaticNavItem(3, Icons.chat_bubble_rounded, 'Chats'),
            _buildStaticNavItem(4, Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }
}
