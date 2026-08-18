import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'chat_screen.dart';
import 'personal_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Theme Colors (Matching your App Theme)
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _redButton = Color(0xFFBB0013);
  static const Color _iconBg = Color(0xFFF0F2F5);

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(
    4,
  ); // 4 is Profile
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // OPTIMIZATION: Cache the stream so it doesn't rebuild on every UI frame
  Stream<DocumentSnapshot>? _userStream;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  // --- NAVIGATION LOGIC ---
  void _navigate(Widget screen) {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    HapticFeedback.selectionClick();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a, b) => screen,
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 150),
      ),
    ).then((_) {
      if (mounted) setState(() => _isNavigating = false);
    });
  }

  Future<void> _navigateToBooking() async {
    if (_isNavigating || currentUser == null) return;
    setState(() => _isNavigating = true);
    HapticFeedback.selectionClick();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _navBgColor)),
    );

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>? ?? {};
      String? trainerId = userData['assignedTrainerId'];

      Widget nextScreen;
      if (trainerId == null || trainerId.isEmpty) {
        nextScreen = const SelectTrainerScreen();
      } else {
        // Fetch with Cache first for instantaneous loading
        DocumentSnapshot trainerDoc = await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .get(const GetOptions(source: Source.cache))
            .catchError(
              (_) => FirebaseFirestore.instance
                  .collection('trainers')
                  .doc(trainerId)
                  .get(),
            );

        nextScreen = trainerDoc.exists
            ? BookingScreen(trainer: Trainer.fromFirestore(trainerDoc))
            : const SelectTrainerScreen();
      }

      if (!mounted) return;
      Navigator.pop(context); // close loader dialog

      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a, b) => nextScreen,
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading booking.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _selectedIndexNotifier.value = 4;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    HapticFeedback.mediumImpact();

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Sign Out",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text("Are you sure you want to sign out?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _redButton,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Sign Out",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Pop all screens to return to the AuthGate/Login page securely
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: StreamBuilder<DocumentSnapshot>(
              stream: _userStream,
              builder: (context, snapshot) {
                var userData =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};

                String fullName =
                    userData['fullName'] ??
                    currentUser?.displayName ??
                    'Client User';
                String package = userData['packageName'] ?? 'Premium Package';
                String photoUrl =
                    userData['photoURL'] ?? currentUser?.photoURL ?? '';
                String trainerName =
                    userData['assignedTrainerName'] ?? 'Unassigned';

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RepaintBoundary(child: _buildTopAppBar()),

                      const SizedBox(height: 16),
                      RepaintBoundary(
                        child: _buildProfileHeader(fullName, package, photoUrl),
                      ),
                      const SizedBox(height: 32),

                      // --- ACCOUNT SECTION ---
                      _buildSectionTitle('Account'),
                      _buildMenuCard([
                        _MenuItemData(
                          icon: Icons.person_outline_rounded,
                          title: 'Personal Details',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PersonalDetailsScreen(),
                              ),
                            );
                          },
                        ),
                        _MenuItemData(
                          icon: Icons.emoji_events_outlined,
                          title: 'My Goals',
                          onTap: () => HapticFeedback.lightImpact(),
                        ),
                        _MenuItemData(
                          icon: Icons.health_and_safety_outlined,
                          title: 'Health Profile',
                          onTap: () => HapticFeedback.lightImpact(),
                        ),
                        _MenuItemData(
                          icon: Icons.credit_card_outlined,
                          title: 'Subscription & Billing',
                          onTap: () => HapticFeedback.lightImpact(),
                        ),
                        _MenuItemData(
                          icon: Icons.swap_horiz_rounded,
                          title: 'Change Trainer',
                          trailingText: trainerName,
                          onTap: () => _navigate(const SelectTrainerScreen()),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // --- PREFERENCE SECTION ---
                      _buildSectionTitle('Preference'),
                      _buildMenuCard([
                        _MenuItemData(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifications',
                          onTap: () => HapticFeedback.lightImpact(),
                        ),
                        _MenuItemData(
                          icon: Icons.flag_outlined,
                          title: 'App Languages',
                          trailingText: 'English (US)',
                          onTap: () => HapticFeedback.lightImpact(),
                        ),
                        _MenuItemData(
                          icon: Icons.help_outline_rounded,
                          title: 'Support',
                          onTap: () => HapticFeedback.lightImpact(),
                        ),
                      ]),
                      const SizedBox(height: 32),

                      // --- SIGN OUT BUTTON ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _redButton,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: _handleSignOut,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),

          // --- BOTTOM NAV BAR ---
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: _textMain,
                  size: 20,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    _navigate(const HomeDashboardScreen());
                  }
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'View Profile',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05), // FIXED
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _textMain,
                size: 24,
              ),
              onPressed: () => HapticFeedback.lightImpact(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name, String package, String photoUrl) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _navBgColor.withValues(alpha: 0.1), // FIXED
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), // FIXED
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: _navBgColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _textMain,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 6),
            Text(
              package,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _navBgColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItemData> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02), // FIXED
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(index == 0 ? 20 : 0),
                  bottom: Radius.circular(index == items.length - 1 ? 20 : 0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _iconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 20, color: _navBgColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _textMain,
                          ),
                        ),
                      ),
                      if (item.trailingText != null) ...[
                        Text(
                          item.trailingText!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (index != items.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade100,
                  indent: 56,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _navBgColor,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15), // FIXED
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: _selectedIndexNotifier,
          builder: (context, selectedIndex, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(
                  index: 0,
                  icon: Icons.home_filled,
                  label: 'Home',
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const HomeDashboardScreen()),
                ),
                _NavItem(
                  index: 1,
                  icon: Icons.calendar_today_rounded,
                  label: 'Booking',
                  selectedIndex: selectedIndex,
                  onTap: _navigateToBooking,
                ),
                _NavItem(
                  index: 2,
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const ProgressScreen()),
                ),
                _NavItem(
                  index: 3,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chats',
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const ChatScreen()),
                ),
                _NavItem(
                  index: 4,
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  selectedIndex: selectedIndex,
                  onTap: () {}, // Already on Profile
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Helper class for menu items
class _MenuItemData {
  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  _MenuItemData({
    required this.icon,
    required this.title,
    this.trailingText,
    required this.onTap,
  });
}

class _NavItem extends StatelessWidget {
  final int index, selectedIndex;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0)
            : const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white70,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
