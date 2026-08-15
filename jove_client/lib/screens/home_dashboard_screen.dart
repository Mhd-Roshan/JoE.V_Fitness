import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String get _todayDate {
    return DateFormat('MMM dd yyyy').format(DateTime.now()).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Calculates exact width for half-screen cards (Accounting for padding)
    double screenWidth = MediaQuery.of(context).size.width;
    double exactCardWidth = (screenWidth - 48 - 16) / 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFBA0C19)),
            );
          }

          var userData =
              userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

          // ==========================================
          // PULLS THE CLIENT'S NAME FROM FIRESTORE HERE
          // ==========================================
          String userName =
              userData['fullName'] ??
              userData['name'] ??
              userData['firstName'] ??
              userData['displayName'] ??
              'Athlete';

          String package =
              userData['subscriptionPackage'] ?? 'Premium Package 3';
          String profilePic =
              userData['profilePic'] ?? userData['imageUrl'] ?? '';

          String currentWeight = userData['weight']?.toString() ?? '0';
          String currentHydration = userData['hydration']?.toString() ?? '0';
          String currentSleep = userData['sleep']?.toString() ?? '0';
          String currentSteps = userData['steps']?.toString() ?? '0';

          String weightBadge = userData['weightBadge']?.toString() ?? '-0.4kg';
          String hydrationBadge =
              userData['hydrationBadge']?.toString() ?? '88%';
          String sleepBadge = userData['sleepBadge']?.toString() ?? 'Good';
          String stepsBadge = userData['stepsBadge']?.toString() ?? '50%';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. RESTRUCTURED HEADER (Slimmer & Bell aligned with Name)
                // ==========================================
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top:
                        MediaQuery.of(context).padding.top +
                        8, // Reduced padding
                    left: 24,
                    right: 24,
                    bottom: 12, // Reduced bottom padding
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF003297), // Deep blue
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30), // Slightly reduced curve
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFF01BCE3),
                        width: 6,
                      ), // Thicker bottom border
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- DATE (Top Left) ---
                      Text(
                        _todayDate,
                        style: const TextStyle(
                          color: Color(0xFF82D3FA), // Light blue text
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ), // Reduced space between date and profile section
                      // --- PROFILE IMAGE, NAME, & BELL ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28, // Shrunk to make bar slimmer
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
                          // Name & Package (Expanded pushes the bell to the far right)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // CLIENT NAME
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize:
                                        22, // Kept big and bold but fits slimmer bar
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // STAR & PACKAGE
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xFFFFD700), // Gold Star
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
                          // NOTIFICATION BELL (Now perfectly aligned with the Profile row)
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

                // ==========================================
                // 2. TODAY'S SESSION
                // ==========================================
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .where('userId', isEqualTo: currentUser?.uid)
                        .orderBy('createdAt', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, bookingSnapshot) {
                      bool hasBooking =
                          bookingSnapshot.hasData &&
                          bookingSnapshot.data!.docs.isNotEmpty;
                      var bookingData = hasBooking
                          ? bookingSnapshot.data!.docs.first.data()
                                as Map<String, dynamic>
                          : null;

                      return Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF2859C5),
                            width: 3,
                          ),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://images.unsplash.com/photo-1599901860904-17e6ed7083a0?q=80&w=2070',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF23D07B,
                                  ).withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  hasBooking ? "Today's session" : "No Session",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(20),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.9),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: hasBooking
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.self_improvement,
                                                color: Color(0xFF23D07B),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  bookingData!['sessionType'] ??
                                                      'Training Session',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '👤 Trainer : ${bookingData['trainerName'] ?? 'Trainer'} • ${bookingData['time'] ?? 'TBD'}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {},
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF2859C5),
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                                    bookingData['status'] ==
                                                            'pending'
                                                        ? 'Pending'
                                                        : 'Arriving',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {},
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFBA0C19),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Reschedule',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Rest Day',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Take time to recover, or book a new session.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // ==========================================
                // 3. QUICK ACTION
                // ==========================================
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

                // ==========================================
                // 4. TODAY PROGRESS
                // ==========================================
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

                // ==========================================
                // 5. CHATS SECTION
                // ==========================================
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
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .where('participants', arrayContains: currentUser?.uid)
                        .orderBy('lastMessageTime', descending: true)
                        .snapshots(),
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
          );
        },
      ),
      // ==========================================
      // BOTTOM NAV
      // ==========================================
      bottomNavigationBar: Container(
        height: 75,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF00225D),
          borderRadius: BorderRadius.circular(35),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF01BCE3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.home, color: Colors.white),
            ),
            const Icon(Icons.calendar_month, color: Colors.grey),
            const Icon(Icons.insert_chart_outlined, color: Colors.grey),
            const Icon(Icons.chat_bubble_outline, color: Colors.grey),
            const Icon(Icons.person_outline, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- UI HELPER WIDGETS ---

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
    double exactWidth,
  ) {
    return Container(
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
