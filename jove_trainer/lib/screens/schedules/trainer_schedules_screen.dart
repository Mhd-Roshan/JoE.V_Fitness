import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/trainer_home_screen.dart';
import '../users/trainer_users_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../profile/trainer_profile_screen.dart';
import '../notifications/trainer_notifications_screen.dart';

class TrainerSchedulesScreen extends StatefulWidget {
  const TrainerSchedulesScreen({super.key});

  @override
  State<TrainerSchedulesScreen> createState() => _TrainerSchedulesScreenState();
}

class _ScheduleSession {
  final String id;
  final String clientName;
  final String serviceType;
  final String time;
  final String amPm;
  final String area;
  final String status;
  final String? notes;

  _ScheduleSession({
    required this.id,
    required this.clientName,
    required this.serviceType,
    required this.time,
    required this.amPm,
    required this.area,
    required this.status,
    this.notes,
  });
}

class _TrainerSchedulesScreenState extends State<TrainerSchedulesScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _scrollableDates;
  late ScrollController _scrollController;

  bool _loading = true;
  List<_ScheduleSession> _sessions = [];

  // Define how many days back and forward you want in the scrollable list
  final int _pastDays = 90;
  final int _futureDays = 90;

  // Colors based on the design
  static const Color darkBlue = Color(0xFF00225D);
  static const Color primaryRed = Color(0xFFBB0013);
  static const Color cyanAccent = Color(0xFF01BCE3);
  static const Color headerBlue = Color(0xFF003AA3);
  static const Color bgGrey = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _scrollableDates = _buildDateRange(_selectedDate);
    _scrollController = ScrollController();
    _loadSessions();

    // Auto-scroll to center "Today" when the screen first builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDateCenter(_selectedDate, animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Generates a list of dates (e.g. 90 days before today to 90 days after)
  List<DateTime> _buildDateRange(DateTime baseDate) {
    return List.generate(_pastDays + _futureDays + 1, (index) {
      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day + (index - _pastDays),
      );
    });
  }

  // Smoothly scrolls the tapped/initial date to the center of the screen
  void _scrollToDateCenter(DateTime date, {bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final index = _scrollableDates.indexWhere((d) => _isSameDay(d, date));
    if (index == -1) return;

    final screenWidth = MediaQuery.of(context).size.width;
    const itemWidth = 65.0; // matches container width
    const spacing = 12.0; // matches separator width
    const leftPadding = 24.0; // matches listview padding

    // Calculate exact pixel offset to center the selected item
    final offset =
        leftPadding +
        (index * (itemWidth + spacing)) -
        (screenWidth / 2) +
        (itemWidth / 2);
    final clampedOffset = offset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(clampedOffset);
    }
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _scrollToDateCenter(date, animate: true);
    _loadSessions();
  }

  // Helper to dynamically get the right day string
  String _getWeekdayLabel(int weekday) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return labels[weekday - 1]; // DateTime.weekday is 1-7
  }

  String _dateStr(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatFullDate(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _sessions = [];
        _loading = false;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('trainerId', isEqualTo: uid)
          .where('scheduledDate', isEqualTo: _dateStr(_selectedDate))
          .get();

      final sessions = snap.docs.map((d) {
        final data = d.data();

        // Parse time
        String rawTime = data['scheduledTime']?.toString().trim() ?? '00:00 AM';
        List<String> timeParts = rawTime.split(' ');
        String parsedTime = timeParts.isNotEmpty ? timeParts[0] : '00:00';
        String parsedAmPm = timeParts.length > 1
            ? timeParts[1].toUpperCase()
            : 'AM';

        // Map Firestore status to UI status
        String rawStatus =
            data['status']?.toString().toLowerCase() ?? 'scheduled';

        if (rawStatus == 'completed') {
          rawStatus = 'done';
        }

        if (rawStatus == 'future' || rawStatus == 'scheduled') {
          rawStatus = 'upcoming';
        }

        return _ScheduleSession(
          id: d.id,
          clientName: data['clientName'] ?? 'Unknown',
          serviceType: data['serviceType'] ?? 'Strength',
          time: parsedTime,
          amPm: parsedAmPm,
          area: data['area'] ?? 'Location',
          status: rawStatus,
          notes: data['notes'], // Fetch notes if they exist
        );
      }).toList()..sort((a, b) => a.time.compareTo(b.time));

      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Schedules load error: $e');
      if (mounted) {
        setState(() {
          _sessions = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int completedCount = _sessions.where((s) => s.status == 'done').length;
    int totalCount = _sessions.length;
    double progress = totalCount > 0 ? (completedCount / totalCount) : 0;

    return Scaffold(
      backgroundColor: bgGrey,
      bottomNavigationBar: const _BottomNav(
        currentIndex: 1,
      ), // Index 1 is Schedules
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TopHeaderBand(),

          const SizedBox(height: 24),

          // "Schedule date" Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Schedule date',
              style: GoogleFonts.workSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: darkBlue,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Scrollable Date Selector Strip
          SizedBox(
            height: 75,
            child: ListView.separated(
              controller: _scrollController, // Attach scroll controller here!
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _scrollableDates.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final date = _scrollableDates[i];
                final selected = _isSameDay(date, _selectedDate);

                return GestureDetector(
                  onTap: () => _selectDate(date),
                  child: Container(
                    width: 65,
                    decoration: BoxDecoration(
                      color: selected ? darkBlue : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? cyanAccent : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1, // Thicker cyan border
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getWeekdayLabel(date.weekday), // Dynamic Day Label
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? cyanAccent
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.workSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : darkBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // "Time - Date" and Progress bar row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time - ${_formatFullDate(_selectedDate)}',
                  style: GoogleFonts.workSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: darkBlue,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 6,
                      decoration: BoxDecoration(
                        color: totalCount > 0
                            ? primaryRed
                            : const Color(0xFFE5E7EB),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: primaryRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$completedCount/$totalCount',
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: darkBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List of Sessions
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: darkBlue),
                  )
                : _sessions.isEmpty
                ? Center(
                    child: Text(
                      'No sessions scheduled for this day.',
                      style: GoogleFonts.workSans(
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _sessions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _SessionCard(session: _sessions[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// SESSION CARD WIDGET
// ---------------------------------------------------------

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final _ScheduleSession session;

  @override
  Widget build(BuildContext context) {
    final bool isDone = session.status == 'done';
    final bool isLive = session.status == 'live';
    final bool isUpcoming = session.status == 'upcoming';

    // Dynamic Colors based on status
    Color cardBg = isLive ? const Color(0xFFFDE8E9) : Colors.white;
    Color cardBorder = isLive
        ? _TrainerSchedulesScreenState.primaryRed
        : const Color(0xFFE5E7EB);

    Color badgeBg = isDone
        ? const Color(0xFFC6F6D5)
        : (isLive ? const Color(0xFFFBCFE8) : const Color(0xFFE5E7EB));
    Color badgeText = isDone
        ? const Color(0xFF22543D)
        : (isLive
              ? _TrainerSchedulesScreenState.primaryRed
              : const Color(0xFF4B5563));
    String badgeLabel = isDone ? 'Done' : (isLive ? 'Live' : 'Upcoming');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Time
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.time} ${session.amPm}',
                  style: GoogleFonts.workSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _TrainerSchedulesScreenState.darkBlue,
                  ),
                ),
              ],
            ),
          ),

          // Right Side: Details & Actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Name & Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        session.clientName,
                        style: GoogleFonts.workSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _TrainerSchedulesScreenState.darkBlue,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeLabel,
                        style: GoogleFonts.workSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeText,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Location and Service Type
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.area,
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.fitness_center,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.serviceType,
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),

                // Optional Notes Preview (shown mostly for 'Done' state if they exist)
                if (isDone || session.notes != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(color: Color(0xFFD1D5DB), width: 3),
                        top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),
                    ),
                    child: Text(
                      session.notes ??
                          'Good form of squats', // Placeholder matching image if null
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action Buttons based on status
                if (isDone)
                  _OutlineBtn(
                    icon: Icons.edit_outlined,
                    label: 'Edit notes',
                    onTap: () {},
                  )
                else if (isLive)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _SolidBtn(
                          icon: Icons.check,
                          label: 'Complete',
                          color: _TrainerSchedulesScreenState.primaryRed,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _OutlineBtn(
                          icon: Icons.edit_outlined,
                          label: 'Add notes',
                          bgColor: Colors.white,
                          onTap: () {},
                        ),
                      ),
                    ],
                  )
                else if (isUpcoming)
                  Row(
                    children: [
                      _SolidBtn(
                        icon: Icons.check,
                        label: 'Mark done',
                        color: _TrainerSchedulesScreenState.darkBlue,
                        onTap: () {},
                      ),
                      const SizedBox(width: 12),
                      _OutlineBtn(
                        icon: Icons.edit_outlined,
                        label: 'Add notes',
                        onTap: () {},
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Buttons for the Cards
class _SolidBtn extends StatelessWidget {
  const _SolidBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.workSans(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.bgColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: bgColor ?? Colors.transparent,
        foregroundColor: _TrainerSchedulesScreenState.darkBlue,
        side: const BorderSide(color: Color(0xFF6B7280)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16, color: _TrainerSchedulesScreenState.darkBlue),
      label: Text(
        label,
        style: GoogleFonts.workSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _TrainerSchedulesScreenState.darkBlue,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// HEADER AND NAVIGATION WIDGETS
// ---------------------------------------------------------

class _TopHeaderBand extends StatelessWidget {
  const _TopHeaderBand();

  @override
  Widget build(BuildContext context) {
    final textShadow = Shadow(
      color: Colors.black.withValues(alpha: 0.4),
      offset: const Offset(1.5, 1.5),
      blurRadius: 3,
    );

    final whiteTitleStyle = GoogleFonts.workSans(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      shadows: [textShadow],
    );

    final redTitleStyle = GoogleFonts.workSans(
      color: const Color(0xFFC7001A),
      fontSize: 24,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      shadows: [textShadow],
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 15),
      decoration: const BoxDecoration(
        color: _TrainerSchedulesScreenState.headerBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: Tappable Logo to go back to Root
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Image.asset(
                'assets/images/landing_photo.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Center: JoE[kettlebell]V FITNESS
          Align(
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'JoE', style: whiteTitleStyle),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: _KettlebellIcon(size: 18),
                    ),
                  ),
                  TextSpan(text: 'V ', style: whiteTitleStyle),
                  TextSpan(text: 'FITNESS', style: redTitleStyle),
                ],
              ),
            ),
          ),

          // Right: Notification Icon (WIRED WITH RED DOT!)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainerNotificationsScreen(),
                  ),
                );
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF00225D),
                      size: 20,
                    ),
                    // Only fetch notifications if user is logged in
                    if (uid != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .where('trainerId', isEqualTo: uid)
                            .where(
                              'isRead',
                              isEqualTo: false,
                            ) // Check for unread
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData &&
                              snapshot.data!.docs.isNotEmpty) {
                            return Positioned(
                              top: 8,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFC7001A), // Primary Red
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink(); // No unread
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home, 'Home'),
      (Icons.calendar_today_outlined, Icons.calendar_today, 'Schedules'),
      (Icons.group_outlined, Icons.group, 'Users'),
      (Icons.description_outlined, Icons.description, 'Notes'),
      (Icons.person_outline, Icons.person, 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _TrainerSchedulesScreenState.headerBlue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: _TrainerSchedulesScreenState.cyanAccent,
        unselectedItemColor: Colors.white,
        selectedLabelStyle: GoogleFonts.workSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.workSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        items: [
          for (final item in items)
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(item.$1, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(item.$2, size: 24),
              ),
              label: item.$3,
            ),
        ],
        onTap: (index) {
          if (index == 0) {
            // FIX: Using pushAndRemoveUntil to clean stack to prevent freezing
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const TrainerHomeScreen()),
              (route) => false,
            );
          } else if (index == 1) {
            if (currentIndex != 1) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const TrainerSchedulesScreen(),
                ),
              );
            }
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerUsersScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerNotesScreen()),
            );
          } else if (index == 4) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerProfileScreen()),
            );
          }
        },
      ),
    );
  }
}

class _KettlebellIcon extends StatelessWidget {
  const _KettlebellIcon({this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KettlebellPainter()),
    );
  }
}

class _KettlebellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final double w = size.width;
    final double h = size.height;

    final Path handle = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.25, h * 0.05, w * 0.75, h * 0.5),
          Radius.circular(w * 0.2),
        ),
      );

    final Path body = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.5, h * 0.65), radius: w * 0.35),
      );

    Path kettlebell = Path.combine(PathOperation.union, handle, body);

    final Path bottomCut = Path()..addRect(Rect.fromLTRB(0, h * 0.94, w, h));
    kettlebell = Path.combine(PathOperation.difference, kettlebell, bottomCut);

    final Path hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.40, h * 0.20, w * 0.60, h * 0.45),
          Radius.circular(w * 0.1),
        ),
      );
    kettlebell = Path.combine(PathOperation.difference, kettlebell, hole);

    canvas.drawPath(kettlebell.shift(const Offset(1.5, 1.5)), shadowPaint);
    canvas.drawPath(kettlebell, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
