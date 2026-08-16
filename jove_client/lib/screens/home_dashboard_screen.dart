import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'booking_screen.dart';
import 'trainer_selection_screen.dart';
import 'reschedule_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _bookingStream;
  late Stream<QuerySnapshot> _chatStream;

  @override
  void initState() {
    super.initState();
    final String uid = currentUser?.uid ?? '';

    // Initialize streams exactly ONCE. Firestore will auto-push updates live!
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

  String get _todayDate {
    return DateFormat('MMM dd yyyy').format(DateTime.now()).toUpperCase();
  }

  Future<void> _handleBookingNavigation(Map<String, dynamic> userData) async {
    String? trainerId = userData['assignedTrainerId'];

    if (trainerId == null || trainerId.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SelectTrainerScreen()),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF01BCE3)),
      ),
    );

    try {
      var trainerDoc = await FirebaseFirestore.instance
          .collection('trainers')
          .doc(trainerId)
          .get();
      if (!mounted) return;
      Navigator.pop(context);

      if (trainerDoc.exists) {
        Trainer assignedTrainer = Trainer.fromFirestore(trainerDoc);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingScreen(trainer: assignedTrainer),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SelectTrainerScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error loading data.')));
    }
  }

  // 2 HOUR RESTRICTION LOGIC
  void _handleRescheduleClick(
    String bookingId,
    Map<String, dynamic> bookingData,
  ) {
    try {
      String dateStr = bookingData['date'] ?? '';
      String timeStr = bookingData['time'] ?? '';

      // Check the 2 hour restriction
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

      // Navigate to Reschedule normally. Do NOT override the stream!
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RescheduleScreen(bookingId: bookingId, bookingData: bookingData),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing session date/time.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double exactCardWidth = (screenWidth - 48 - 16) / 2;

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF01BCE3)),
            ),
          );
        }

        var userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

        String userName =
            userData['fullName'] ??
            userData['name'] ??
            userData['firstName'] ??
            'Athlete';
        String package = userData['subscriptionPackage'] ?? 'Premium Package 3';
        String profilePic =
            userData['profilePic'] ?? userData['imageUrl'] ?? '';
        String currentWeight = userData['weight']?.toString() ?? '0';
        String currentHydration = userData['hydration']?.toString() ?? '0';
        String currentSleep = userData['sleep']?.toString() ?? '0';
        String currentSteps = userData['steps']?.toString() ?? '0';

        String weightBadge = userData['weightBadge']?.toString() ?? '-0.4kg';
        String hydrationBadge = userData['hydrationBadge']?.toString() ?? '88%';
        String sleepBadge = userData['sleepBadge']?.toString() ?? 'Good';
        String stepsBadge = userData['stepsBadge']?.toString() ?? '50%';

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 24,
                    right: 24,
                    bottom: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF003297),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF01BCE3), width: 6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _todayDate,
                        style: const TextStyle(
                          color: Color(0xFF82D3FA),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF01BCE3),
                            backgroundImage: profilePic.isNotEmpty
                                ? NetworkImage(profilePic)
                                : null,
                            child: profilePic.isEmpty
                                ? Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xFFFFD700),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      package,
                                      style: TextStyle(
                                        color: Colors.grey.shade200,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none,
                              color: Color(0xFF01BCE3),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. UPCOMING SESSION
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        _bookingStream, // Relies on live Firebase stream safely!
                    builder: (context, bookingSnapshot) {
                      bool hasBooking = false;
                      Map<String, dynamic>? bookingData;
                      String? bookingId;
                      String displayDate = 'TBD';

                      if (bookingSnapshot.hasData &&
                          bookingSnapshot.data!.docs.isNotEmpty) {
                        String todayFormatted = DateFormat(
                          'yyyy-MM-dd',
                        ).format(DateTime.now());

                        var futureBookings = bookingSnapshot.data!.docs.where((
                          doc,
                        ) {
                          var data = doc.data() as Map<String, dynamic>;
                          String date = data['date'] ?? '';
                          String status = data['status'] ?? '';
                          return date.compareTo(todayFormatted) >= 0 &&
                              status != 'cancelled';
                        }).toList();

                        if (futureBookings.isNotEmpty) {
                          futureBookings.sort((a, b) {
                            var dataA = a.data() as Map<String, dynamic>;
                            var dataB = b.data() as Map<String, dynamic>;

                            String dateA = dataA['date'] ?? '2099-01-01';
                            String timeA = dataA['time'] ?? '12:00 AM';
                            String dateB = dataB['date'] ?? '2099-01-01';
                            String timeB = dataB['time'] ?? '12:00 AM';

                            try {
                              // h:mm a handles both "08:30 AM" and "8:30 AM" cleanly
                              DateTime dtA = DateFormat(
                                'yyyy-MM-dd h:mm a',
                              ).parse('$dateA $timeA');
                              DateTime dtB = DateFormat(
                                'yyyy-MM-dd h:mm a',
                              ).parse('$dateB $timeB');
                              return dtA.compareTo(dtB);
                            } catch (e) {
                              return dateA.compareTo(dateB);
                            }
                          });

                          hasBooking = true;
                          bookingId = futureBookings.first.id;
                          bookingData =
                              futureBookings.first.data()
                                  as Map<String, dynamic>;

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
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF001233),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: const Color(0xFF2859C5),
                            width: 3.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: hasBooking
                                      ? const Color(0xFF23D07B)
                                      : Colors.grey.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  hasBooking ? 'Confirmed' : 'No Session',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (hasBooking) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.self_improvement,
                                    color: Color(0xFF23D07B),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      bookingData!['sessionType'] ??
                                          'Training Session',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '👤 ${bookingData['trainerName'] ?? 'Trainer'} • 📅 $displayDate • ⏰ ${bookingData['time'] ?? 'TBD'}',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2859C5,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.access_time,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      label: Text(
                                        bookingData['status'] == 'pending'
                                            ? 'Pending'
                                            : 'Arriving',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _handleRescheduleClick(
                                        bookingId!,
                                        bookingData!,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFBA0C19,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Reschedule',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
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
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Take time to recover, or book a new session.',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 3. QUICK ACTION
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Quick Action',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2859C5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 115,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _quickActionCard(
                        'Booking',
                        Icons.calendar_month,
                        const Color(0xFFBA0C19),
                        Colors.white,
                        exactCardWidth,
                        onTap: () => _handleBookingNavigation(userData),
                      ),
                      _quickActionCard(
                        'Health',
                        Icons.monitor_heart_outlined,
                        const Color(0xFF00225D),
                        Colors.white,
                        exactCardWidth,
                      ),
                      _quickActionCard(
                        'Diet',
                        Icons.restaurant_menu,
                        const Color(0xFF00225D),
                        Colors.white,
                        exactCardWidth,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 4. TODAY PROGRESS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Today Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2859C5),
                        ),
                      ),
                      _forwardIcon(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 125,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildGridProgressCard(
                        exactWidth: exactCardWidth,
                        title: 'Current Weight',
                        value: currentWeight,
                        unit: 'Kg',
                        icon: Icons.monitor_weight_outlined,
                        mainColor: const Color(0xFFF77E36),
                        shadowColor: const Color(0xFF090088),
                        iconColor: const Color(0xFF090088),
                        badge: weightBadge,
                        badgeColor: const Color(0xFF24D17C),
                      ),
                      _buildGridProgressCard(
                        exactWidth: exactCardWidth,
                        title: 'Hydration',
                        value: currentHydration,
                        unit: 'L',
                        icon: Icons.water_drop,
                        mainColor: const Color(0xFF297FCA),
                        shadowColor: const Color(0xFF00BED6),
                        iconColor: const Color(0xFF82D3FA),
                        badge: hydrationBadge,
                        badgeColor: const Color(0xFF24D17C),
                      ),
                      _buildGridProgressCard(
                        exactWidth: exactCardWidth,
                        title: 'Sleep',
                        value: currentSleep,
                        unit: 'hrs',
                        icon: Icons.nightlight_outlined,
                        mainColor: const Color(0xFFBBBBBB),
                        shadowColor: const Color(0xFFA545D9),
                        iconColor: const Color(0xFFA545D9),
                        badge: sleepBadge,
                        badgeColor: const Color(0xFF24D17C),
                      ),
                      _buildGridProgressCard(
                        exactWidth: exactCardWidth,
                        title: 'Steps',
                        value: currentSteps,
                        unit: '',
                        icon: Icons.directions_walk,
                        mainColor: const Color(0xFF1B8B3B),
                        shadowColor: const Color(0xFF0B4A1D),
                        iconColor: Colors.white,
                        badge: stepsBadge,
                        badgeColor: const Color(0xFF00225D),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 5. CHATS SECTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Chats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2859C5),
                        ),
                      ),
                      _forwardIcon(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatStream,
                    builder: (context, chatSnapshot) {
                      if (!chatSnapshot.hasData ||
                          chatSnapshot.data!.docs.isEmpty) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
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
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No recent chats available',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: chatSnapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var chat =
                              chatSnapshot.data!.docs[index].data()
                                  as Map<String, dynamic>;
                          return _chatCard(
                            chat['senderName'] ?? 'Support',
                            chat['lastMessage'] ?? 'Tap to view message',
                            'New',
                            chat['senderImage'] ??
                                'https://ui-avatars.com/api/?name=User&background=2859C5&color=fff',
                            chat['unread'] ?? false,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            height: 70,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF001233),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStaticNavItem(0, Icons.home_filled, 'Home', userData),
                _buildStaticNavItem(
                  1,
                  Icons.calendar_month,
                  'Booking',
                  userData,
                ),
                _buildStaticNavItem(
                  2,
                  Icons.insert_chart_rounded,
                  'Stats',
                  userData,
                ),
                _buildStaticNavItem(
                  3,
                  Icons.chat_bubble_rounded,
                  'Chats',
                  userData,
                ),
                _buildStaticNavItem(
                  4,
                  Icons.person_rounded,
                  'Profile',
                  userData,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaticNavItem(
    int index,
    IconData icon,
    String label,
    Map<String, dynamic> userData,
  ) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          _handleBookingNavigation(userData);
          return;
        }
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 10.0 : 6.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF01BCE3) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 22,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _forwardIcon() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF01BCE3).withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF01BCE3).withValues(alpha: 0.3),
        ),
      ),
      child: const Icon(
        Icons.arrow_forward_ios,
        color: Color(0xFF01BCE3),
        size: 14,
      ),
    );
  }

  Widget _quickActionCard(
    String title,
    IconData icon,
    Color bgColor,
    Color iconColor,
    double exactWidth, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: exactWidth,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2859C5), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: iconColor.withValues(alpha: 0.8), size: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridProgressCard({
    required double exactWidth,
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color mainColor,
    required Color shadowColor,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      width: exactWidth,
      height: 115,
      margin: const EdgeInsets.only(right: 16, bottom: 6, left: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mainColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: shadowColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(-5, 5),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 22),
              Text(
                badge,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chatCard(
    String name,
    String message,
    String time,
    String avatarUrl,
    bool isUnread,
  ) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              if (isUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBA0C19),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
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
                          color: Color(0xFF2859C5),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: isUnread ? const Color(0xFFBA0C19) : Colors.grey,
                        fontSize: 10,
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: isUnread ? Colors.black87 : Colors.grey,
                    fontSize: 12,
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
