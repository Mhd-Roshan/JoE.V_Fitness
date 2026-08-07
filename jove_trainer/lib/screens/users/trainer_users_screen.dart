import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../schedules/trainer_schedules_screen.dart';

class TrainerUsersScreen extends StatefulWidget {
  const TrainerUsersScreen({super.key});

  @override
  State<TrainerUsersScreen> createState() => _TrainerUsersScreenState();
}

// Data Model to represent the UI in the image
class _ClientData {
  final String name;
  final String initials;
  final String details;
  final String? medicalWarning;
  final int progressPercent;
  final String status;

  _ClientData({
    required this.name,
    required this.initials,
    required this.details,
    required this.progressPercent,
    this.medicalWarning,
    this.status = 'Active',
  });
}

class _TrainerUsersScreenState extends State<TrainerUsersScreen> {
  bool _loading = true;
  List<_ClientData> _users = [];

  // Colors based on the design
  static const Color darkBlue = Color(0xFF00225D);
  static const Color primaryRed = Color(0xFFBB0013);
  static const Color cyanAccent = Color(0xFF01BCE3);
  static const Color headerBlue = Color(0xFF003AA3);
  static const Color bgGrey = Color(0xFFFAFAFA);
  static const Color borderGrey = Color(0xFFE5E7EB);

  static const Color activeBg = Color(0xFFC6F6D5);
  static const Color activeText = Color(0xFF22543D);
  static const Color warningText = Color(
    0xFFB48A28,
  ); // Brown/Yellow for medical

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Query users where this trainer is assigned.
      // NOTE: Adjust 'trainerId' if your database uses a different field name (e.g., 'assignedTrainerId')
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('trainerId', isEqualTo: uid)
          .get();

      final loadedUsers = snap.docs.map((doc) {
        final data = doc.data();

        // Safely extract name
        final name =
            data['fullName']?.toString() ??
            data['name']?.toString() ??
            'Unknown User';

        // Dynamically generate initials
        final parts = name.trim().split(' ');
        String initials = 'U';
        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          initials = parts.first[0];
          if (parts.length > 1 && parts.last.isNotEmpty) {
            initials += parts.last[0];
          }
        }

        // Build details string (e.g. "Package 1 · Weight loss · Vytilla")
        final package = data['package']?.toString() ?? 'Standard';
        final goal = data['goal']?.toString() ?? 'Fitness';
        final area = data['area']?.toString() ?? 'Location';
        final details = '$package · $goal · $area';

        // Calculate progress percentage safely
        final completed = data['completedSessions'] ?? 0;
        final total = data['totalSessions'] ?? 10;
        int progress = 0;
        if (total > 0 && completed is num && total is num) {
          progress = ((completed / total) * 100).round();
          if (progress > 100) progress = 100;
        }

        // Extract optional medical warning
        String? medical = data['medicalWarning']?.toString();
        if (medical != null && medical.trim().isEmpty) {
          medical = null; // Treat empty strings as no warning
        }

        return _ClientData(
          name: name,
          initials: initials.toUpperCase(),
          details: details,
          progressPercent: progress,
          medicalWarning: medical,
          status: data['status']?.toString() ?? 'Active',
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _users = loadedUsers;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      bottomNavigationBar: const _BottomNav(
        currentIndex: 2,
      ), // Index 2 is Users
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TopHeaderBand(),

          const SizedBox(height: 24),

          // "All Users" Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'All Users',
              style: GoogleFonts.workSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: darkBlue,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar & Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search  people....',
                        hintStyle: GoogleFonts.workSans(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                          size: 22,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: borderGrey,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: darkBlue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Filter Button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderGrey, width: 1.5),
                  ),
                  child: const Icon(Icons.tune, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Users List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: darkBlue),
                  )
                : _users.isEmpty
                ? Center(
                    child: Text(
                      'No users assigned yet.',
                      style: GoogleFonts.workSans(
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _users.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _UserCard(user: _users[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// USER CARD WIDGET
// ---------------------------------------------------------

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final _ClientData user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Row: Avatar, Name, Details, Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _TrainerUsersScreenState.darkBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: GoogleFonts.workSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.workSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _TrainerUsersScreenState.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.details,
                      style: GoogleFonts.workSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),

                    // Optional Medical Warning
                    if (user.medicalWarning != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: _TrainerUsersScreenState.warningText,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              user.medicalWarning!,
                              style: GoogleFonts.workSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _TrainerUsersScreenState.warningText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Active Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _TrainerUsersScreenState.activeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.status,
                  style: GoogleFonts.workSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _TrainerUsersScreenState.activeText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Progress Bar Section
          Text(
            'Sessions',
            style: GoogleFonts.workSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _TrainerUsersScreenState.darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: user.progressPercent / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _TrainerUsersScreenState.primaryRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${user.progressPercent}%',
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _TrainerUsersScreenState.darkBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_outline, size: 18),
              label: Text(
                'View Profile',
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _TrainerUsersScreenState.darkBlue,
                side: const BorderSide(
                  color: _TrainerUsersScreenState.darkBlue,
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// HEADER AND NAVIGATION WIDGETS (Reusable components)
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 15),
      decoration: const BoxDecoration(
        color: _TrainerUsersScreenState.headerBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: Tappable Logo to go back
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
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

          // Right: Notification Icon
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF00225D),
                size: 20,
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
        color: _TrainerUsersScreenState.headerBlue,
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
        selectedItemColor: _TrainerUsersScreenState.cyanAccent,
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
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerSchedulesScreen()),
            );
          }
          // Do nothing if index == 2 because we are already on Users
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
