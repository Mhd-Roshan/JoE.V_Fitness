import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- BOTTOM NAVIGATION IMPORTS ---
import '../home/trainer_home_screen.dart';
import '../schedules/trainer_schedules_screen.dart';
import '../users/trainer_users_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../profile/trainer_profile_screen.dart';
import '../notifications/trainer_notifications_screen.dart';

// --- LOCALIZATION & SERVICES IMPORTS ---
import '../../services/language_service.dart';
import '../../l10n/app_en.dart' as loc_en;
import '../../l10n/app_ml.dart' as loc_ml;
import '../../l10n/app_hi.dart' as loc_hi;
import '../../l10n/app_ta.dart' as loc_ta;

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  // Theme Colors
  static const Color darkBlue = Color(0xFF00225D);
  static const Color primaryRed = Color(0xFFC7001A);
  static const Color bgGrey = Color(0xFFFAFAFA);
  static const Color borderGrey = Color(0xFFE5E7EB);
  static const Color textGrey = Color(0xFF6B7280);

  // State Variables
  bool _notificationsEnabled = true;
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = languageService.currentLanguage;
  }

  Map<String, String> get _strings {
    switch (_selectedLanguage) {
      case 'ml':
        return loc_ml.AppStrings.ml;
      case 'hi':
        return loc_hi.AppStrings.hi;
      case 'ta':
        return loc_ta.AppStrings.ta;
      case 'en':
      default:
        return loc_en.AppStrings.en;
    }
  }

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ml', 'name': 'മലയാളം'},
    {'code': 'hi', 'name': 'हिंदी'},
    {'code': 'ta', 'name': 'தமிழ்'},
  ];

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _strings['selectLanguage'] ?? 'Select Language',
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 16),
                ..._languages.map((lang) {
                  final isSelected = lang['code'] == _selectedLanguage;
                  return ListTile(
                    leading: Icon(
                      Icons.language,
                      color: isSelected ? primaryRed : textGrey,
                    ),
                    title: Text(
                      lang['name']!,
                      style: GoogleFonts.workSans(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? darkBlue : textGrey,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: primaryRed)
                        : null,
                    onTap: () {
                      // 1. Instantly update the UI on THIS screen
                      setState(() {
                        _selectedLanguage = lang['code']!;
                      });

                      // 2. Save language preference in your service
                      languageService.setLanguage(lang['code']!);

                      // 3. Close the bottom sheet
                      Navigator.pop(context);

                      // 4. SEAMLESS TRANSITION!
                      // Instead of restarting the whole app/showing the Splash screen,
                      // we just clear the back-history and drop them cleanly on the Home screen.
                      // The Home screen will rebuild from scratch with the new language perfectly!
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const TrainerHomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      bottomNavigationBar: _BottomNav(currentIndex: 4, strings: _strings),
      body: Column(
        children: [
          const _TopHeaderBand(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        // SEAMLESS BACK ARROW FIX
                        // Forces the Profile screen to rebuild cleanly if they just press back
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const TrainerProfileScreen(),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.arrow_back,
                          color: darkBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _strings['appSettings'] ?? 'App Settings',
                        style: GoogleFonts.workSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderGrey, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDE8E8),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_active_outlined,
                                        color: primaryRed,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _strings['notifications'] ??
                                                'Notifications',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.workSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: darkBlue,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _strings['notificationsDesc'] ??
                                                'Turn alerts on or off',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.workSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: textGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              CupertinoSwitch(
                                activeTrackColor: primaryRed,
                                value: _notificationsEnabled,
                                onChanged: (val) {
                                  setState(() {
                                    _notificationsEnabled = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const Divider(
                          color: borderGrey,
                          height: 1,
                          thickness: 1,
                        ),

                        GestureDetector(
                          onTap: _showLanguagePicker,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.language_rounded,
                                          color: Color(0xFF0284C7),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _strings['language'] ??
                                                  'Language',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.workSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: darkBlue,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _strings['languageDesc'] ??
                                                  'Select app language',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.workSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: textGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _languages.firstWhere(
                                            (l) =>
                                                l['code'] == _selectedLanguage,
                                          )['name'] ??
                                          'English',
                                      style: GoogleFonts.workSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textGrey,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: textGrey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}

// ---------------------------------------------------------
// REUSABLE WIDGETS FOR HEADER & NAVIGATION
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
      decoration: const BoxDecoration(
        color: Color(0xFF003AA3),
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
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const TrainerProfileScreen(),
                  ),
                );
              },
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
      decoration: const BoxDecoration(
        color: Color(0xFF003AA3),
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
