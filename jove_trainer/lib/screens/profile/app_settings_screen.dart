import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- THEME IMPORTS ---
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';

import '../home/trainer_main_screen.dart';
import '../home/trainer_home_screen.dart';
import '../profile/trainer_profile_screen.dart';
import '../notifications/trainer_notifications_screen.dart';

// ---> IMPORT LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  // Brand Colors
  static const Color primaryRed = Color(0xFFC7001A);

  // State Variables
  bool _notificationsEnabled = true;
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = languageService.currentLanguage;
  }

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ml', 'name': 'മലയാളം'},
    {'code': 'hi', 'name': 'हिंदी'},
    {'code': 'ta', 'name': 'தமிழ்'},
  ];

  // ----------------------------------------------------
  // LANGUAGE PICKER BOTTOM SHEET
  // ----------------------------------------------------
  void _showLanguagePicker(Color textColor, Color subTextColor) {
    final strings = languageService.strings;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
                  strings['selectLanguage'] ?? 'Select Language',
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                ..._languages.map((lang) {
                  final isSelected = lang['code'] == _selectedLanguage;
                  return ListTile(
                    leading: Icon(
                      Icons.language,
                      color: isSelected ? primaryRed : subTextColor,
                    ),
                    title: Text(
                      lang['name']!,
                      style: GoogleFonts.workSans(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? textColor : subTextColor,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: primaryRed)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLanguage = lang['code']!;
                      });
                      languageService.setLanguage(lang['code']!);
                      Navigator.pop(context);
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

  // ----------------------------------------------------
  // THEME PICKER BOTTOM SHEET (NEW!)
  // ----------------------------------------------------
  void _showThemePicker(
    ThemeProvider themeProvider,
    Color textColor,
    Color subTextColor,
  ) {
    final strings = languageService.strings;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
                  strings['theme'] ?? 'App Theme',
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildThemeOption(
                  themeProvider,
                  ThemeMode.system,
                  strings['systemDefault'] ?? 'System Default',
                  Icons.settings_system_daydream_rounded,
                  textColor,
                  subTextColor,
                ),
                _buildThemeOption(
                  themeProvider,
                  ThemeMode.light,
                  strings['lightMode'] ?? 'Light Mode',
                  Icons.light_mode_rounded,
                  textColor,
                  subTextColor,
                ),
                _buildThemeOption(
                  themeProvider,
                  ThemeMode.dark,
                  strings['darkMode'] ?? 'Dark Mode',
                  Icons.dark_mode_rounded,
                  textColor,
                  subTextColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    ThemeProvider provider,
    ThemeMode mode,
    String title,
    IconData icon,
    Color textColor,
    Color subTextColor,
  ) {
    final isSelected = provider.themeMode == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF01BCE3) : subTextColor,
      ),
      title: Text(
        title,
        style: GoogleFonts.workSans(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? textColor : subTextColor,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF01BCE3))
          : null,
      onTap: () {
        provider.setThemeMode(mode); // Updates the app instantly!
        Navigator.pop(context);
      },
    );
  }

  String _getThemeLabel(ThemeMode mode, Map<String, String> strings) {
    switch (mode) {
      case ThemeMode.light:
        return strings['light'] ?? 'Light';
      case ThemeMode.dark:
        return strings['dark'] ?? 'Dark';
      case ThemeMode.system:
        return strings['system'] ?? 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // --- DYNAMIC THEME COLORS ---
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: _BottomNav(currentIndex: 4, strings: strings),
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
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const TrainerProfileScreen(),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.arrow_back,
                          color: textColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        strings['appSettings'] ?? 'App Settings',
                        style: GoogleFonts.workSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: dividerColor, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        // ------------------------------------
                        // 1. NOTIFICATIONS TOGGLE
                        // ------------------------------------
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
                                        color: primaryRed.withValues(
                                          alpha: 0.1,
                                        ),
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
                                            strings['notifications'] ??
                                                'Notifications',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.workSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            strings['notificationsDesc'] ??
                                                'Turn alerts on or off',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.workSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: subTextColor,
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

                        Divider(color: dividerColor, height: 1, thickness: 1),

                        // ------------------------------------
                        // 2. THEME SELECTOR
                        // ------------------------------------
                        GestureDetector(
                          onTap: () => _showThemePicker(
                            themeProvider,
                            textColor,
                            subTextColor,
                          ),
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
                                          color: const Color(
                                            0xFF01BCE3,
                                          ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          themeProvider.themeMode ==
                                                  ThemeMode.dark
                                              ? Icons.dark_mode_rounded
                                              : (themeProvider.themeMode ==
                                                        ThemeMode.light
                                                    ? Icons.light_mode_rounded
                                                    : Icons
                                                          .settings_system_daydream_rounded),
                                          color: const Color(
                                            0xFF01BCE3,
                                          ), // Cyan accent
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
                                              strings['theme'] ?? 'App Theme',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.workSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              strings['themeDesc'] ??
                                                  'Match device or pick a theme',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.workSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: subTextColor,
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
                                      _getThemeLabel(
                                        themeProvider.themeMode,
                                        strings,
                                      ),
                                      style: GoogleFonts.workSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: subTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: subTextColor,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        Divider(color: dividerColor, height: 1, thickness: 1),

                        // ------------------------------------
                        // 3. LANGUAGE PICKER
                        // ------------------------------------
                        GestureDetector(
                          onTap: () =>
                              _showLanguagePicker(textColor, subTextColor),
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
                                              strings['language'] ?? 'Language',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.workSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              strings['languageDesc'] ??
                                                  'Select app language',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.workSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: subTextColor,
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
                                        color: subTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: subTextColor,
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
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Dynamic Header Color
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
                      color: Colors.white,
                      size: 20,
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData &&
                            snapshot.data!.docs.isNotEmpty) {
                          final userEmail = FirebaseAuth.instance.currentUser?.email;
                          final hasUnread = snapshot.data!.docs.any((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final isForMe = TrainerNotificationsScreen.isNotificationForTrainer(
                              data: data,
                              uid: uid ?? '',
                              userEmail: userEmail,
                            );
                            final isUnread = TrainerNotificationsScreen.isNotificationUnread(data);
                            return isForMe && isUnread;
                          });
                          if (hasUnread) {
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
        color: Theme.of(context).primaryColor, // Dynamic Header Color
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
        selectedItemColor: Theme.of(context).colorScheme.secondary,
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
          TrainerMainScreen.switchTab(context, index);
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
