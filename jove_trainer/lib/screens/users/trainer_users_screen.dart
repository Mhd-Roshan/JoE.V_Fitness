import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jove_trainer/screens/users/client_profile_screen.dart';

import '../home/trainer_home_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../schedules/trainer_schedules_screen.dart';
import '../profile/trainer_profile_screen.dart';
import '../notifications/trainer_notifications_screen.dart';

// ---> NEW: IMPORT USER PROFILE SCREEN & LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class TrainerUsersScreen extends StatefulWidget {
  const TrainerUsersScreen({super.key});

  @override
  State<TrainerUsersScreen> createState() => _TrainerUsersScreenState();
}

// Data Model to represent the UI in the image
class _ClientData {
  final String id;
  final String name;
  final String initials;
  final String details;
  final String? medicalWarning;
  final int progressPercent;
  final String status;

  _ClientData({
    required this.id,
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
  List<_ClientData> _filteredUsers = []; // <-- Added for Search functionality
  final TextEditingController _searchController = TextEditingController();

  // These colors stay the same in both themes (semantic colors)
  static const Color primaryRed = Color(0xFFBB0013);
  static const Color activeBg = Color(0xFFC6F6D5);
  static const Color activeText = Color(0xFF22543D);
  static const Color warningText = Color(0xFFB48A28);

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final strings = languageService.strings;

    try {
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
            (strings['unknownClient'] ?? 'Unknown User');

        // Dynamically generate initials
        final parts = name.trim().split(' ');
        String initials = 'U';
        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          initials = parts.first[0];
          if (parts.length > 1 && parts.last.isNotEmpty) {
            initials += parts.last[0];
          }
        }

        // Build details string
        final package = data['package']?.toString() ?? 'Standard';
        final goal = data['goal']?.toString() ?? 'Fitness';
        final area = data['area']?.toString() ?? 'Location';
        final details = '$package · $goal · $area';

        // Calculate progress percentage
        final completed = data['completedSessions'] ?? 0;
        final total = data['totalSessions'] ?? 10;
        int progress = 0;
        if (total > 0 && completed is num && total is num) {
          progress = ((completed / total) * 100).round();
          if (progress > 100) progress = 100;
        }

        // Extract medical warning
        String? medical = data['medicalWarning']?.toString();
        if (medical != null && medical.trim().isEmpty) {
          medical = null;
        }

        return _ClientData(
          id: doc.id,
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
        _filteredUsers = loadedUsers; // Initialize filtered list
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

  // --- Search Logic ---
  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _users;
      });
    } else {
      setState(() {
        _filteredUsers = _users
            .where(
              (user) => user.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      });
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
    final brandBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: _BottomNav(
        currentIndex: 2,
        strings: strings,
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
              strings['allUsers'] ?? 'All Users',
              style: GoogleFonts.workSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textColor, // Dynamic text color
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
                      controller: _searchController,
                      onChanged: _filterUsers,
                      style: TextStyle(color: textColor), // Dynamic input text
                      decoration: InputDecoration(
                        hintText:
                            strings['searchPeople'] ?? 'Search people....',
                        hintStyle: GoogleFonts.workSans(
                          color: subTextColor, // Dynamic hint color
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: subTextColor,
                          size: 22,
                        ),
                        filled: true,
                        fillColor: cardColor, // Dynamic search bar background
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: dividerColor, // Dynamic border
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: brandBlue, // Highlights brand color on tap
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Filter Button
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          strings['filterComingSoon'] ??
                              'Filter options coming soon!',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cardColor, // Dynamic button background
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: dividerColor, width: 1.5),
                    ),
                    child: Icon(Icons.tune, color: subTextColor),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Users List
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: brandBlue))
                : _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isNotEmpty
                          ? (strings['noUsersMatch'] ??
                                'No users match your search.')
                          : (strings['noUsers'] ?? 'No users assigned yet.'),
                      style: GoogleFonts.workSans(
                        color: subTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _filteredUsers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _UserCard(user: _filteredUsers[index]);
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
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS FOR CARD <---
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;
    final brandBlue = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor, width: 1.5),
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
                decoration: BoxDecoration(
                  color: brandBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: GoogleFonts.workSans(
                    color: Colors.white, // Initials stay white
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
                        color: textColor, // Dynamic Name
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.details,
                      style: GoogleFonts.workSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: subTextColor, // Dynamic Subtitle
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
            strings['sessions'] ?? 'Sessions',
            style: GoogleFonts.workSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: dividerColor, // Track background
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
                  color: textColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${strings['openingProfileFor'] ?? 'Opening profile for '}${user.name}...',
                    ),
                  ),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrainerUserProfileScreen(
                      clientId: user.id,
                    ), // Ensure this matches your screen name
                  ),
                );
              },
              icon: Icon(Icons.person_outline, size: 18, color: brandBlue),
              label: Text(
                strings['viewProfile'] ?? 'View Profile',
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: brandBlue, // Dynamic Button Text
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: brandBlue, // Dynamic Button Border
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
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Dynamic Header Background
        borderRadius: const BorderRadius.only(
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
                      color: Colors.white, // Fixed white on header
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
        color: Theme.of(context).primaryColor, // Dynamic Footer Background
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
        ).colorScheme.secondary, // Dynamic cyan highlight
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
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const TrainerHomeScreen()),
              (route) => false,
            );
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerSchedulesScreen()),
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
