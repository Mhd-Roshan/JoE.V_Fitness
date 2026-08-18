import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Haptic Feedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'booking_screen.dart';
import 'trainer_selection_screen.dart';
import 'reschedule_screen.dart';
import 'progress_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart'; // <-- IMPORTED PROFILE SCREEN HERE

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);

  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _bookingStream;
  late Stream<QuerySnapshot> _chatStream;

  bool _isNavigating = false; // Prevents double-tap lag

  @override
  void initState() {
    super.initState();
    final String uid = currentUser?.uid ?? '';

    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
    _bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .snapshots();
    _chatStream = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  // --- OPTIMIZED NAVIGATION (FIXES LAG) ---

  // 1. Standard Navigation for Progress, Chat, and Profile
  Future<void> _handleStandardNavigation(Widget screen, int index) async {
    if (_isNavigating) return;
    HapticFeedback.selectionClick(); // <-- Added tactile feedback
    setState(() => _isNavigating = true);
    _selectedIndexNotifier.value = index;

    // MAGIC ANTI-LAG TRICK: Yield the UI thread for 50ms so the tap animation
    // and nav bar color change can render BEFORE building the heavy target screen.
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, b) => screen,
        transitionsBuilder: (context, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 150),
      ),
    );

    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  // 2. Booking Navigation (Requires Firebase check)
  Future<void> _handleBookingNavigation([
    Map<String, dynamic>? userData,
  ]) async {
    if (_isNavigating) return;
    HapticFeedback.selectionClick(); // <-- Added tactile feedback
    setState(() => _isNavigating = true);
    _selectedIndexNotifier.value = 1;

    // Instantly show visual feedback so UI doesn't freeze waiting for Firebase
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF003AA3)),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      if (userData == null) {
        final uid = currentUser?.uid ?? '';
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        userData = doc.data() ?? {};
      }

      String? trainerId = userData['assignedTrainerId'];
      Widget nextScreen;

      if (trainerId == null || trainerId.isEmpty) {
        nextScreen = const SelectTrainerScreen();
      } else {
        // Fetch from cache first for instantaneous loads
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

        if (trainerDoc.exists) {
          nextScreen = BookingScreen(
            trainer: Trainer.fromFirestore(trainerDoc),
          );
        } else {
          nextScreen = const SelectTrainerScreen();
        }
      }

      if (!mounted) return;

      // Pop loading dialog
      Navigator.pop(context);

      // LAG FIX: Use pushReplacement to stop the navigation stack from leaking memory
      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a, b) => nextScreen,
          transitionsBuilder: (context, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop dialog on error
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error loading data.')));
      }
    } finally {
      if (mounted) {
        _selectedIndexNotifier.value = 0; // Reset state silently
        setState(() => _isNavigating = false);
      }
    }
  }

  void _handleRescheduleClick(
    String bookingId,
    Map<String, dynamic> bookingData,
  ) {
    try {
      HapticFeedback.lightImpact();
      String dateStr = bookingData['date'] ?? '';
      String timeStr = bookingData['time'] ?? '';

      DateTime sessionDateTime = DateFormat(
        'yyyy-MM-dd h:mm a',
      ).parse('$dateStr $timeStr');
      DateTime now = DateTime.now();

      if (sessionDateTime.difference(now).inMinutes < 120 &&
          sessionDateTime.isAfter(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sessions cannot be rescheduled within 2 hours of start time.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RescheduleScreen(bookingId: bookingId, bookingData: bookingData),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error processing session date/time. Please contact support.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          var userData =
              userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RepaintBoundary(child: _HeaderSection(userData: userData)),

                    // RepaintBoundary drastically reduces lag on complex gradients/shadows
                    RepaintBoundary(
                      child: _UpcomingSessionSection(
                        bookingStream: _bookingStream,
                        onReschedule: _handleRescheduleClick,
                      ),
                    ),

                    RepaintBoundary(
                      child: _QuickActionsSection(
                        userData: userData,
                        onBookingTap: () => _handleBookingNavigation(userData),
                      ),
                    ),

                    RepaintBoundary(
                      child: _TodayProgressSection(userData: userData),
                    ),

                    RepaintBoundary(
                      child: _RecentChatsSection(
                        chatStream: _chatStream,
                        onChatTap: () =>
                            _handleStandardNavigation(const ChatScreen(), 3),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _FloatingNavBar(
                  selectedIndexNotifier: _selectedIndexNotifier,
                  onBookingTap: () => _handleBookingNavigation(userData),
                  onStatsTap: () =>
                      _handleStandardNavigation(const ProgressScreen(), 2),
                  onChatsTap: () =>
                      _handleStandardNavigation(const ChatScreen(), 3),
                  onProfileTap:
                      () => // <-- ADDED PROFILE NAVIGATION
                          _handleStandardNavigation(const ProfileScreen(), 4),
                  isNavigating: _isNavigating,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final Map<String, dynamic> userData;
  const _HeaderSection({required this.userData});

  @override
  Widget build(BuildContext context) {
    String userName =
        userData['fullName'] ??
        userData['name'] ??
        userData['firstName'] ??
        'Athlete';
    String profilePic = userData['profilePic'] ?? userData['imageUrl'] ?? '';
    String todayDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todayDate,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: profilePic.isNotEmpty
                ? NetworkImage(profilePic)
                : null,
            child: profilePic.isEmpty
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _UpcomingSessionSection extends StatelessWidget {
  final Stream<QuerySnapshot> bookingStream;
  final Function(String, Map<String, dynamic>) onReschedule;

  const _UpcomingSessionSection({
    required this.bookingStream,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: bookingStream,
        builder: (context, bookingSnapshot) {
          bool hasBooking = false;
          Map<String, dynamic>? bookingData;
          String? bookingId;
          String displayDate = 'TBD';

          if (bookingSnapshot.hasData &&
              bookingSnapshot.data!.docs.isNotEmpty) {
            DateTime now = DateTime.now();
            String todayFormatted = DateFormat('yyyy-MM-dd').format(now);

            var futureBookings = bookingSnapshot.data!.docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'cancelled') return false;

              try {
                DateTime sessionDateTime = DateFormat(
                  'yyyy-MM-dd h:mm a',
                ).parse('${data['date']} ${data['time']}');
                return sessionDateTime.isAfter(now);
              } catch (e) {
                return (data['date'] ?? '').compareTo(todayFormatted) >= 0;
              }
            }).toList();

            if (futureBookings.isNotEmpty) {
              var parsedBookings = futureBookings.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                DateTime? dt;
                try {
                  dt = DateFormat(
                    'yyyy-MM-dd h:mm a',
                  ).parse('${data['date']} ${data['time']}');
                } catch (e) {
                  dt = DateTime(2099);
                }
                return {'doc': doc, 'dt': dt};
              }).toList();

              parsedBookings.sort(
                (a, b) => (a['dt'] as DateTime).compareTo(b['dt'] as DateTime),
              );

              var nextBookingDoc =
                  parsedBookings.first['doc'] as DocumentSnapshot;
              hasBooking = true;
              bookingId = nextBookingDoc.id;
              bookingData = nextBookingDoc.data() as Map<String, dynamic>;

              if (bookingData['date'] == todayFormatted) {
                displayDate = 'Today';
              } else {
                try {
                  DateTime parsed = DateFormat(
                    'yyyy-MM-dd',
                  ).parse(bookingData['date']);
                  displayDate = DateFormat('MMM d').format(parsed);
                } catch (e) {
                  displayDate = bookingData['date'];
                }
              }
            }
          }

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment(-0.8, -0.8),
                end: Alignment(1.0, 1.0),
                stops: [0.0, 0.45, 0.65, 0.85, 1.0],
                colors: [
                  Color(0xFFE2EBE5),
                  Color(0xFFF1E6B9),
                  Color(0xFFFF5B3E),
                  Color(0xFF141F36),
                  Color(0xFFB7C7F5),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming Session',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasBooking)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Confirmed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasBooking) ...[
                  Text(
                    bookingData!['sessionType'] ?? 'Training Session',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bookingData['trainerName'] ?? 'Trainer',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$displayDate • ${bookingData['time'] ?? 'TBD'}',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                bookingData['status'] == 'pending'
                                    ? 'Pending'
                                    : 'Arriving',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              onReschedule(bookingId!, bookingData!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBB0013),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Reschedule',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Rest Day',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take time to recover, or book a new session.',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onBookingTap;

  const _QuickActionsSection({
    required this.userData,
    required this.onBookingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Quick Action',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _QuickActionPill(
                title: 'Booking',
                icon: Icons.calendar_month_outlined,
                pillColor: const Color.fromARGB(255, 180, 4, 22),
                iconColor: const Color(0xFFBB0013),
                textColor: Colors.white,
                onTap: onBookingTap,
              ),
              const _QuickActionPill(
                title: 'Health',
                icon: Icons.monitor_heart_outlined,
                pillColor: Color.fromARGB(255, 143, 228, 240),
                iconColor: Color.fromARGB(255, 0, 14, 199),
              ),
              const _QuickActionPill(
                title: 'Diet',
                icon: Icons.restaurant_menu_outlined,
                pillColor: Color.fromARGB(78, 0, 233, 20),
                iconColor: Color.fromARGB(255, 69, 221, 77),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _TodayProgressSection extends StatelessWidget {
  final Map<String, dynamic> userData;
  const _TodayProgressSection({required this.userData});

  @override
  Widget build(BuildContext context) {
    double exactCardWidth = (MediaQuery.of(context).size.width - 48 - 16) / 2;

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    Map<String, dynamic> dailyWeightMap = userData['dailyWeight'] != null
        ? Map<String, dynamic>.from(userData['dailyWeight'])
        : {};
    String weight =
        dailyWeightMap[today]?.toString() ??
        userData['weight']?.toString() ??
        '0';

    Map<String, dynamic> dailyHydrationMap = userData['dailyHydration'] != null
        ? Map<String, dynamic>.from(userData['dailyHydration'])
        : {};
    String hydration = dailyHydrationMap[today] != null
        ? (dailyHydrationMap[today] / 1000).toString().replaceAll(
            RegExp(r'\.0$'),
            '',
          )
        : '0';

    Map<String, dynamic> dailySleepMap = userData['dailySleep'] != null
        ? Map<String, dynamic>.from(userData['dailySleep'])
        : {};
    String sleep =
        dailySleepMap[today]?.toString() ??
        userData['sleep']?.toString() ??
        '0';

    Map<String, dynamic> dailyStepsMap = userData['dailySteps'] != null
        ? Map<String, dynamic>.from(userData['dailySteps'])
        : {};
    String steps =
        dailyStepsMap[today]?.toString() ??
        userData['steps']?.toString() ??
        '0';

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black87,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _ProgressCard(
                exactWidth: exactCardWidth,
                title: 'Weight\nProgress',
                value: weight,
                unit: 'Kg',
                icon: Icons.monitor_weight_outlined,
                iconColor: const Color(0xFFFF9500),
              ),
              _ProgressCard(
                exactWidth: exactCardWidth,
                title: 'Daily\nHydration',
                value: hydration,
                unit: 'Liters',
                icon: Icons.water_drop_outlined,
                iconColor: const Color(0xFF007AFF),
              ),
              _ProgressCard(
                exactWidth: exactCardWidth,
                title: 'Sleep\nDuration',
                value: sleep,
                unit: 'Hours',
                icon: Icons.nightlight_outlined,
                iconColor: const Color(0xFFAF52DE),
              ),
              _ProgressCard(
                exactWidth: exactCardWidth,
                title: 'Daily\nSteps',
                value: steps,
                unit: 'Steps',
                icon: Icons.directions_walk_outlined,
                iconColor: const Color(0xFF34C759),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final double exactWidth;
  final String title, value, unit;
  final IconData icon;
  final Color iconColor;

  const _ProgressCard({
    required this.exactWidth,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: exactWidth,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentChatsSection extends StatelessWidget {
  final Stream<QuerySnapshot> chatStream;
  final VoidCallback onChatTap;

  const _RecentChatsSection({
    required this.chatStream,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Chats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black87,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream: chatStream,
            builder: (context, chatSnapshot) {
              // Even if empty, we provide a placeholder that routes to ChatScreen
              if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
                return GestureDetector(
                  onTap: onChatTap,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No recent chats. Tap to start.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: chatSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var chat =
                      chatSnapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: onChatTap, // ADDED: TAP CARD TO CHAT
                    child: _ChatCard(
                      name: chat['senderName'] ?? 'Admin',
                      message: chat['lastMessage'] ?? 'Tap to view message',
                      avatarUrl:
                          chat['senderImage'] ??
                          'https://ui-avatars.com/api/?name=Admin&background=00215F&color=fff',
                      isUnread: chat['unread'] ?? false,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color pillColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _QuickActionPill({
    required this.title,
    required this.icon,
    required this.pillColor,
    required this.iconColor,
    this.textColor = Colors.black87,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap!();
        }
      },
      child: Container(
        width: 145,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.only(left: 6, top: 6, bottom: 6, right: 16),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final String name, message, avatarUrl;
  final bool isUnread;

  const _ChatCard({
    required this.name,
    required this.message,
    required this.avatarUrl,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final ValueNotifier<int> selectedIndexNotifier;
  final VoidCallback onBookingTap;
  final VoidCallback onStatsTap;
  final VoidCallback onChatsTap;
  final VoidCallback onProfileTap;
  final bool isNavigating;

  const _FloatingNavBar({
    required this.selectedIndexNotifier,
    required this.onBookingTap,
    required this.onStatsTap,
    required this.onChatsTap,
    required this.onProfileTap,
    required this.isNavigating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 33, 95),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                index: 0,
                icon: Icons.home_filled,
                label: 'Home',
                selectedIndex: selectedIndex,
                onTap: () {
                  if (selectedIndex != 0 && !isNavigating) {
                    HapticFeedback.selectionClick();
                    selectedIndexNotifier.value = 0;
                  }
                },
              ),
              _NavItem(
                index: 1,
                icon: Icons.calendar_today_rounded,
                label: 'Booking',
                selectedIndex: selectedIndex,
                onTap: () {
                  if (selectedIndex != 1 && !isNavigating) {
                    onBookingTap();
                  }
                },
              ),
              _NavItem(
                index: 2,
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                selectedIndex: selectedIndex,
                onTap: () {
                  if (selectedIndex != 2 && !isNavigating) {
                    onStatsTap();
                  }
                },
              ),
              _NavItem(
                index: 3,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chats',
                selectedIndex: selectedIndex,
                onTap: () {
                  if (selectedIndex != 3 && !isNavigating) {
                    onChatsTap();
                  }
                },
              ),
              _NavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                selectedIndex: selectedIndex,
                onTap: () {
                  if (selectedIndex != 4 && !isNavigating) {
                    onProfileTap();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0)
            : const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
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
