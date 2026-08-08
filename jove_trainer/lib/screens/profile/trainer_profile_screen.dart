import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- ALL BOTTOM NAVIGATION IMPORTS ---
import '../home/trainer_home_screen.dart';
import '../schedules/trainer_schedules_screen.dart';
import '../users/trainer_users_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../notifications/trainer_notifications_screen.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  // Theme Colors
  static const Color darkBlue = Color(0xFF00225D);
  static const Color headerBlue = Color(0xFF003AA3);
  static const Color primaryRed = Color(0xFFC7001A);
  static const Color bgGrey = Color(0xFFFAFAFA);
  static const Color borderGrey = Color(0xFFE5E7EB);
  static const Color textGrey = Color(0xFF6B7280);

  bool _isLoading = true;

  // Data Variables (Populated purely from Firebase)
  String _fullName = '';
  String _designation = '';
  int _yearsExperience = 0;
  String _phone = '';
  String _email = '';
  String _area = '';
  String _profileImageUrl = '';

  int _clientCount = 0;
  int _totalSessions = 0;
  String _successRate = '';

  List<Map<String, dynamic>> _feedbacks = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch Trainer/User Data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? {};

      // Fallback check: Some apps store trainer data in a 'trainers' collection
      final trainerQuery = await FirebaseFirestore.instance
          .collection('trainers')
          .where('trainerId', isEqualTo: uid)
          .limit(1)
          .get();
      final trainerData = trainerQuery.docs.isNotEmpty
          ? trainerQuery.docs.first.data()
          : {};

      // 2. Dynamically Count Assigned Clients
      final clientsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('trainerId', isEqualTo: uid)
          .get();

      // 3. Dynamically Count Total Sessions (From your 'sessions' collection)
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('sessions')
          .where('trainerId', isEqualTo: uid)
          .get();

      // 4. Fetch Real Client Feedbacks
      final feedbackQuery = await FirebaseFirestore.instance
          .collection('feedbacks')
          .where('trainerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          // Merge User/Trainer document data
          _fullName =
              userData['fullName'] ??
              trainerData['fullName'] ??
              userData['name'] ??
              'Trainer';
          _phone = userData['phone'] ?? trainerData['phone'] ?? '—';
          _email =
              userData['email'] ??
              FirebaseAuth.instance.currentUser?.email ??
              '—';
          _area = trainerData['area'] ?? userData['area'] ?? '—';
          _profileImageUrl =
              trainerData['profileImageUrl'] ??
              userData['profileImageUrl'] ??
              '';

          _designation =
              (trainerData['designation'] ??
                      userData['designation'] ??
                      'FITNESS TRAINER')
                  .toString()
                  .toUpperCase();
          _yearsExperience =
              trainerData['yearsExperience'] ??
              userData['yearsExperience'] ??
              0;
          _successRate =
              trainerData['successRate'] ??
              userData['successRate'] ??
              '100%'; // Custom metric usually stored in DB

          // Dynamic Counts
          _clientCount = clientsQuery.docs.length;
          _totalSessions = sessionsQuery.docs.length;

          // Feedback list
          _feedbacks = feedbackQuery.docs.map((doc) => doc.data()).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignOut() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Sign Out',
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.workSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.workSans(color: textGrey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.workSans(
                color: primaryRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      bottomNavigationBar: const _BottomNav(currentIndex: 4), // Profile Tab
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: darkBlue))
          : Column(
              children: [
                const _TopHeaderBand(),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),

                        // 1. Profile Picture & Header
                        _buildProfileHeader(),

                        const SizedBox(height: 24),

                        // 2. Stats Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Clients',
                                  _clientCount.toString(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Sessions',
                                  _totalSessions.toString(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard('Rate', _successRate),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 3. Personal Information Box
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildPersonalInfoCard(),
                        ),

                        const SizedBox(height: 32),

                        // 4. Client Feedback Section
                        _buildFeedbackSection(),

                        const SizedBox(height: 32),

                        // 5. Menu Options
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              _buildMenuOption(
                                icon: Icons.group_outlined,
                                title: 'My Client',
                                subtitle: '$_clientCount users assigned',
                                onTap: () =>
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const TrainerUsersScreen(),
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _buildMenuOption(
                                icon: Icons.call_outlined,
                                title: 'Contact admin',
                                subtitle: 'Report issue or request leave',
                                onTap: () {
                                  // Action for contact admin
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildMenuOption(
                                icon: Icons.settings_outlined,
                                title: 'App setting',
                                subtitle: 'Language, notifications',
                                onTap: () {
                                  // Action for app settings
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 6. Sign Out Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _handleSignOut,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                'SIGN OUT',
                                style: GoogleFonts.workSans(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildProfileHeader() {
    // Safety check for initials
    String initials = '?';
    if (_fullName.isNotEmpty) {
      final parts = _fullName.trim().split(' ');
      initials = parts.first[0].toUpperCase();
      if (parts.length > 1) initials += parts.last[0].toUpperCase();
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2563EB), width: 3),
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: borderGrey,
                backgroundImage: _profileImageUrl.isNotEmpty
                    ? NetworkImage(_profileImageUrl)
                    : null,
                child: _profileImageUrl.isEmpty
                    ? Text(
                        initials,
                        style: GoogleFonts.workSans(
                          fontSize: 32,
                          color: darkBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _fullName,
          style: GoogleFonts.workSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _designation,
          style: GoogleFonts.workSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4B5563),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_yearsExperience Years Professional Experience',
          style: GoogleFonts.workSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: headerBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            decoration: const BoxDecoration(
              color: primaryRed,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.workSans(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.workSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGrey, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: GoogleFonts.workSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: darkBlue,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: borderGrey, thickness: 1),
          ),
          _buildInfoRow(Icons.phone_outlined, 'PHONE', _phone),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.mail_outline_rounded, 'EMAIL', _email),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.location_on_outlined, 'PRIMARY AREA', _area),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: darkBlue, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.workSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.workSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: darkBlue,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Client Feedback',
                style: GoogleFonts.workSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: darkBlue,
                ),
              ),
              Text(
                'VIEW ALL',
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: primaryRed,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: _feedbacks.isEmpty
              ? Center(
                  child: Text(
                    'No feedback available yet.',
                    style: GoogleFonts.workSans(
                      color: textGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: _feedbacks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final feedback = _feedbacks[index];
                    return _buildFeedbackCard(feedback);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    // Dynamic Firebase Fields
    final clientName = feedback['clientName']?.toString() ?? 'Anonymous';
    final memberType = feedback['memberType']?.toString() ?? 'MEMBER';
    final reviewText = feedback['reviewText']?.toString() ?? '';
    final clientImage = feedback['clientImageUrl']?.toString() ?? '';

    // Safety parse rating
    int rating = 5;
    if (feedback['rating'] != null) {
      rating = double.tryParse(feedback['rating'].toString())?.round() ?? 5;
    }

    String initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : 'U';

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGrey, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: primaryRed,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              reviewText.isNotEmpty
                  ? '"$reviewText"'
                  : 'No written review provided.',
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: reviewText.isNotEmpty
                    ? const Color(0xFF374151)
                    : textGrey,
                fontStyle: reviewText.isNotEmpty
                    ? FontStyle.normal
                    : FontStyle.italic,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: borderGrey,
                backgroundImage: clientImage.isNotEmpty
                    ? NetworkImage(clientImage)
                    : null,
                child: clientImage.isEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 10,
                          color: darkBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style: GoogleFonts.workSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: darkBlue,
                    ),
                  ),
                  Text(
                    memberType.toUpperCase(),
                    style: GoogleFonts.workSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF4B5563), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.workSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.workSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 15),
      decoration: const BoxDecoration(
        color: _TrainerProfileScreenState.headerBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          Align(
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'JoE',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: _KettlebellIcon(size: 18),
                    ),
                  ),
                  TextSpan(
                    text: 'V ',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                  TextSpan(
                    text: 'FITNESS',
                    style: GoogleFonts.workSans(
                      color: _TrainerProfileScreenState.primaryRed,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        color: _TrainerProfileScreenState.headerBlue,
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
        selectedItemColor: const Color(0xFF01BCE3),
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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerHomeScreen()),
            );
          } else if (index == 1) {
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
          } else if (index == 5) {
            // --> NAVIGATE TO NOTIFICATION SCREEN <--
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const TrainerNotificationsScreen(),
              ),
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
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _KettlebellPainter()),
  );
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
    final double w = size.width, h = size.height;
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
    Path k = Path.combine(PathOperation.union, handle, body);
    k = Path.combine(
      PathOperation.difference,
      k,
      Path()..addRect(Rect.fromLTRB(0, h * 0.94, w, h)),
    );
    k = Path.combine(
      PathOperation.difference,
      k,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.40, h * 0.20, w * 0.60, h * 0.45),
          Radius.circular(w * 0.1),
        ),
      ),
    );
    canvas.drawPath(k.shift(const Offset(1.5, 1.5)), shadowPaint);
    canvas.drawPath(k, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
