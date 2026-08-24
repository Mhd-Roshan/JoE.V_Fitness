import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../users/client_profile_screen.dart';
import '../notifications/trainer_notifications_screen.dart';
import '../home/trainer_home_screen.dart';

import '../../services/language_service.dart';
import '../home/trainer_main_screen.dart';

import '../../services/trainer_data_service.dart';

class TrainerSchedulesScreen extends StatefulWidget {
  final bool isEmbeddedInShell;
  const TrainerSchedulesScreen({super.key, this.isEmbeddedInShell = false});

  @override
  State<TrainerSchedulesScreen> createState() => _TrainerSchedulesScreenState();
}

class _ScheduleSession {
  final String id;
  final String clientId;
  final String clientName;
  final String serviceType;
  final String time;
  final String amPm;
  final String area;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime? scheduledDateTime;
  String status;
  final String? notes;
  final dynamic rawDate;

  _ScheduleSession({
    required this.id,
    this.clientId = '',
    required this.clientName,
    required this.serviceType,
    required this.time,
    required this.amPm,
    required this.area,
    this.latitude,
    this.longitude,
    this.address,
    this.scheduledDateTime,
    required this.status,
    this.notes,
    this.rawDate,
  });

  /// Only visible/markable on the current scheduled date & time (with a 15-minute buffer before start)
  bool get canMarkDone {
    if (scheduledDateTime == null) return true;
    final now = DateTime.now();
    return now.isAfter(scheduledDateTime!.subtract(const Duration(minutes: 15)));
  }
}

class _TrainerSchedulesScreenState extends State<TrainerSchedulesScreen>
    with AutomaticKeepAliveClientMixin {
  late DateTime _selectedDate;
  late List<DateTime> _scrollableDates;
  late ScrollController _scrollController;

  bool _loading = true;
  List<_ScheduleSession> _allSessions = [];
  List<_ScheduleSession> _sessions = [];

  final int _pastDays = 90;
  final int _futureDays = 90;

  static const Color primaryRed = Color(0xFFC7001A);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _scrollableDates = _buildDateRange(_selectedDate);
    _scrollController = ScrollController();

    if (TrainerDataService().isInitialized) {
      _parseFromCache();
      _loadSessions(showSpinner: false);
    } else {
      _loadSessions(showSpinner: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDateCenter(_selectedDate, animate: false);
    });
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
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> _buildDateRange(DateTime baseDate) {
    return List.generate(_pastDays + _futureDays + 1, (index) {
      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day + (index - _pastDays),
      );
    });
  }

  void _scrollToDateCenter(DateTime date, {bool animate = true}) {
    if (!_scrollController.hasClients) {
      return;
    }

    final index = _scrollableDates.indexWhere((d) => _isSameDay(d, date));
    if (index == -1) {
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    const itemWidth = 65.0;
    const spacing = 12.0;
    const leftPadding = 24.0;

    final offset =
        leftPadding +
        (index * (itemWidth + spacing)) -
        (screenWidth / 2) +
        (itemWidth / 2);
    final clampedOffset = offset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(clampedOffset);
    }
  }

  void _filterSessionsForSelectedDate() {
    _sessions = _allSessions
        .where((s) => _isSameDayDate(s.rawDate, _selectedDate))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _filterSessionsForSelectedDate();
    });
    _scrollToDateCenter(date, animate: true);
  }

  String _getWeekdayLabel(int weekday, Map<String, String> strings) {
    final labels = [
      strings['mon'] ?? 'MON',
      strings['tue'] ?? 'TUE',
      strings['wed'] ?? 'WED',
      strings['thu'] ?? 'THU',
      strings['fri'] ?? 'FRI',
      strings['sat'] ?? 'SAT',
      strings['sun'] ?? 'SUN',
    ];
    return labels[weekday - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- ROBUST DATE MATCHER (HANDLES ISO, DD-MM-YYYY, TEXT MONTHS, AND TIMESTAMPS) ---
  bool _isSameDayDate(dynamic rawDate, DateTime targetDate) {
    if (rawDate == null) {
      return false;
    }
    DateTime? d;
    if (rawDate is Timestamp) {
      d = rawDate.toDate();
    } else if (rawDate is DateTime) {
      d = rawDate;
    } else if (rawDate is num) {
      int val = rawDate.toInt();
      if (val < 10000000000) {
        val *= 1000;
      }
      d = DateTime.fromMillisecondsSinceEpoch(val);
    } else if (rawDate is String) {
      String s = rawDate.trim();
      if (s.isEmpty) return false;

      // Check YYYY-MM-DD or YYYY/MM/DD
      final isoRegex = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})');
      final isoMatch = isoRegex.firstMatch(s);
      if (isoMatch != null) {
        int y = int.parse(isoMatch.group(1)!);
        int m = int.parse(isoMatch.group(2)!);
        int day = int.parse(isoMatch.group(3)!);
        return y == targetDate.year &&
            m == targetDate.month &&
            day == targetDate.day;
      }

      // Check DD-MM-YYYY or DD/MM/YYYY
      final dmyRegex = RegExp(r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})');
      final dmyMatch = dmyRegex.firstMatch(s);
      if (dmyMatch != null) {
        int p1 = int.parse(dmyMatch.group(1)!);
        int p2 = int.parse(dmyMatch.group(2)!);
        int y = int.parse(dmyMatch.group(3)!);
        if (y == targetDate.year) {
          if ((p1 == targetDate.day && p2 == targetDate.month) ||
              (p2 == targetDate.day && p1 == targetDate.month)) {
            return true;
          }
        }
      }

      d = DateTime.tryParse(s);
      if (d == null) {
        final months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
          'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
          'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
        };

        String lower = s.toLowerCase();
        for (var entry in months.entries) {
          if (lower.contains(entry.key)) {
            final numbers = RegExp(r'\d+').allMatches(s).map((m) => int.parse(m.group(0)!)).toList();
            if (numbers.isNotEmpty) {
              int year = numbers.firstWhere((n) => n >= 1900 && n <= 2100, orElse: () => targetDate.year);
              int day = numbers.firstWhere((n) => n <= 31 && n != year, orElse: () => -1);
              if (day != -1) {
                d = DateTime(year, entry.value, day);
                break;
              }
            }
          }
        }
      }
    }
    if (d == null) {
      return false;
    }
    return d.year == targetDate.year &&
        d.month == targetDate.month &&
        d.day == targetDate.day;
  }

  String _formatFullDate(DateTime d, Map<String, String> strings) {
    final days = [
      strings['monday'] ?? 'Monday',
      strings['tuesday'] ?? 'Tuesday',
      strings['wednesday'] ?? 'Wednesday',
      strings['thursday'] ?? 'Thursday',
      strings['friday'] ?? 'Friday',
      strings['saturday'] ?? 'Saturday',
      strings['sunday'] ?? 'Sunday',
    ];
    final months = [
      strings['january'] ?? 'January',
      strings['february'] ?? 'February',
      strings['march'] ?? 'March',
      strings['april'] ?? 'April',
      strings['may'] ?? 'May',
      strings['june'] ?? 'June',
      strings['july'] ?? 'July',
      strings['august'] ?? 'August',
      strings['september'] ?? 'September',
      strings['october'] ?? 'October',
      strings['november'] ?? 'November',
      strings['december'] ?? 'December',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }



  Future<void> _loadSessions({bool showSpinner = true, bool force = false}) async {
    if (showSpinner && _allSessions.isEmpty) {
      if (mounted) setState(() => _loading = true);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _allSessions = [];
          _sessions = [];
          _loading = false;
        });
      }
      return;
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
      debugPrint('Schedules load error: $e');
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clientsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allTrainersDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingsDocs,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    final Map<String, String> clientToTrainerMap = {};
    final Map<String, String> clientNamesMap = {};
    final Map<String, Map<String, dynamic>> clientLocationsMap = {};
    for (var doc in clientsDocs) {
      final data = doc.data();
      if (data['role'] != 'trainer') {
        final assignedId =
            data['assignedTrainerId'] ?? data['trainerId'] ?? data['assignedTrainer'] ?? '';
        if (assignedId.toString().isNotEmpty) {
          clientToTrainerMap[doc.id] = assignedId.toString().trim();
        }
        final cName = data['fullName'] ?? data['name'] ?? '';
        if (cName.toString().isNotEmpty) {
          clientNamesMap[doc.id] = cName.toString().trim();
        }

        double? cLat = (data['latitude'] ?? data['lat']) is num
            ? (data['latitude'] ?? data['lat']).toDouble()
            : null;
        double? cLng = (data['longitude'] ?? data['lng']) is num
            ? (data['longitude'] ?? data['lng']).toDouble()
            : null;
        if (data['location'] is Map) {
          final loc = data['location'] as Map;
          if (loc['latitude'] is num) cLat = loc['latitude'].toDouble();
          if (loc['lat'] is num) cLat = loc['lat'].toDouble();
          if (loc['longitude'] is num) cLng = loc['longitude'].toDouble();
          if (loc['lng'] is num) cLng = loc['lng'].toDouble();
        }
        String cAddress = data['address']?.toString() ??
            data['locationAddress']?.toString() ??
            data['area']?.toString() ??
            '';
        clientLocationsMap[doc.id] = {
          'lat': cLat,
          'lng': cLng,
          'address': cAddress,
        };
      }
    }

    final strings = languageService.strings;
    final Map<String, _ScheduleSession> sessionMap = {};

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs = [];
    activeDocs.addAll(sessionsDocs);
    activeDocs.addAll(bookingsDocs);

    for (var doc in activeDocs) {
      final data = doc.data();
      final docTrainerId = (data['trainerId'] ??
              data['assignedTrainerId'] ??
              data['assignedTrainer'] ??
              data['trainer_id'] ??
              '')
          .toString()
          .trim();
      final docTrainerName = (data['trainerName'] ??
              data['trainer'] ??
              data['assignedTrainerName'] ??
              data['trainer_name'] ??
              '')
          .toString()
          .toLowerCase()
          .trim();
      final docTrainerEmail = (data['trainerEmail'] ??
              data['trainer_email'] ??
              data['email'] ??
              '')
          .toString()
          .toLowerCase()
          .trim();
      final clientId = (data['clientId'] ??
              data['userId'] ??
              data['client_id'] ??
              data['user_id'] ??
              '')
          .toString()
          .trim();

      // Check if this booking belongs to this trainer
      bool isTrainerMatch = false;
      if (docTrainerId.isNotEmpty && myTrainerIds.contains(docTrainerId)) {
        isTrainerMatch = true;
      } else if (docTrainerEmail.isNotEmpty &&
          myTrainerEmails.contains(docTrainerEmail)) {
        isTrainerMatch = true;
      } else if (docTrainerName.isNotEmpty &&
          myTrainerNames.any((n) =>
              n.isNotEmpty &&
              (docTrainerName == n ||
                  docTrainerName.contains(n) ||
                  n.contains(docTrainerName)))) {
        isTrainerMatch = true;
      } else if (clientId.isNotEmpty) {
        final clientAssignedTrainer = clientToTrainerMap[clientId] ?? '';
        if (clientAssignedTrainer.isNotEmpty &&
            myTrainerIds.contains(clientAssignedTrainer)) {
          isTrainerMatch = true;
        } else if (docTrainerId.isEmpty && docTrainerName.isEmpty && clientId != uid) {
          isTrainerMatch = true;
        }
      } else if (docTrainerId.isEmpty && docTrainerName.isEmpty) {
        isTrainerMatch = true;
      } else if (allTrainersDocs.length == 1) {
        isTrainerMatch = true;
      }

      if (!isTrainerMatch) {
        continue;
      }

      final rawDate = data['scheduledDate'] ??
          data['date'] ??
          data['sessionDate'] ??
          data['bookingDate'] ??
          data['selectedDate'] ??
          data['scheduled_date'] ??
          data['session_date'] ??
          data['scheduledDateTime'] ??
          data['dateTime'] ??
          data['createdAt'] ??
          data['timestamp'];

      // Parse Time accurately (checks startTime, time, or scheduledTime)
      String rawTime = data['startTime']?.toString().trim() ??
          data['time']?.toString().trim() ??
          data['scheduledTime']?.toString().trim() ??
          data['sessionTime']?.toString().trim() ??
          data['start_time']?.toString().trim() ??
          '08:00 AM';

      List<String> timeParts = rawTime.split(' ');
      String parsedTime = timeParts.isNotEmpty ? timeParts[0] : '08:00';
      String parsedAmPm = timeParts.length > 1
          ? timeParts[1].toUpperCase()
          : 'AM';

      // Location extraction
      String area = 'Location';
      double? lat;
      double? lng;
      String? address;

      if (data['latitude'] is num) lat = (data['latitude'] as num).toDouble();
      if (data['lat'] is num) lat = (data['lat'] as num).toDouble();
      if (data['longitude'] is num) lng = (data['longitude'] as num).toDouble();
      if (data['lng'] is num) lng = (data['lng'] as num).toDouble();
      if (data['geoPoint'] is GeoPoint) {
        lat = (data['geoPoint'] as GeoPoint).latitude;
        lng = (data['geoPoint'] as GeoPoint).longitude;
      }

      if (data['location'] is Map) {
        final locMap = data['location'] as Map;
        area = locMap['title']?.toString() ??
            locMap['address']?.toString() ??
            locMap['city']?.toString() ??
            locMap['area']?.toString() ??
            'Location';
        if (locMap['latitude'] is num) lat = (locMap['latitude'] as num).toDouble();
        if (locMap['lat'] is num) lat = (locMap['lat'] as num).toDouble();
        if (locMap['longitude'] is num) lng = (locMap['longitude'] as num).toDouble();
        if (locMap['lng'] is num) lng = (locMap['lng'] as num).toDouble();
        address = locMap['address']?.toString() ??
            locMap['street']?.toString() ??
            locMap['title']?.toString();
      } else if (data['area'] != null &&
          data['area'].toString().isNotEmpty) {
        area = data['area'].toString();
      } else if (data['location'] != null &&
          data['location'].toString().isNotEmpty) {
        area = data['location'].toString();
      }

      if (lat == null &&
          lng == null &&
          clientId.isNotEmpty &&
          clientLocationsMap.containsKey(clientId)) {
        lat = clientLocationsMap[clientId]?['lat'];
        lng = clientLocationsMap[clientId]?['lng'];
        if (address == null || address.isEmpty) {
          address = clientLocationsMap[clientId]?['address'];
        }
      }

      if (address == null || address.isEmpty) {
        address = data['address']?.toString() ??
            data['street']?.toString() ??
            data['clientAddress']?.toString() ??
            area;
      }

      // Status parsing
      String rawStatus =
          data['status']?.toString().toLowerCase().trim() ?? 'scheduled';
      if (rawStatus == 'completed' || rawStatus == 'done') {
        rawStatus = 'done';
      } else {
        rawStatus = 'upcoming';
      }

      String clientName = data['clientName'] ??
          data['client'] ??
          data['userName'] ??
          data['name'] ??
          (clientId.isNotEmpty ? clientNamesMap[clientId] : null) ??
          (strings['unknownClient'] ?? 'Client');
      String serviceType = data['serviceType'] ??
          data['sessionType'] ??
          data['service'] ??
          data['plan'] ??
          (strings['strength'] ?? 'Personal Training');

      DateTime? parsedDateTime;
      if (rawDate is Timestamp) {
        parsedDateTime = rawDate.toDate();
      } else if (rawDate is DateTime) {
        parsedDateTime = rawDate;
      } else if (rawDate is String) {
        parsedDateTime = DateTime.tryParse(rawDate);
      }
      if (parsedDateTime != null) {
        int h = 8;
        int m = 0;
        final tParts = parsedTime.split(':');
        if (tParts.isNotEmpty) h = int.tryParse(tParts[0]) ?? 8;
        if (tParts.length > 1) m = int.tryParse(tParts[1]) ?? 0;
        if (parsedAmPm == 'PM' && h < 12) h += 12;
        if (parsedAmPm == 'AM' && h == 12) h = 0;
        parsedDateTime = DateTime(
          parsedDateTime.year,
          parsedDateTime.month,
          parsedDateTime.day,
          h,
          m,
        );
      }

      final uniqueKey = data['bookingId'] ?? data['sessionId'] ?? doc.id;
      sessionMap[uniqueKey] = _ScheduleSession(
        id: doc.id,
        clientId: clientId,
        clientName: clientName.toUpperCase(),
        serviceType: serviceType.toUpperCase(),
        time: parsedTime,
        amPm: parsedAmPm,
        area: area,
        latitude: lat,
        longitude: lng,
        address: address,
        scheduledDateTime: parsedDateTime,
        status: rawStatus,
        notes: data['notes'] ?? data['sessionNotes'] ?? data['trainerNotes'],
        rawDate: rawDate,
      );
    }

    final allList = sessionMap.values.toList();

    if (mounted) {
      setState(() {
        _allSessions = allList;
        _filterSessionsForSelectedDate();
        _loading = false;
      });
    }
  }

  Future<void> _toggleSessionStatus(_ScheduleSession session) async {
    final oldStatus = session.status;
    final newStatus = oldStatus == 'done' ? 'upcoming' : 'done';

    setState(() {
      session.status = newStatus;
    });

    try {
      final firestoreStatus = newStatus == 'done' ? 'completed' : 'scheduled';
      final batch = FirebaseFirestore.instance.batch();

      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(session.id);
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(session.id);

      batch.set(sessionRef, {
        'status': firestoreStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(bookingRef, {
        'status': firestoreStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (session.clientId.isNotEmpty) {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(session.clientId);
        if (newStatus == 'done') {
          batch.set(userRef, {
            'completedSessions': FieldValue.increment(1),
          }, SetOptions(merge: true));
        } else {
          batch.set(userRef, {
            'completedSessions': FieldValue.increment(-1),
          }, SetOptions(merge: true));
        }
      }

      await batch.commit();
    } catch (e) {
      setState(() {
        session.status = oldStatus;
      });
      debugPrint('Failed to update session status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = languageService.strings;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;
    final brandBlue = Theme.of(context).colorScheme.primary;

    int completedCount = _sessions.where((s) => s.status == 'done').length;
    int totalCount = _sessions.length;
    double progress = totalCount > 0 ? (completedCount / totalCount) : 0;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: widget.isEmbeddedInShell
          ? null
          : _BottomNav(currentIndex: 1, strings: strings),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TopHeaderBand(),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              strings['scheduleDate'] ?? 'Schedule date',
              style: GoogleFonts.workSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 75,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _scrollableDates.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final date = _scrollableDates[i];
                final selected = _isSameDay(date, _selectedDate);

                const darkNavy = Color(0xFF00225D);
                const headerBlue = Color(0xFF003AA3);

                return GestureDetector(
                  onTap: () => _selectDate(date),
                  child: Container(
                    width: 65,
                    decoration: BoxDecoration(
                      color: selected ? darkNavy : cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? headerBlue : dividerColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getWeekdayLabel(date.weekday, strings),
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white.withValues(alpha: 0.85)
                                : subTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.workSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${strings['timeDash'] ?? 'Time - '}${_formatFullDate(_selectedDate, strings)}',
                    style: GoogleFonts.workSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 6,
                      decoration: BoxDecoration(
                        color: totalCount > 0 ? primaryRed : dividerColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: primaryRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$completedCount/$totalCount',
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: brandBlue))
                : _sessions.isEmpty
                ? Center(
                    child: Text(
                      strings['noSessionsThisDay'] ??
                          'No sessions scheduled for this day.',
                      style: GoogleFonts.workSans(
                        color: subTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _sessions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _SessionCard(
                        session: _sessions[index],
                        strings: strings,
                        onToggle: () => _toggleSessionStatus(_sessions[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.strings,
    required this.onToggle,
  });
  final _ScheduleSession session;
  final Map<String, String> strings;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final bool isDone = session.status == 'done';
    final bool isActive = session.status == 'active' || session.status == 'live';

    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    const brandRed = Color(0xFFBB0013);
    const brandNavy = Color(0xFF00225D);
    final innerBoxColor = Theme.of(context).scaffoldBackgroundColor;

    Color badgeBg = isDone
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFE2E8F0);
    Color badgeText = isDone ? const Color(0xFF15803D) : const Color(0xFF64748B);
    String badgeLabel = isDone
        ? (strings['done'] ?? 'Done')
        : (strings['upcoming'] ?? 'Upcoming');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? brandRed : dividerColor,
          width: isActive ? 1.8 : 1.2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: brandRed.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings['time'] ?? 'Time',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.amPm.isNotEmpty
                      ? '${session.time} ${session.amPm}'
                      : session.time,
                  style: GoogleFonts.workSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (session.clientId.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TrainerUserProfileScreen(
                                  clientId: session.clientId,
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          session.clientName,
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeLabel,
                          style: GoogleFonts.workSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: badgeText,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          TrainerHomeScreen.openGoogleMaps(
                            lat: session.latitude,
                            lng: session.longitude,
                            address: session.address ?? session.area,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Color(0xFF01BCE3),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                session.area,
                                style: GoogleFonts.workSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF01BCE3),
                                  decoration: TextDecoration.underline,
                                  decorationColor: const Color(0xFF01BCE3),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.fitness_center, size: 14, color: subTextColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        session.serviceType,
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (session.notes != null && session.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: innerBoxColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dividerColor),
                    ),
                    child: Text(
                      session.notes!,
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subTextColor,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                Row(
                  children: [
                    if (isDone) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF22C55E),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  strings['completed'] ?? 'Completed',
                                  style: GoogleFonts.workSans(
                                    color: const Color(0xFF16A34A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OutlineBtn(
                          icon: Icons.edit_outlined,
                          label: strings['editNotes'] ?? 'Edit notes',
                          onTap: () {
                            TrainerMainScreen.switchTab(context, 3);
                          },
                        ),
                      ),
                    ],
                    if (!isDone) ...[
                      if (session.canMarkDone) ...[
                        Expanded(
                          child: _SolidBtn(
                            icon: Icons.check,
                            label: isActive
                                ? (strings['complete'] ?? 'Complete')
                                : (strings['markDone'] ?? 'Mark done'),
                            color: isActive ? brandRed : brandNavy,
                            onTap: onToggle,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: _OutlineBtn(
                          icon: Icons.edit_outlined,
                          label: strings['addNotes'] ?? 'Add notes',
                          onTap: () {
                            TrainerMainScreen.switchTab(context, 3);
                          },
                        ),
                      ),
                    ],
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

class _SolidBtn extends StatelessWidget {
  const _SolidBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.workSans(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        side: BorderSide(color: subTextColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16, color: textColor),
      label: Text(
        label,
        style: GoogleFonts.workSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

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
        color: Theme.of(context).primaryColor,
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
                    if (uid != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final userEmail = FirebaseAuth.instance.currentUser?.email;
                            final hasUnread = snapshot.data!.docs.any((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final isForMe = TrainerNotificationsScreen.isNotificationForTrainer(
                                data: data,
                                uid: uid,
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
        color: Theme.of(context).primaryColor,
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
