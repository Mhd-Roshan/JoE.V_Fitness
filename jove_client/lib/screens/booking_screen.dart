import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trainer_selection_screen.dart'; // Ensure this points to where your Trainer class is
import 'home_dashboard_screen.dart';

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
  bool _isLoading = false;
  bool _showAllSessions = false;

  // 6-Day Weekly Routine (Rotates for the month)
  final List<Map<String, dynamic>> _weeklySessions = [
    {
      'name': 'Strength & Conditioning',
      'sub': 'Focused on power and form',
      'icon': Icons.fitness_center,
      'color': const Color(0xFF01BCE3),
    },
    {
      'name': 'HIIT Intensity',
      'sub': 'Maximum calorie burn',
      'icon': Icons.local_fire_department_outlined,
      'color': const Color(0xFFFF7A00),
    },
    {
      'name': 'Mobility & Flow',
      'sub': 'Recovery and flexibility',
      'icon': Icons.accessibility_new,
      'color': const Color(0xFF00225D),
    },
    {
      'name': 'Upper Body Power',
      'sub': 'Chest, back and arms',
      'icon': Icons.fitness_center,
      'color': const Color(0xFFBA0C19),
    },
    {
      'name': 'Lower Body Agility',
      'sub': 'Speed and explosiveness',
      'icon': Icons.directions_run,
      'color': const Color(0xFF01BCE3),
    },
    {
      'name': 'Core & Endurance',
      'sub': 'Stamina and stability',
      'icon': Icons.directions_walk,
      'color': const Color(0xFFFF7A00),
    },
  ];

  @override
  void initState() {
    super.initState();
    _generateNext6Days();
    // Default to the first session in the 6-day split
    _selectedSession = _weeklySessions.first['name'];
  }

  void _generateNext6Days() {
    _next6Days = [];
    DateTime today = DateTime.now();
    int added = 0;
    while (added < 6) {
      if (today.weekday != DateTime.sunday) {
        _next6Days.add(today);
        added++;
      }
      today = today.add(const Duration(days: 1));
    }
    _selectedDate = _next6Days.first;
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _showConfirmModal() {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time first.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildConfirmBottomSheet(),
    );
  }

  Future<void> _confirmAndBook() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        String formattedTime = _selectedTime!.format(context);

        // Save to Firebase Bookings Collection
        await FirebaseFirestore.instance.collection('bookings').add({
          'userId': user.uid,
          'trainerId': widget.trainer.id,
          'trainerName': widget.trainer.name,
          'date': formattedDate,
          'time': formattedTime,
          'sessionType': _selectedSession,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context); // Close Modal

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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String monthYear = DateFormat('MMM yyyy').format(_selectedDate!);

    // Decide how many sessions to show based on "See All" button
    List<Map<String, dynamic>> displayedSessions = _showAllSessions
        ? _weeklySessions
        : _weeklySessions.take(3).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. Custom Curved App Bar
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF00225D),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Booking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
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
                  // 2. Schedule Date Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Schedule Date',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00225D),
                        ),
                      ),
                      Text(
                        monthYear,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00225D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 6 Days Horizontal List
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _next6Days.length,
                      itemBuilder: (context, index) {
                        DateTime date = _next6Days[index];
                        bool isSelected = _selectedDate == date;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDate = date),
                          child: Container(
                            width: 65,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00225D)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.grey.shade300,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF01BCE3,
                                        ).withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE').format(date).toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF01BCE3)
                                        : Colors.grey,
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
                                        : const Color(0xFF00225D),
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
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

                  // 3. All Sessions
                  const Text(
                    'All Sessions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00225D),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00225D)
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
                                border: Border.all(color: session['color']),
                              ),
                              child: Icon(
                                session['icon'],
                                color: session['color'],
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
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00225D),
                                    ),
                                  ),
                                  Text(
                                    session['sub'],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              color: isSelected
                                  ? const Color(0xFFFF7A00)
                                  : Colors.grey.shade300,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // See All Button
                  if (!_showAllSessions)
                    GestureDetector(
                      onTap: () => setState(() => _showAllSessions = true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBA0C19)),
                        ),
                        child: const Center(
                          child: Text(
                            'See all',
                            style: TextStyle(
                              color: Color(0xFFBA0C19),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 4. Select Time
                  const Text(
                    'Select Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00225D),
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
                            fontWeight: FontWeight.bold,
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
                                            : _selectedTime!.format(context),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.access_time,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _showConfirmModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBA0C19),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Check',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                color: Color(0xFF00225D),
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Note : Type your preferred time or use the picker. Availability will be confirmed by trainer shortly.',
                                  style: TextStyle(
                                    color: Color(0xFF00225D),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 5. Sessions Location
                  const Text(
                    'Sessions Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00225D),
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.home_outlined,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Home Gym',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00225D),
                                ),
                              ),
                              Text(
                                '742 block house, Vytilla',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Change',
                          style: TextStyle(
                            color: Color(0xFF00225D),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      // Mock Bottom Nav for Booking Screen
      bottomNavigationBar: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF00225D),
          borderRadius: BorderRadius.circular(35),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Icon(Icons.home_outlined, color: Colors.grey),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF01BCE3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month, color: Colors.white),
            ),
            const Icon(Icons.insert_chart_outlined, color: Colors.grey),
            const Icon(Icons.restaurant_menu, color: Colors.grey),
            const Icon(Icons.person_outline, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // BOTTOM SHEET DIALOG
  Widget _buildConfirmBottomSheet() {
    String formattedDate = DateFormat('EEEE, MMM d').format(_selectedDate!);
    String formattedTime = _selectedTime!.format(context);

    // Find the currently selected session object to get its icon and color
    var sessionObj = _weeklySessions.firstWhere(
      (s) => s['name'] == _selectedSession,
    );

    return Container(
      height: 450,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=2070',
          ), // Mock trainer image
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.4),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6B8EFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Selected session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Confirm Session',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0044FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    sessionObj['icon'],
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedSession!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        sessionObj['sub'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🗓 Date',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🕒 Time',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        '$formattedTime (60M)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmAndBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA0C19),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirm session ->',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0044FF), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Edit session',
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
  }
}
