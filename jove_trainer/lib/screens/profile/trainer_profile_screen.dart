import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/trainer_home_screen.dart';
import '../schedules/trainer_schedules_screen.dart';
import '../users/trainer_users_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../notifications/trainer_notifications_screen.dart';
import 'contact_admin_screen.dart';
import 'app_settings_screen.dart';
import 'trainer_client_reviews_screen.dart';
import '../auth/login_screen.dart';

// ---> NEW: IMPORT LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  // Keep brand specific colors static
  static const Color primaryRed = Color(0xFFC7001A);

  bool _isLoading = true;
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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? {};
      final trainerQuery = await FirebaseFirestore.instance
          .collection('trainers')
          .where('trainerId', isEqualTo: uid)
          .limit(1)
          .get();
      final trainerData = trainerQuery.docs.isNotEmpty
          ? trainerQuery.docs.first.data()
          : {};
      final clientsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('trainerId', isEqualTo: uid)
          .get();
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('sessions')
          .where('trainerId', isEqualTo: uid)
          .get();
      final feedbackQuery = await FirebaseFirestore.instance
          .collection('feedbacks')
          .where('trainerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
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
              trainerData['successRate'] ?? userData['successRate'] ?? '100%';
          _clientCount = clientsQuery.docs.length;
          _totalSessions = sessionsQuery.docs.length;
          _feedbacks = feedbackQuery.docs.map((doc) => doc.data()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignOut(Map<String, String> strings) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).cardColor;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          strings['signOut'] ?? 'Sign Out',
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: Text(
          strings['signOutConfirm'] ?? 'Are you sure you want to sign out?',
          style: GoogleFonts.workSans(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              strings['cancel'] ?? 'Cancel',
              style: GoogleFonts.workSans(color: subTextColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                debugPrint("Error signing out: $e");
              }
            },
            child: Text(
              strings['signOut'] ?? 'Sign Out',
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
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS <---
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final brandBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: _BottomNav(currentIndex: 4, strings: strings),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: brandBlue))
          : Column(
              children: [
                const _TopHeaderBand(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        _buildProfileHeader(),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  strings['clients'] ?? 'Clients',
                                  _clientCount.toString(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  strings['sessions'] ?? 'Sessions',
                                  _totalSessions.toString(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  strings['rate'] ?? 'Rate',
                                  _successRate,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildPersonalInfoCard(strings),
                        ),
                        const SizedBox(height: 32),
                        _buildFeedbackSection(strings),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              _buildMenuOption(
                                icon: Icons.group_outlined,
                                title: strings['myClient'] ?? 'My Client',
                                subtitle:
                                    '$_clientCount ${strings['usersAssigned'] ?? 'users assigned'}',
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
                                title:
                                    strings['contactAdmin'] ?? 'Contact admin',
                                subtitle:
                                    strings['reportIssue'] ??
                                    'Report issue or request leave',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ContactAdminScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildMenuOption(
                                icon: Icons.settings_outlined,
                                title: strings['appSettings'] ?? 'App Settings',
                                subtitle:
                                    strings['appSettingsDesc'] ??
                                    'Language, notifications',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AppSettingsScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleSignOut(strings),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                strings['signOut'] ?? 'SIGN OUT',
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

  Widget _buildProfileHeader() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final brandBlue = Theme.of(context).colorScheme.primary;
    final dividerColor = Theme.of(context).dividerColor;

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
                border: Border.all(color: brandBlue, width: 3),
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: dividerColor,
                backgroundImage: _profileImageUrl.isNotEmpty
                    ? NetworkImage(_profileImageUrl)
                    : null,
                child: _profileImageUrl.isEmpty
                    ? Text(
                        initials,
                        style: GoogleFonts.workSans(
                          fontSize: 32,
                          color: textColor,
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
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified, color: brandBlue, size: 22),
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
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _designation,
          style: GoogleFonts.workSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: subTextColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_yearsExperience Years Professional Experience',
          style: GoogleFonts.workSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: brandBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Dynamic brand blue
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
                    color: Colors.white, // Keep white for contrast on blue
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

  Widget _buildPersonalInfoCard(Map<String, String> strings) {
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings['personalInfo'] ?? 'Personal Information',
            style: GoogleFonts.workSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: dividerColor, thickness: 1),
          ),
          _buildInfoRow(
            Icons.phone_outlined,
            strings['phone'] ?? 'PHONE',
            _phone,
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.mail_outline_rounded,
            strings['email'] ?? 'EMAIL',
            _email,
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.location_on_outlined,
            strings['primaryArea'] ?? 'PRIMARY AREA',
            _area,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final brandBlue = Theme.of(context).colorScheme.primary;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, color: brandBlue, size: 20),
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
                  color: subTextColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.workSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackSection(Map<String, String> strings) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings['clientFeedback'] ?? 'Client Feedback',
                style: GoogleFonts.workSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainerClientReviewsScreen(),
                  ),
                ),
                child: Text(
                  strings['viewAll'] ?? 'VIEW ALL',
                  style: GoogleFonts.workSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primaryRed,
                    letterSpacing: 1.0,
                  ),
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
                    strings['noFeedback'] ?? 'No feedback available yet.',
                    style: GoogleFonts.workSans(
                      color: subTextColor,
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
                  itemBuilder: (context, index) =>
                      _buildFeedbackCard(_feedbacks[index], strings),
                ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard(
    Map<String, dynamic> feedback,
    Map<String, String> strings,
  ) {
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final clientName =
        feedback['clientName']?.toString() ??
        strings['anonymous'] ??
        'Anonymous';
    final memberType =
        feedback['memberType']?.toString() ?? strings['member'] ?? 'MEMBER';
    final reviewText = feedback['reviewText']?.toString() ?? '';
    final clientImage = feedback['clientImageUrl']?.toString() ?? '';
    int rating = feedback['rating'] != null
        ? (double.tryParse(feedback['rating'].toString())?.round() ?? 5)
        : 5;
    String initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : 'U';

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: primaryRed,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              reviewText.isNotEmpty
                  ? '"$reviewText"'
                  : (strings['noWrittenReview'] ??
                        'No written review provided.'),
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: reviewText.isNotEmpty ? textColor : subTextColor,
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
                backgroundColor: dividerColor,
                backgroundImage: clientImage.isNotEmpty
                    ? NetworkImage(clientImage)
                    : null,
                child: clientImage.isEmpty
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor,
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
                      color: textColor,
                    ),
                  ),
                  Text(
                    memberType.toUpperCase(),
                    style: GoogleFonts.workSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
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
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;

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
                color: dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: subTextColor, size: 20),
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
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.workSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subTextColor),
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
                      color: const Color(0xFFC7001A),
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
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrainerNotificationsScreen(),
                ),
              ),
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
                      color: Colors.white, // Fixed to always be white here
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
        ).colorScheme.secondary, // Dynamic cyan
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
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerUsersScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerNotesScreen()),
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
