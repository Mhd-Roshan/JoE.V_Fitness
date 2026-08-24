import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'session_history_tab.dart';
import 'health_info_tab.dart';
import '../home/trainer_main_screen.dart';
import '../../services/language_service.dart';
import '../../services/trainer_data_service.dart';

class TrainerUserProfileScreen extends StatefulWidget {
  final String clientId;

  const TrainerUserProfileScreen({super.key, required this.clientId});

  @override
  State<TrainerUserProfileScreen> createState() =>
      _TrainerUserProfileScreenState();
}

class _TrainerUserProfileScreenState extends State<TrainerUserProfileScreen> {
  bool _loading = true;
  int _selectedTab = 0; // 0: Overview, 1: Sessions, 2: Health info
  String _activeFilterKey = 'allTime';

  // Fetched Data
  String _fullName = '—';
  String? _photoUrl;
  String _status = 'inactive';
  String _packageName = '—';
  double? _currentWeightKg;
  double? _startWeightKg;
  double? _heightCm;
  int? _dailySteps;
  double? _waterL;
  double? _sleepHours;
  int? _age;
  String _goal = '—';
  String _area = '—';
  int _totalSessions = 0;
  int _completedSessions = 0;

  // Semantic Colors (Stay the same across themes)
  static const Color cyanAccent = Color(0xFF01BCE3);
  static const Color greenText = Color(0xFF17CC1A);
  static const Color progressSteps = Color(0xFF01BCE3);
  static const Color progressWater = Color(0xFF2E51A2);
  static const Color progressSleep = Color(0xFFA932B2);

  @override
  void initState() {
    super.initState();
    _checkCache();
    _loadData();
  }

  void _checkCache() {
    final cached = TrainerDataService().getCachedClientProfile(widget.clientId);
    if (cached != null) {
      _fullName = cached['fullName'] ?? 'Client';
      _photoUrl = cached['photoUrl'];
      _status = cached['status'] ?? 'active';
      _packageName = cached['packageName'] ?? 'Standard';
      _currentWeightKg = cached['currentWeightKg'];
      _startWeightKg = cached['startWeightKg'];
      _heightCm = cached['heightCm'];
      _dailySteps = cached['dailySteps'];
      _waterL = cached['waterL'];
      _sleepHours = cached['sleepHours'];
      _age = cached['age'];
      _goal = cached['goal'] ?? '—';
      _area = cached['area'] ?? '—';
      _totalSessions = cached['totalSessions'] ?? 0;
      _completedSessions = cached['completedSessions'] ?? 0;
      _loading = false;
    }
  }

  static int _sessionsFromDurationString(String str) {
    if (str.isEmpty) return 26;
    final sessMatch = RegExp(r'(\d+)\s*(?:sessions?|class(?:es)?)', caseSensitive: false).firstMatch(str);
    if (sessMatch != null) {
      final s = int.tryParse(sessMatch.group(1) ?? '0') ?? 0;
      if (s > 0) return s;
    }

    if (str.contains('12 month') || str.contains('1 year') || str.contains('annual') || str.contains('12m') || str.contains('1y')) {
      return 312; // 12 months * 26 workout days (all Sundays rest)
    }
    if (str.contains('6 month') || str.contains('6m') || str.contains('half year')) {
      return 156; // 6 months * 26 workout days (all Sundays rest)
    }
    if (str.contains('3 month') || str.contains('3m') || str.contains('quarter')) {
      return 78; // 3 months * 26 workout days (all Sundays rest)
    }
    if (str.contains('2 month') || str.contains('2m')) {
      return 52; // 2 months * 26 workout days (all Sundays rest)
    }
    if (str.contains('1 month') || str.contains('1m') || str.contains('monthly') || str.contains('standard')) {
      return 26; // 1 month * 26 workout days (all Sundays rest)
    }
    if (str.contains('month')) {
      final mMatch = RegExp(r'(\d+)\s*month').firstMatch(str);
      final months = int.tryParse(mMatch?.group(1) ?? '1') ?? 1;
      return months * 26;
    }
    if (str.contains('day')) {
      final dMatch = RegExp(r'(\d+)\s*day').firstMatch(str);
      final days = int.tryParse(dMatch?.group(1) ?? '30') ?? 30;
      final sundays = (days / 7).floor();
      return days - sundays;
    }
    if (str.contains('week')) {
      final wMatch = RegExp(r'(\d+)\s*week').firstMatch(str);
      final weeks = int.tryParse(wMatch?.group(1) ?? '1') ?? 1;
      return weeks * 6; // 6 workout days per week (Sunday rest)
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

  double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final cleaned = val.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned);
    }
    if (val is Map && val.isNotEmpty) {
      return _toDouble(val.values.last);
    }
    return null;
  }

  int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final cleaned = val.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned);
    }
    if (val is Map && val.isNotEmpty) {
      return _toInt(val.values.last);
    }
    return null;
  }

  double? _extractWeight(
    Map<String, dynamic> p,
    Map<String, dynamic> h,
    Map<String, dynamic> u,
    Map<String, dynamic> prof,
  ) {
    for (final source in [p, h, u, prof]) {
      for (final key in [
        'weight',
        'weightKg',
        'currentWeight',
        'currentWeightKg',
        'weight_kg',
      ]) {
        final val = _toDouble(source[key]);
        if (val != null && val > 0) return val;
      }
    }
    if (u['dailyWeight'] is Map && (u['dailyWeight'] as Map).isNotEmpty) {
      final map = u['dailyWeight'] as Map;
      final val = _toDouble(map.values.last);
      if (val != null && val > 0) return val;
    }
    return null;
  }

  double? _extractWater(
    Map<String, dynamic> p,
    Map<String, dynamic> h,
    Map<String, dynamic> u,
  ) {
    for (final source in [p, h, u]) {
      for (final key in [
        'water',
        'waterL',
        'water_l',
        'hydration',
        'dailyWater',
        'waterIntake',
        'currentWater',
      ]) {
        final val = _toDouble(source[key]);
        if (val != null && val > 0) {
          if (val > 20) return double.parse((val / 1000.0).toStringAsFixed(1));
          return double.parse(val.toStringAsFixed(1));
        }
      }
    }
    if (u['dailyHydration'] is Map && (u['dailyHydration'] as Map).isNotEmpty) {
      final map = u['dailyHydration'] as Map;
      final val = _toDouble(map.values.last);
      if (val != null && val > 0) {
        if (val > 20) return double.parse((val / 1000.0).toStringAsFixed(1));
        return double.parse(val.toStringAsFixed(1));
      }
    }
    return null;
  }

  int? _extractSteps(
    Map<String, dynamic> p,
    Map<String, dynamic> h,
    Map<String, dynamic> u,
  ) {
    for (final source in [p, h, u]) {
      for (final key in ['steps', 'dailySteps', 'stepCount', 'stepsGoal']) {
        final val = _toInt(source[key]);
        if (val != null && val > 0) return val;
      }
    }
    if (u['dailySteps'] is Map && (u['dailySteps'] as Map).isNotEmpty) {
      final map = u['dailySteps'] as Map;
      final val = _toInt(map.values.last);
      if (val != null && val > 0) return val;
    }
    return null;
  }

  double? _extractSleep(
    Map<String, dynamic> p,
    Map<String, dynamic> h,
    Map<String, dynamic> u,
  ) {
    for (final source in [p, h, u]) {
      for (final key in ['sleep', 'sleepHours', 'dailySleep', 'sleep_hours']) {
        final val = _toDouble(source[key]);
        if (val != null && val > 0) return double.parse(val.toStringAsFixed(1));
      }
    }
    if (u['dailySleep'] is Map && (u['dailySleep'] as Map).isNotEmpty) {
      final map = u['dailySleep'] as Map;
      final val = _toDouble(map.values.last);
      if (val != null && val > 0) return double.parse(val.toStringAsFixed(1));
    }
    return null;
  }

  String _extractArea(
    Map<String, dynamic> prof,
    Map<String, dynamic> u,
    String? fallbackArea,
  ) {
    for (final source in [prof, u]) {
      for (final key in [
        'area',
        'location',
        'city',
        'address',
        'preferredLocation',
        'gymLocation',
        'place',
      ]) {
        final val = source[key];
        if (val is String && val.trim().isNotEmpty && val != '—') {
          return val.trim();
        } else if (val is Map) {
          final title = val['title'] ?? val['address'] ?? val['city'] ?? val['area'];
          if (title != null && title.toString().trim().isNotEmpty) {
            return title.toString().trim();
          }
        }
      }
    }
    if (fallbackArea != null && fallbackArea.trim().isNotEmpty && fallbackArea != '—') {
      return fallbackArea.trim();
    }
    return 'Location';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _safeDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get();
    } catch (e) {
      debugPrint('SafeDoc fetch error on ${ref.path}: $e');
      return null;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _safeQuery(
    Future<QuerySnapshot<Map<String, dynamic>>> query,
  ) async {
    try {
      return await query;
    } catch (e) {
      debugPrint('SafeQuery fetch error: $e');
      return null;
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.clientId);

      final snaps = await Future.wait([
        _safeDoc(userRef),
        _safeDoc(userRef.collection('profile').doc('general')),
        _safeDoc(userRef.collection('subscription').doc('current')),
        _safeQuery(userRef.collection('progress').get()),
        _safeQuery(userRef.collection('progress_history').get()),
        _safeQuery(FirebaseFirestore.instance.collection('sessions').where('clientId', isEqualTo: widget.clientId).get()),
        _safeQuery(FirebaseFirestore.instance.collection('sessions').where('userId', isEqualTo: widget.clientId).get()),
        _safeQuery(FirebaseFirestore.instance.collection('bookings').where('clientId', isEqualTo: widget.clientId).get()),
        _safeQuery(FirebaseFirestore.instance.collection('bookings').where('userId', isEqualTo: widget.clientId).get()),
      ]);

      final userDoc = snaps[0] as DocumentSnapshot<Map<String, dynamic>>?;
      final profileDoc = snaps[1] as DocumentSnapshot<Map<String, dynamic>>?;
      final subDoc = snaps[2] as DocumentSnapshot<Map<String, dynamic>>?;
      final progressSnap = snaps[3] as QuerySnapshot<Map<String, dynamic>>?;
      final histSnap = snaps[4] as QuerySnapshot<Map<String, dynamic>>?;

      final userData = userDoc?.data() ?? {};
      final profileData = profileDoc?.data() ?? {};
      final subData = subDoc?.data() ?? {};

      final latestProgress = (progressSnap != null && progressSnap.docs.isNotEmpty)
          ? progressSnap.docs.last.data()
          : <String, dynamic>{};

      final latestHistory = (histSnap != null && histSnap.docs.isNotEmpty)
          ? histSnap.docs.last.data()
          : <String, dynamic>{};

      // Multi-collection session query
      final Set<String> uniqueSessionIds = {};
      int completedSessionsCount = 0;
      String? fallbackBookingArea;

      try {
        final List<QuerySnapshot<Map<String, dynamic>>> sessionsResults = [];
        for (int i = 5; i <= 8; i++) {
          if (snaps[i] != null) {
            sessionsResults.add(snaps[i] as QuerySnapshot<Map<String, dynamic>>);
          }
        }

        for (var snap in sessionsResults) {
          for (var doc in snap.docs) {
            final data = doc.data();
            final uniqueKey = data['bookingId'] ?? data['sessionId'] ?? doc.id;
            if (uniqueSessionIds.contains(uniqueKey)) continue;
            uniqueSessionIds.add(uniqueKey);

            if (fallbackBookingArea == null) {
              if (data['area'] != null && data['area'].toString().isNotEmpty) {
                fallbackBookingArea = data['area'].toString();
              } else if (data['location'] != null && data['location'].toString().isNotEmpty) {
                fallbackBookingArea = data['location'] is Map
                    ? (data['location']['title'] ?? data['location']['address'] ?? data['location']['city'])?.toString()
                    : data['location'].toString();
              }
            }

            final status = (data['status'] ?? '').toString().toLowerCase().trim();
            if (status == 'completed' || status == 'done') {
              completedSessionsCount++;
            }
          }
        }
      } catch (e) {
        debugPrint('Sessions count fetch error: $e');
      }

      int? age;
      final dobStr = profileData['dob'] as String? ?? userData['dob'] as String?;
      if (dobStr != null) {
        final dob = DateTime.tryParse(dobStr);
        if (dob != null) {
          final now = DateTime.now();
          age = now.year - dob.year;
          if (now.month < dob.month ||
              (now.month == dob.month && now.day < dob.day)) {
            age -= 1;
          }
        }
      }

      final parsedWeight = _extractWeight(latestProgress, latestHistory, userData, profileData);
      final parsedStartWeight = _toDouble(profileData['startWeightKg']) ??
          _toDouble(userData['startWeight']) ??
          _toDouble(userData['startWeightKg']) ??
          _toDouble(userData['initialWeight']) ??
          _toDouble(userData['weight']) ??
          parsedWeight;

      final parsedHeight = _toDouble(profileData['heightCm']) ??
          _toDouble(profileData['startHeightCm']) ??
          _toDouble(userData['height']) ??
          _toDouble(userData['heightCm']);

      final parsedSteps = _extractSteps(latestProgress, latestHistory, userData);
      final parsedWater = _extractWater(latestProgress, latestHistory, userData);
      final parsedSleep = _extractSleep(latestProgress, latestHistory, userData);
      final parsedAge = age ?? _toInt(userData['age']);

      final parsedGoal = profileData['primaryGoal']?.toString() ??
          profileData['goal']?.toString() ??
          userData['goal']?.toString() ??
          userData['fitnessGoal']?.toString() ??
          userData['primaryGoal']?.toString() ??
          'Fitness';

      final parsedArea = _extractArea(profileData, userData, fallbackBookingArea);

      final parsedPackage = subData['packageName']?.toString() ??
          userData['package']?.toString() ??
          userData['plan']?.toString() ??
          userData['membership']?.toString() ??
          'Standard';

      final parsedStatus = subData['status']?.toString() ??
          userData['status']?.toString() ??
          'active';

      int docCompleted = 0;
      if (userData['completedSessions'] is num) {
        docCompleted = (userData['completedSessions'] as num).toInt();
      }
      final finalCompleted = completedSessionsCount > docCompleted ? completedSessionsCount : docCompleted;
      final finalTotal = _calculatePackageTotalSessions(userData, uniqueSessionIds.length);

      if (!mounted) return;

      TrainerDataService().cacheClientProfile(widget.clientId, {
        'fullName': userData['fullName']?.toString() ??
            userData['name']?.toString() ??
            userData['displayName']?.toString() ??
            'Client',
        'photoUrl': userData['photoURL']?.toString() ??
            userData['photoUrl']?.toString() ??
            userData['profileImage']?.toString(),
        'status': parsedStatus.toLowerCase(),
        'packageName': parsedPackage,
        'currentWeightKg': parsedWeight,
        'startWeightKg': parsedStartWeight,
        'heightCm': parsedHeight,
        'dailySteps': parsedSteps,
        'waterL': parsedWater,
        'sleepHours': parsedSleep,
        'age': parsedAge,
        'goal': parsedGoal,
        'area': parsedArea,
        'totalSessions': finalTotal,
        'completedSessions': finalCompleted,
      });

      setState(() {
        _fullName = userData['fullName']?.toString() ??
            userData['name']?.toString() ??
            userData['displayName']?.toString() ??
            'Client';
        _photoUrl = userData['photoURL']?.toString() ??
            userData['photoUrl']?.toString() ??
            userData['profileImage']?.toString();
        _status = parsedStatus.toLowerCase();
        _packageName = parsedPackage;
        _currentWeightKg = parsedWeight;
        _startWeightKg = parsedStartWeight;
        _heightCm = parsedHeight;
        _dailySteps = parsedSteps;
        _waterL = parsedWater;
        _sleepHours = parsedSleep;
        _age = parsedAge;
        _goal = parsedGoal;
        _area = parsedArea;
        _totalSessions = finalTotal;
        _completedSessions = finalCompleted;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Client profile load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- FILTER UI BOTTOM SHEET ---
  void _showFilterOptions(Map<String, String> strings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(
        context,
      ).cardColor, // Dynamic Bottom Sheet Color
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings['filterDataBy'] ?? 'Filter Data By',
                style: GoogleFonts.workSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Divider(color: Theme.of(context).dividerColor),
              _filterTile('allTime', strings['allTime'] ?? 'All Time'),
              _filterTile('last7Days', strings['last7Days'] ?? 'Last 7 Days'),
              _filterTile(
                'last30Days',
                strings['last30Days'] ?? 'Last 30 Days',
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _filterTile(String filterKey, String displayName) {
    bool isSelected = _activeFilterKey == filterKey;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? cyanAccent : subTextColor,
      ),
      title: Text(
        displayName,
        style: GoogleFonts.workSans(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: textColor,
        ),
      ),
      onTap: () {
        setState(() => _activeFilterKey = filterKey);
        Navigator.pop(context);
        _loadData();
      },
    );
  }

  // Helpers
  String get _initials {
    final parts = _fullName.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '—';
    final first = parts.first[0];
    final second = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last[0]
        : '';
    return (first + second).toUpperCase();
  }

  String _fmt(double? val) => val == null
      ? '—'
      : (val == val.toInt() ? val.toInt().toString() : val.toStringAsFixed(1));

  double get _stepPercent => ((_dailySteps ?? 0) / 10000).clamp(0.0, 1.0);
  double get _waterPercent => ((_waterL ?? 0) / 4.0).clamp(0.0, 1.0);
  double get _sleepPercent => ((_sleepHours ?? 0) / 8.0).clamp(0.0, 1.0);
  double get _sessionPercent => _totalSessions > 0
      ? (_completedSessions / _totalSessions).clamp(0.0, 1.0)
      : 0.0;

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: _BottomNav(
        currentIndex: 2, // Index 2 is Users
        strings: strings,
      ),
      body: Column(
        children: [
          const _TopHeaderBand(),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: brandBlue))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: cyanAccent,
                    backgroundColor: cardColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // Back Button, Title & FILTER BUTTON
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: textColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  strings['userProfile'] ?? 'User Profile',
                                  style: GoogleFonts.workSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _showFilterOptions(strings),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: dividerColor),
                                    ),
                                    child: Icon(
                                      Icons.tune_rounded,
                                      color: textColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Profile Avatar
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: brandBlue,
                                    width: 3,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      _photoUrl != null && _photoUrl!.isNotEmpty
                                      ? Image.network(
                                          _photoUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: dividerColor,
                                          alignment: Alignment.center,
                                          child: Text(
                                            _initials,
                                            style: GoogleFonts.workSans(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              // Status Dot
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color:
                                        cardColor, // Frame matches background
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: bgColor,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _status == 'active'
                                          ? cyanAccent
                                          : subTextColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Name
                          Text(
                            _fullName,
                            style: GoogleFonts.workSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Status & Package
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.workSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              children: [
                                TextSpan(
                                  text: _status == 'active'
                                      ? (strings['activeNow'] ?? 'ACTIVE NOW')
                                      : _status.toUpperCase(),
                                  style: TextStyle(
                                    color: _status == 'active'
                                        ? greenText
                                        : subTextColor,
                                  ),
                                ),
                                TextSpan(
                                  text: '  •  ',
                                  style: TextStyle(color: subTextColor),
                                ),
                                TextSpan(
                                  text: _packageName,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          // Tag showing the active filter
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${strings['showing'] ?? 'Showing:'} ${strings[_activeFilterKey] ?? 'Filter'}",
                              style: GoogleFonts.workSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cyanAccent,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Stats Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    title: strings['weightCaps'] ?? 'WEIGHT',
                                    value: _fmt(_currentWeightKg),
                                    unit: 'kg',
                                    isHighlighted: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    title: strings['heightCaps'] ?? 'HEIGHT',
                                    value: _fmt(_heightCm),
                                    unit: 'cm',
                                    isHighlighted: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    title:
                                        strings['sessions']?.toUpperCase() ??
                                        'SESSIONS',
                                    value: '$_completedSessions/$_totalSessions',
                                    unit: strings['completedWord'] ?? 'Completed',
                                    isHighlighted: false,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Tab Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: dividerColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _TabButton(
                                      label: strings['overview'] ?? 'Overview',
                                      isSelected: _selectedTab == 0,
                                      onTap: () =>
                                          setState(() => _selectedTab = 0),
                                    ),
                                  ),
                                  Expanded(
                                    child: _TabButton(
                                      label: strings['sessions'] ?? 'Sessions',
                                      isSelected: _selectedTab == 1,
                                      onTap: () =>
                                          setState(() => _selectedTab = 1),
                                    ),
                                  ),
                                  Expanded(
                                    child: _TabButton(
                                      label:
                                          strings['healthInfo'] ??
                                          'Health info',
                                      isSelected: _selectedTab == 2,
                                      onTap: () =>
                                          setState(() => _selectedTab = 2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Tab Content (IndexedStack preserves state for buttery smooth zero-lag switching)
                          IndexedStack(
                            index: _selectedTab,
                            children: [
                              _buildOverviewTab(strings),
                              SessionHistoryTab(clientId: widget.clientId),
                              HealthInfoTab(clientId: widget.clientId),
                            ],
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

  Widget _buildOverviewTab(Map<String, String> strings) {
    final weightDelta = (_currentWeightKg != null && _startWeightKg != null)
        ? _currentWeightKg! - _startWeightKg!
        : null;

    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // PROGRESS CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings['progress'] ?? 'Progress',
                  style: GoogleFonts.workSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Weight Progress Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        strings['weight'] ?? 'Weight',
                        style: GoogleFonts.workSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: subTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            color: textColor,
                          ),
                          children: [
                            TextSpan(
                              text: '${_fmt(_currentWeightKg)}kg ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_startWeightKg != null)
                              TextSpan(
                                text:
                                    '(${strings['startWord'] ?? 'start'} ${_fmt(_startWeightKg)} kg)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: subTextColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        weightDelta == null || weightDelta == 0
                            ? '—'
                            : (weightDelta > 0
                                  ? '⬆ ${_fmt(weightDelta.abs())} kg'
                                  : '⬇ ${_fmt(weightDelta.abs())} kg'),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: (weightDelta != null && weightDelta <= 0)
                              ? greenText
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _ProgressBarRow(
                  label: strings['dailySteps'] ?? 'Daily steps',
                  value: _dailySteps != null ? '$_dailySteps' : '—',
                  percent: _stepPercent,
                  color: progressSteps,
                ),
                const SizedBox(height: 16),
                _ProgressBarRow(
                  label: strings['waterL'] ?? 'Water (L)',
                  value: _waterL != null ? '${_fmt(_waterL)}L' : '—',
                  percent: _waterPercent,
                  color: progressWater,
                ),
                const SizedBox(height: 16),
                _ProgressBarRow(
                  label: strings['sleepH'] ?? 'Sleep (H)',
                  value: _sleepHours != null ? '${_fmt(_sleepHours)}h' : '—',
                  percent: _sleepPercent,
                  color: progressSleep,
                ),
                const SizedBox(height: 16),
                _ProgressBarRow(
                  label: strings['sessions'] ?? 'Workout Sessions',
                  value: '$_completedSessions / $_totalSessions',
                  percent: _sessionPercent,
                  color: cyanAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // DETAILS CARD
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor, width: 1.5),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: strings['age'] ?? 'Age',
                  value: _age != null
                      ? '$_age ${strings['yrs'] ?? 'yrs'}'
                      : '—',
                ),
                _DetailRow(
                  label: strings['weight'] ?? 'Weight',
                  value: _currentWeightKg != null
                      ? '${_fmt(_currentWeightKg)}\nkg'
                      : '—',
                  multiLineValue: true,
                ),
                _DetailRow(
                  label: strings['startWeight'] ?? 'Start weight',
                  value: _startWeightKg != null
                      ? '${_fmt(_startWeightKg)} kg'
                      : '—',
                ),
                _DetailRow(
                  label: strings['startHeight'] ?? 'Start height',
                  value: _heightCm != null ? '${_fmt(_heightCm)} cm' : '—',
                ),
                _DetailRow(label: strings['goal'] ?? 'Goal', value: _goal),
                _DetailRow(
                  label: strings['area'] ?? 'Area',
                  value: _area,
                  hideBorder: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// COMPONENT WIDGETS
// ---------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.isHighlighted,
  });
  final String title;
  final String value;
  final String unit;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Smart colors for Dark and Light mode
    Color bg = isHighlighted
        ? (isDark
              ? const Color(0xFF01BCE3).withValues(alpha: 0.15)
              : const Color(0xFFA5C4F2))
        : (isDark ? Theme.of(context).cardColor : const Color(0xFF00225D));

    Color border = isHighlighted
        ? Colors.transparent
        : (isDark ? Theme.of(context).dividerColor : Colors.transparent);

    Color textCol = isHighlighted
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white;

    Color subTextCol = isHighlighted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: (isHighlighted || isDark)
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.workSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: subTextCol,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.workSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textCol,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              unit,
              style: GoogleFonts.workSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: subTextCol,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // Light Blue color for selected sliding tab box
    final lightBlueBg = isDark
        ? const Color(0xFF01BCE3).withValues(alpha: 0.25)
        : const Color(0xFFBAE6FD); // Light blue

    final selectedTextColor = isDark
        ? const Color(0xFF01BCE3)
        : const Color(0xFF00225D); // High-contrast navy on light blue

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? lightBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: isDark
                      ? const Color(0xFF01BCE3).withValues(alpha: 0.5)
                      : const Color(0xFF7DD3FC),
                  width: 1,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark
                            ? const Color(0xFF01BCE3)
                            : const Color(0xFF38BDF8))
                        .withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            color: isSelected ? selectedTextColor : subTextColor,
          ),
        ),
      ),
    );
  }
}

class _ProgressBarRow extends StatelessWidget {
  const _ProgressBarRow({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });
  final String label;
  final String value;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: GoogleFonts.workSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.workSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.hideBorder = false,
    this.multiLineValue = false,
  });
  final String label;
  final String value;
  final bool hideBorder;
  final bool multiLineValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: hideBorder
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1.5,
                ),
              ),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: multiLineValue
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.workSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.workSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              height: multiLineValue ? 1.2 : 1,
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
            child: Image.asset(
              'assets/images/landing_photo.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
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
                color: Colors.white, // Always white on header
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
        color: Theme.of(context).primaryColor, // Dynamic Footer Color
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
