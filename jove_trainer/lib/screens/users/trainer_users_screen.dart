import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'client_profile_screen.dart';
import '../notifications/trainer_notifications_screen.dart';

import '../../services/language_service.dart';
import '../home/trainer_main_screen.dart';

import '../../services/trainer_data_service.dart';

class TrainerUsersScreen extends StatefulWidget {
  final bool isEmbeddedInShell;
  const TrainerUsersScreen({super.key, this.isEmbeddedInShell = false});

  @override
  State<TrainerUsersScreen> createState() => _TrainerUsersScreenState();
}

// Data Model to represent the UI in the image
class _ClientData {
  final String id;
  final String name;
  final String initials;
  final String details;
  final int completedSessions;
  final int totalSessions;
  final int progressPercent;
  final String? medicalWarning;
  final String status;
  final String? photoUrl;

  _ClientData({
    required this.id,
    required this.name,
    required this.initials,
    required this.details,
    required this.completedSessions,
    required this.totalSessions,
    required this.progressPercent,
    this.medicalWarning,
    required this.status,
    this.photoUrl,
  });
}

class _TrainerUsersScreenState extends State<TrainerUsersScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    if (TrainerDataService().isInitialized) {
      _parseFromCache();
      _fetchUsers(showSpinner: false);
    } else {
      _fetchUsers(showSpinner: true);
    }
  }

  void _parseFromCache() {
    final cache = TrainerDataService();
    if (!cache.isInitialized) return;
    _processDocs(
      cache.myTrainerIds,
      cache.myTrainerNames,
      cache.myTrainerEmails,
      cache.allUsersDocs,
      cache.allTrainersDocs,
      cache.allSessionsDocs,
      cache.allBookingsDocs,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static int _sessionsFromDurationString(String str) {
    if (str.isEmpty) return 26;
    final sessMatch = RegExp(r'(\d+)\s*(?:sessions?|class(?:es)?)', caseSensitive: false).firstMatch(str);
    if (sessMatch != null) {
      final s = int.tryParse(sessMatch.group(1) ?? '0') ?? 0;
      if (s > 0) return s;
    }
    if (str.contains('12 month') || str.contains('1 year') || str.contains('annual') || str.contains('12m') || str.contains('1y')) {
      return 312;
    }
    if (str.contains('6 month') || str.contains('6m') || str.contains('half year')) {
      return 156;
    }
    if (str.contains('3 month') || str.contains('3m') || str.contains('quarter')) {
      return 78;
    }
    if (str.contains('2 month') || str.contains('2m')) {
      return 52;
    }
    if (str.contains('1 month') || str.contains('1m') || str.contains('monthly') || str.contains('standard')) {
      return 26;
    }
    if (str.contains('month')) {
      final mMatch = RegExp(r'(\d+)\s*month').firstMatch(str);
      final months = int.tryParse(mMatch?.group(1) ?? '1') ?? 1;
      return months * 26;
    }
    if (str.contains('week')) {
      final wMatch = RegExp(r'(\d+)\s*week').firstMatch(str);
      final weeks = int.tryParse(wMatch?.group(1) ?? '1') ?? 1;
      return weeks * 6;
    }
    final numMatch = RegExp(r'(\d+)').firstMatch(str);
    if (numMatch != null) {
      final n = int.tryParse(numMatch.group(1) ?? '0') ?? 0;
      if (n > 0 && n <= 365) return n;
    }
    return 26;
  }

  static int _calculatePackageTotalSessions(Map<String, dynamic> data, int totalBookingsCount) {
    for (final key in [
      'totalSessions',
      'totalCount',
      'packageSessions',
      'sessionsCount',
      'sessionCount',
      'maxSessions',
      'totalPackageSessions',
    ]) {
      if (data[key] != null) {
        final val = int.tryParse(data[key].toString());
        if (val != null && val > 0) return val;
      }
    }

    for (final key in ['subscription', 'package', 'membership', 'activePlan', 'planDetails']) {
      if (data[key] is Map) {
        final map = data[key] as Map;
        for (final subKey in ['totalSessions', 'sessions', 'sessionsCount', 'count']) {
          if (map[subKey] != null) {
            final val = int.tryParse(map[subKey].toString());
            if (val != null && val > 0) return val;
          }
        }
        final durationStr = (map['duration'] ?? map['packageDuration'] ?? map['name'] ?? map['title'] ?? '').toString().toLowerCase();
        final fromDuration = _sessionsFromDurationString(durationStr);
        if (fromDuration > 0) return fromDuration;
      }
    }

    final durationStr = (data['packageDuration'] ?? data['duration'] ?? data['package'] ?? data['plan'] ?? data['packageName'] ?? data['subscriptionPlan'] ?? '').toString().toLowerCase();
    final fromDuration = _sessionsFromDurationString(durationStr);
    if (fromDuration > 0) return fromDuration;

    if (totalBookingsCount > 26) return totalBookingsCount;
    return 26;
  }



  Future<void> _fetchUsers({bool showSpinner = true, bool force = false}) async {
    if (showSpinner && _users.isEmpty) {
      setState(() => _loading = true);
    }

    try {
      final cache = TrainerDataService();
      if (!cache.isInitialized) {
        await cache.preloadAll(notify: false);
      } else if (force) {
        await cache.preloadAll(notify: false, force: true);
      } else {
        cache.preloadAll(notify: false, force: true).then((_) {
          if (mounted) _parseFromCache();
        });
      }
      _parseFromCache();
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _processDocs(
    Set<String> myTrainerIds,
    Set<String> myTrainerNames,
    Set<String> myTrainerEmails,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> usersDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allTrainersDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingsDocs,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    final strings = languageService.strings;

    // 1. Collect client IDs and calculate completed sessions from bookings & sessions
    final Set<String> bookedClientIds = {};
    final Map<String, int> clientCompletedCount = {};
    final Map<String, int> clientTotalBookingsCount = {};

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionResults = [];
    sessionResults.addAll(sessionsDocs);
    sessionResults.addAll(bookingsDocs);

    for (var doc in sessionResults) {
      final d = doc.data();
      final docTrainerId = (d['trainerId'] ?? d['assignedTrainerId'] ?? d['trainer_id'] ?? '').toString().trim();
      final docTrainerName = (d['trainerName'] ?? d['trainer'] ?? '').toString().toLowerCase().trim();
      final docTrainerEmail = (d['trainerEmail'] ?? d['email'] ?? '').toString().toLowerCase().trim();
      final cId = (d['clientId'] ?? d['userId'] ?? d['client_id'] ?? d['user_id'] ?? '').toString().trim();

      bool isMatch = false;
      if (docTrainerId.isNotEmpty && myTrainerIds.contains(docTrainerId)) {
        isMatch = true;
      } else if (docTrainerEmail.isNotEmpty && myTrainerEmails.contains(docTrainerEmail)) {
        isMatch = true;
      } else if (docTrainerName.isNotEmpty && myTrainerNames.any((n) => n.isNotEmpty && (docTrainerName == n || docTrainerName.contains(n) || n.contains(docTrainerName)))) {
        isMatch = true;
      } else if (allTrainersDocs.length == 1) {
        isMatch = true;
      }

      if (isMatch && cId.isNotEmpty && cId != uid) {
        bookedClientIds.add(cId);
        clientTotalBookingsCount[cId] = (clientTotalBookingsCount[cId] ?? 0) + 1;

        final status = (d['status'] ?? '').toString().toLowerCase().trim();
        if (status == 'completed' || status == 'done') {
          clientCompletedCount[cId] = (clientCompletedCount[cId] ?? 0) + 1;
        }
      }
    }

    // 2. Process all users and filter clients
    final List<_ClientData> loadedUsers = [];

    for (var doc in usersDocs) {
      final data = doc.data();
      if (doc.id == uid) continue;
      if (data['role'] == 'trainer' || data['role'] == 'admin') continue;

      final assignedId = (data['assignedTrainerId'] ?? data['trainerId'] ?? data['assignedTrainer'] ?? '').toString().trim();
      final assignedName = (data['assignedTrainerName'] ?? data['assignedTrainer'] ?? '').toString().toLowerCase().trim();

      bool isMyClient = false;
      if (assignedId.isNotEmpty && myTrainerIds.contains(assignedId)) {
        isMyClient = true;
      } else if (assignedName.isNotEmpty && myTrainerNames.any((n) => n.isNotEmpty && (assignedName == n || assignedName.contains(n) || n.contains(assignedName)))) {
        isMyClient = true;
      } else if (bookedClientIds.contains(doc.id)) {
        isMyClient = true;
      } else if (allTrainersDocs.length == 1) {
        isMyClient = true;
      }

      if (!isMyClient) continue;

        // Safely extract name
        final name = data['fullName']?.toString() ??
            data['name']?.toString() ??
            (strings['unknownClient'] ?? 'Unknown User');

        // Initials
        final parts = name.trim().split(' ');
        String initials = 'U';
        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          initials = parts.first[0];
          if (parts.length > 1 && parts.last.isNotEmpty) {
            initials += parts.last[0];
          }
        }

        // Details string
        final package = data['package']?.toString() ?? data['plan'] ?? 'Standard';
        final goal = data['goal']?.toString() ?? data['fitnessGoal'] ?? 'Fitness';
        final area = data['area']?.toString() ?? data['city'] ?? 'Location';
        final details = '$package · $goal · $area';

        // Calculate Package Total Sessions from package duration
        final totalBookings = clientTotalBookingsCount[doc.id] ?? 0;
        final totalPackageSessions = _calculatePackageTotalSessions(data, totalBookings);

        // Live completed sessions count
        int liveCompleted = clientCompletedCount[doc.id] ?? 0;
        int docCompleted = 0;
        if (data['completedSessions'] is num) {
          docCompleted = (data['completedSessions'] as num).toInt();
        } else if (data['completedCount'] is num) {
          docCompleted = (data['completedCount'] as num).toInt();
        }
        final completed = liveCompleted > docCompleted ? liveCompleted : docCompleted;

        int progress = 0;
        if (totalPackageSessions > 0) {
          progress = ((completed / totalPackageSessions) * 100).round();
          if (progress > 100) progress = 100;
        }

        // Medical warning
        String? medical = data['medicalWarning']?.toString() ??
            data['medicalCondition']?.toString();
        if (medical != null && medical.trim().isEmpty) {
          medical = null;
        }

        // Photo URL
        final photoUrl = data['photoURL']?.toString() ??
            data['photoUrl']?.toString() ??
            data['profileImage']?.toString() ??
            data['image']?.toString();

        loadedUsers.add(
          _ClientData(
            id: doc.id,
            name: name,
            initials: initials.toUpperCase(),
            details: details,
            completedSessions: completed,
            totalSessions: totalPackageSessions,
            progressPercent: progress,
            medicalWarning: medical,
            status: data['status']?.toString() ?? 'Active',
            photoUrl: photoUrl,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _users = loadedUsers;
          _filteredUsers = loadedUsers;
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
    super.build(context);
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
      bottomNavigationBar: widget.isEmbeddedInShell
          ? null
          : _BottomNav(
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: brandBlue,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? Image.network(
                          user.photoUrl!,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: brandBlue,
                            alignment: Alignment.center,
                            child: Text(
                              user.initials,
                              style: GoogleFonts.workSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          alignment: Alignment.center,
                          child: Text(
                            user.initials,
                            style: GoogleFonts.workSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.workSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor, // Dynamic Name
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings['sessions'] ?? 'Sessions',
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              Text(
                '${user.completedSessions} / ${user.totalSessions} (${user.progressPercent}%)',
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: subTextColor,
                ),
              ),
            ],
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
                    widthFactor: (user.progressPercent / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _TrainerUsersScreenState.primaryRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrainerUserProfileScreen(
                      clientId: user.id,
                    ),
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
