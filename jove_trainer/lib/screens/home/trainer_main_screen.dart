import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'trainer_home_screen.dart';
import '../schedules/trainer_schedules_screen.dart';
import '../users/trainer_users_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../profile/trainer_profile_screen.dart';
import '../../services/language_service.dart';
import '../../services/trainer_data_service.dart';

/// Central Persistent Navigation Shell holding all 5 primary tabs in an IndexedStack.
/// Switching tabs happens instantaneously (0ms) without screen rebuilds or loading spinners.
class TrainerMainScreen extends StatefulWidget {
  final int initialIndex;
  const TrainerMainScreen({super.key, this.initialIndex = 0});

  /// Helper to switch tabs from anywhere in the widget hierarchy
  static void switchTab(BuildContext context, int index) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
    final state = context.findAncestorStateOfType<_TrainerMainScreenState>();
    if (state != null) {
      state.setIndex(index);
    } else {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => TrainerMainScreen(initialIndex: index)),
        (route) => false,
      );
    }
  }

  @override
  State<TrainerMainScreen> createState() => _TrainerMainScreenState();
}

class _TrainerMainScreenState extends State<TrainerMainScreen> {
  late int _currentIndex;
  late final PageController _pageController;

  final List<Widget> _pages = const [
    TrainerHomeScreen(isEmbeddedInShell: true),
    TrainerSchedulesScreen(isEmbeddedInShell: true),
    TrainerUsersScreen(isEmbeddedInShell: true),
    TrainerNotesScreen(isEmbeddedInShell: true),
    TrainerProfileScreen(isEmbeddedInShell: true),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Silently preheat data cache in the background
    TrainerDataService().preloadAll(notify: false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void setIndex(int index, {bool animate = true}) {
    if (index >= 0 && index < _pages.length) {
      setState(() => _currentIndex = index);
      if (_pageController.hasClients) {
        if (animate && (_pageController.page?.round() != index)) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 150),
            curve: Curves.fastOutSlowIn,
          );
        } else {
          _pageController.jumpToPage(index);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;
    final primaryColor = Theme.of(context).primaryColor;
    final selectedColor = Theme.of(context).colorScheme.secondary;

    final navItems = [
      (Icons.home_outlined, Icons.home, strings['home'] ?? 'Home'),
      (Icons.calendar_today_outlined, Icons.calendar_today, strings['schedules'] ?? 'Schedules'),
      (Icons.group_outlined, Icons.group, strings['users'] ?? 'Users'),
      (Icons.description_outlined, Icons.description, strings['notes'] ?? 'Notes'),
      (Icons.person_outline, Icons.person, strings['profile'] ?? 'Profile'),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        padEnds: false,
        physics: const PageScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: selectedColor,
          unselectedItemColor: Colors.white,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: GoogleFonts.workSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.workSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: [
            for (final item in navItems)
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
          onTap: (index) => setIndex(index, animate: true),
        ),
      ),
    );
  }
}
