import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../schedules/trainer_schedules_screen.dart';
import '../users/trainer_users_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../profile/trainer_profile_screen.dart';
import '../notifications/trainer_notifications_screen.dart';
import '../profile/trainer_client_reviews_screen.dart';

// IMPORT LANGUAGE SERVICE
import '../../services/language_service.dart';

class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerSession {
  final String id;
  final String clientName;
  final String serviceType;
  final String time;
  final String amPm;
  final String area;
  String status;

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
  List<_TrainerSession> _sessions = [];

  // Keep brand red static
  static const Color primaryRed = Color(0xFFBB0013);

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
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final sessionsSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('trainerId', isEqualTo: uid)
          .where('scheduledDate', isEqualTo: _todayDateStr())
          .get();

      final sessions = sessionsSnap.docs.map((d) {
        final data = d.data();
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

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Trainer home load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSessionStatus(_TrainerSession session) async {
    final oldStatus = session.status;
    final newStatus = oldStatus == 'completed' ? 'future' : 'completed';

    setState(() {
      session.status = newStatus;
    });

    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(session.id)
          .update({'status': newStatus});
    } catch (e) {
      setState(() {
        session.status = oldStatus;
      });
      debugPrint('Failed to update session status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS <---
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;
    final primaryBlue = Theme.of(context).primaryColor;

    final heroSession = _sessions.cast<_TrainerSession?>().firstWhere(
      (s) => s?.status != 'completed',
      orElse: () => _sessions.isNotEmpty ? _sessions.first : null,
    );

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: _BottomNav(currentIndex: 0, strings: strings),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
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
                        const SizedBox(height: 32),

                        // Hero Card
                        if (heroSession != null)
                          _HeroSessionCard(
                            session: heroSession,
                            onComplete: () => _toggleSessionStatus(heroSession),
                            strings: strings,
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: dividerColor,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              strings['noSessionsScheduled'] ??
                                  'No sessions scheduled for today yet.',
                              style: GoogleFonts.workSans(
                                color: subTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),

                        Text(
                          strings['quickAction'] ?? 'Quick Action',
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Quick Actions Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const TrainerNotesScreen(),
                                ),
                              );
                            },
                            child: _QuickActionCard(
                              label: strings['addNotes'] ?? 'Add Notes',
                              icon: Icons.chat_outlined,
                              isRed: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TrainerClientReviewsScreen(),
                                ),
                              );
                            },
                            child: _QuickActionCard(
                              label:
                                  strings['reviewFeedback'] ??
                                  'Review Feedback',
                              icon: Icons.star_outline_rounded,
                              isRed: false,
                            ),
                          ),
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
                              strings['todaysSessions'] ?? "Today's Sessions",
                              style: GoogleFonts.workSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TrainerSchedulesScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  strings['viewAll'] ?? 'View All',
                                  style: GoogleFonts.workSans(
                                    color: primaryRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_sessions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              strings['noSessionsToday'] ??
                                  'No sessions today.',
                              style: GoogleFonts.workSans(color: subTextColor),
                            ),
                          )
                        else
                          ..._sessions.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SessionRow(
                                session: s,
                                onToggle: () => _toggleSessionStatus(s),
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
// WIDGETS
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
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Dynamic Brand Blue
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/landing_photo.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
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
                      color:
                          Colors.white, // Popped to white for better contrast
                      size: 20,
                    ),
                    if (uid != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .where('trainerId', isEqualTo: uid)
                            .where('isRead', isEqualTo: false)
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
                                  color: Color(0xFFC7001A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
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
  const _HeroSessionCard({
    required this.session,
    required this.onComplete,
    required this.strings,
  });

  final _TrainerSession session;
  final VoidCallback onComplete;
  final Map<String, String> strings;

  @override
  Widget build(BuildContext context) {
    final isCompleted = session.status == 'completed';

    // We keep the static gradient here since it is the "Hero" element and looks beautiful in both modes
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00225D), Color(0xFF001233)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.clientName,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 24,
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
                    const SizedBox(height: 12),
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
              ),
              const SizedBox(width: 12),
              Container(
                width: 90,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      color: Color(0xFF01BCE3),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.time,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      session.amPm,
                      style: GoogleFonts.workSans(
                        color: Color(0xFF01BCE3),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
                child: OutlinedButton.icon(
                  onPressed: onComplete,
                  icon: Icon(
                    isCompleted
                        ? Icons.undo_rounded
                        : Icons.check_circle_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    isCompleted
                        ? (strings['markUndone'] ?? 'Mark Undone')
                        : (strings['markDone'] ?? 'Mark Done'),
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
                    strings['addVisitNotes'] ?? 'Add visit notes',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBB0013),
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
    // Red stays Red. Dark Blue adapts to Primary Theme Color.
    final boxColor = isRed
        ? const Color(0xFFBB0013)
        : Theme.of(context).primaryColor;

    return Container(
      height: 95,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: boxColor,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.workSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onToggle});

  final _TrainerSession session;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isCompleted = session.status == 'completed';

    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final primaryColor = Theme.of(context).primaryColor;

    // Dynamic Row Styling
    Color rowBgColor = isCompleted
        ? Theme.of(context).scaffoldBackgroundColor
        : cardColor;
    Color borderColor = isCompleted
        ? dividerColor
        : dividerColor.withValues(alpha: 0.5);
    Color timeBoxColor = isCompleted ? dividerColor : primaryColor;
    Color timeTextColor = isCompleted ? textColor : Colors.white;
    Color titleColor = isCompleted ? subTextColor : textColor;
    Color subtitleColor = isCompleted
        ? subTextColor.withValues(alpha: 0.6)
        : subTextColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rowBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 2),
                Text(
                  session.serviceType,
                  style: GoogleFonts.workSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isCompleted ? Colors.green : subTextColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.strings});

  final int currentIndex;
  final Map<String, String> strings;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, Icons.home, strings['home'] ?? 'Home'),
      (
        Icons.calendar_today_outlined,
        Icons.calendar_today,
        strings['schedules'] ?? 'Schedules',
      ),
      (Icons.group_outlined, Icons.group, strings['users'] ?? 'Users'),
      (
        Icons.description_outlined,
        Icons.description,
        strings['notes'] ?? 'Notes',
      ),
      (Icons.person_outline, Icons.person, strings['profile'] ?? 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Dynamic Brand Blue
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Theme.of(
          context,
        ).colorScheme.secondary, // Cyan accent
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
