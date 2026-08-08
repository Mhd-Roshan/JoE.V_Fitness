import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../schedules/trainer_schedules_screen.dart';
import '../users/trainer_users_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../profile/trainer_profile_screen.dart';
import '../notifications/trainer_notifications_screen.dart';

class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerSession {
  final String id;
  final String clientName;
  final String serviceType;
  final String time; // e.g., "07:00"
  final String amPm; // e.g., "AM"
  final String area;
  final String status; // 'completed', 'live', 'future'

  _TrainerSession({
    required this.id,
    required this.clientName,
    required this.serviceType,
    required this.time,
    required this.amPm,
    required this.area,
    required this.status,
  });
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  bool _loading = true;
  String _trainerName = '—';
  String _designation = '—';
  int _yearsExperience = 0;
  List<_TrainerSession> _sessions = [];

  // Colors based on the design
  static const Color darkBlue = Color(0xFF00225D);
  static const Color primaryRed = Color(0xFFBB0013);
  static const Color cyanAccent = Color(0xFF01BCE3);
  static const Color headerBlue = Color(0xFF003AA3);
  static const Color navBlue = Color(0xFF003AA3);
  static const Color bgGrey = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _todayDateStr() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      // 1. Fetch User Data
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      // 2. Fetch Trainer Data
      final trainerSnap = await FirebaseFirestore.instance
          .collection('trainers')
          .where('trainerId', isEqualTo: uid)
          .limit(1)
          .get();

      // 3. Fetch Today's Sessions
      final sessionsSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('trainerId', isEqualTo: uid)
          .where('scheduledDate', isEqualTo: _todayDateStr())
          .get();

      final sessions = sessionsSnap.docs.map((d) {
        final data = d.data();

        // Parse time to split "07:00 AM" into "07:00" and "AM"
        String rawTime = data['scheduledTime']?.toString().trim() ?? '00:00 AM';
        List<String> timeParts = rawTime.split(' ');
        String parsedTime = timeParts.isNotEmpty ? timeParts[0] : '00:00';
        String parsedAmPm = timeParts.length > 1
            ? timeParts[1].toUpperCase()
            : 'AM';

        return _TrainerSession(
          id: d.id,
          clientName: data['clientName']?.toString().toUpperCase() ?? 'UNKNOWN',
          serviceType:
              data['serviceType']?.toString().toUpperCase() ?? 'SESSION',
          time: parsedTime,
          amPm: parsedAmPm,
          area: data['area'] ?? '—',
          status: data['status']?.toString().toLowerCase() ?? 'future',
        );
      }).toList()..sort((a, b) => a.time.compareTo(b.time));

      if (!mounted) {
        return;
      }

      setState(() {
        _trainerName = userSnap.data()?['fullName'] ?? 'Trainer';
        if (trainerSnap.docs.isNotEmpty) {
          final tData = trainerSnap.docs.first.data();
          _designation = tData['designation'] ?? 'Trainer';
          _yearsExperience = tData['yearsExperience'] ?? 0;
        } else {
          _designation = 'Trainer';
          _yearsExperience = 0;
        }
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Trainer home load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Dynamically generate initials from the trainer's name
  String get _initials {
    final parts = _trainerName.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) {
      return '—';
    }
    final first = parts.first[0];
    final second = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last[0]
        : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Find the live session for the Hero card
    final heroSession = _sessions.cast<_TrainerSession?>().firstWhere(
      (s) => s?.status == 'live',
      orElse: () => _sessions.isNotEmpty ? _sessions.first : null,
    );

    return Scaffold(
      backgroundColor: bgGrey,
      bottomNavigationBar: const _BottomNav(currentIndex: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: darkBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TopHeaderBand(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        // Trainer Profile Row
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: darkBlue,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _initials,
                                style: GoogleFonts.workSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _trainerName,
                                  style: GoogleFonts.workSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: darkBlue,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  '$_designation · $_yearsExperience yrs exp',
                                  style: GoogleFonts.workSans(
                                    fontSize: 12,
                                    color: const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Hero Card (Live Session)
                        if (heroSession != null)
                          _HeroSessionCard(session: heroSession)
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'No sessions scheduled for today yet.',
                              style: GoogleFonts.workSans(
                                color: const Color(0xFF6B7280),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),

                        // Quick Actions Title
                        Text(
                          'Quick Action',
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Quick Actions List (Horizontal Scroll)
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      clipBehavior: Clip.none,
                      children: [
                        const _QuickActionCard(
                          label: 'Record Session',
                          icon: Icons.mic_none_outlined,
                          isRed: true,
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const TrainerNotesScreen(),
                              ),
                            );
                          },
                          child: const _QuickActionCard(
                            label: 'Add Notes',
                            icon: Icons.chat_outlined,
                            isRed: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const _QuickActionCard(
                          label: 'Health Info',
                          icon: Icons.favorite_border_rounded,
                          isRed: false,
                        ),
                      ],
                    ),
                  ),

                  // Today's Sessions Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's Sessions",
                              style: GoogleFonts.workSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: darkBlue,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFDE8E9,
                                ), // Very light red
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'View All',
                                style: GoogleFonts.workSans(
                                  color: primaryRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // List of sessions
                        if (_sessions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No sessions today.',
                              style: GoogleFonts.workSans(
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          )
                        else
                          ..._sessions.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SessionRow(session: s),
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
// WIDGETS
// ---------------------------------------------------------

class _TopHeaderBand extends StatelessWidget {
  const _TopHeaderBand();

  @override
  Widget build(BuildContext context) {
    // Drop shadow matching the image perfectly
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
      color: const Color(0xFFC7001A), // Matches the bright red in the header
      fontSize: 24,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      shadows: [textShadow],
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      width: double.infinity,
      // Reduced top and bottom padding to make the header smaller
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 15),
      decoration: const BoxDecoration(
        color: _TrainerHomeScreenState.headerBlue, // 0xFF003AA3
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Logo on the far left
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/landing_photo.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),

          // Centered Text: JoE[kettlebell]V FITNESS
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

          // Right-aligned Notification Icon (with unread badge logic)
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
                      color: Color(0xFF00225D), // Dark blue icon as requested
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

class _HeroSessionCard extends StatelessWidget {
  const _HeroSessionCard({required this.session});
  final _TrainerSession session;

  @override
  Widget build(BuildContext context) {
    final isLive = session.status == 'live';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_TrainerHomeScreenState.darkBlue, Color(0xFF001233)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: isLive
            ? Border.all(color: _TrainerHomeScreenState.cyanAccent, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Content Column (Text & Badges)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Badge
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _TrainerHomeScreenState.primaryRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Live now',
                              style: GoogleFonts.workSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(
                        height: 24,
                      ), // Keeps layout consistent if no badge

                    const SizedBox(height: 16),

                    Text(
                      session.clientName,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 24, // Slightly scaled down to fit the map
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.serviceType,
                      style: GoogleFonts.workSans(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Time and Location row
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: _TrainerHomeScreenState.cyanAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${session.time} ${session.amPm}',
                              style: GoogleFonts.workSans(
                                color: _TrainerHomeScreenState.cyanAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                session.area,
                                style: GoogleFonts.workSans(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right Side: Map Thumbnail
              GestureDetector(
                onTap: () {
                  // In the future: Add logic to open Google Maps
                },
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey[200], // Fallback color
                    borderRadius: BorderRadius.circular(4),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://tile.openstreetmap.org/13/1310/3165.png',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'View Profile',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to notes from the live session button too!
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const TrainerNotesScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Add visit notes',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _TrainerHomeScreenState.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.isRed,
  });

  final String label;
  final IconData icon;
  final bool isRed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRed
            ? _TrainerHomeScreenState.primaryRed
            : _TrainerHomeScreenState.darkBlue,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          Text(
            label,
            style: GoogleFonts.workSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final _TrainerSession session;

  @override
  Widget build(BuildContext context) {
    final isLive = session.status == 'live';
    final isCompleted = session.status == 'completed';
    final isFuture = session.status == 'future' || (!isLive && !isCompleted);

    // Dynamic styling based on exact design image
    Color bgColor = isFuture ? const Color(0xFFF3F4F6) : Colors.white;
    Color borderColor = isLive
        ? _TrainerHomeScreenState.primaryRed
        : (isCompleted ? const Color(0xFFE5E7EB) : Colors.transparent);
    Color timeBoxColor = isLive
        ? _TrainerHomeScreenState.primaryRed
        : (isCompleted
              ? _TrainerHomeScreenState.darkBlue
              : const Color(0xFFD1D5DB));
    Color timeTextColor = isFuture ? const Color(0xFF4B5563) : Colors.white;
    Color titleColor = isFuture
        ? const Color(0xFF6B7280)
        : _TrainerHomeScreenState.darkBlue;
    Color subtitleColor = isFuture
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        // The live card has a thick red line on the right, achieved via box shadow here
        boxShadow: isLive
            ? [
                const BoxShadow(
                  color: _TrainerHomeScreenState.primaryRed,
                  offset: Offset(6, 0),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Time Block
          Container(
            width: 55,
            height: 60,
            decoration: BoxDecoration(
              color: timeBoxColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  session.time,
                  style: GoogleFonts.workSans(
                    color: timeTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  session.amPm,
                  style: GoogleFonts.workSans(
                    color: timeTextColor.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      session.clientName,
                      style: GoogleFonts.workSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: _TrainerHomeScreenState.primaryRed,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.workSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                      letterSpacing: 0.5,
                    ),
                    children: [
                      TextSpan(text: session.serviceType),
                      if (isLive)
                        const TextSpan(
                          text: ' • LIVE',
                          style: TextStyle(
                            color: _TrainerHomeScreenState.primaryRed,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Trailing Icon
          Icon(
            isLive
                ? Icons.keyboard_double_arrow_right_rounded
                : Icons.chevron_right_rounded,
            color: isLive
                ? _TrainerHomeScreenState.primaryRed
                : const Color(0xFFD1D5DB),
            size: 24,
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
        color: _TrainerHomeScreenState.navBlue,
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
        selectedItemColor: _TrainerHomeScreenState.cyanAccent,
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
          if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerSchedulesScreen()),
            );
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

// ---------------------------------------------------------
// CUSTOM KETTLEBELL ICON W/ SHADOW
// ---------------------------------------------------------

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

    // Drop shadow matching the text shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final double w = size.width;
    final double h = size.height;

    // 1. The main handle shape - slightly thicker for visual clarity
    final Path handle = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.25, h * 0.05, w * 0.75, h * 0.5),
          Radius.circular(w * 0.2),
        ),
      );

    // 2. The round body shape - clearly circular
    final Path body = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.5, h * 0.65), radius: w * 0.35),
      );

    // Combine handle and body
    Path kettlebell = Path.combine(PathOperation.union, handle, body);

    // 3. Cut off the bottom to make it flat.
    // Cut exactly at h * 0.94 so the bottom rests exactly on the baseline.
    final Path bottomCut = Path()..addRect(Rect.fromLTRB(0, h * 0.94, w, h));
    kettlebell = Path.combine(PathOperation.difference, kettlebell, bottomCut);

    // 4. Cut out the middle D-hole for the handle.
    final Path hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.40, h * 0.20, w * 0.60, h * 0.45),
          Radius.circular(w * 0.1),
        ),
      );
    kettlebell = Path.combine(PathOperation.difference, kettlebell, hole);

    // Draw the drop shadow first
    canvas.drawPath(kettlebell.shift(const Offset(1.5, 1.5)), shadowPaint);

    // Draw the white kettlebell on top
    canvas.drawPath(kettlebell, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
