import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:url_launcher/url_launcher.dart';

import '../notifications/trainer_notifications_screen.dart';
import '../profile/trainer_client_reviews_screen.dart';
import 'trainer_main_screen.dart';

// IMPORT LANGUAGE SERVICE
import '../../services/language_service.dart';

import '../../services/trainer_data_service.dart';

class TrainerHomeScreen extends StatefulWidget {
  final bool isEmbeddedInShell;
  const TrainerHomeScreen({super.key, this.isEmbeddedInShell = false});

  /// Opens Google Maps with coordinates or address for turn-by-turn navigation
  static Future<void> openGoogleMaps({
    double? lat,
    double? lng,
    String? address,
  }) async {
    try {
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        // 1. Try Google Maps Native App Navigation intent directly
        final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
        try {
          if (await launchUrl(navUri, mode: LaunchMode.externalApplication)) {
            return;
          }
        } catch (_) {}

        // 2. Try geo: intent
        final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
        try {
          if (await launchUrl(geoUri, mode: LaunchMode.externalApplication)) {
            return;
          }
        } catch (_) {}

        // 3. Fallback to Google Maps Directions API (active turn-by-turn navigation)
        final webUri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving&dir_action=navigate',
        );
        try {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Web launch error: $e');
        }
        return;
      }

      if (address != null &&
          address.trim().isNotEmpty &&
          address.trim() != 'Location' &&
          address.trim() != '—') {
        final query = Uri.encodeComponent(address.trim());
        final navUri = Uri.parse('google.navigation:q=$query&mode=d');
        try {
          if (await launchUrl(navUri, mode: LaunchMode.externalApplication)) {
            return;
          }
        } catch (_) {}

        final webUri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving&dir_action=navigate',
        );
        try {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Web launch error: $e');
        }
      }
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
    }
  }

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerSession {
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

  _TrainerSession({
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
  });

  /// Only visible/markable on the current scheduled date & time (with a 15-minute buffer before start)
  bool get canMarkDone {
    if (scheduledDateTime == null) return true;
    final now = DateTime.now();
    return now.isAfter(scheduledDateTime!.subtract(const Duration(minutes: 15)));
  }
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<_TrainerSession> _sessions = [];
  bool _loading = true;

  // Keep brand red static
  static const Color primaryRed = Color(0xFFBB0013);

  @override
  void initState() {
    super.initState();
    if (TrainerDataService().isInitialized) {
      _parseFromCache();
      _loadData(showSpinner: false);
    } else {
      _loadData(showSpinner: true);
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
        int day = int.parse(dmyMatch.group(1)!);
        int m = int.parse(dmyMatch.group(2)!);
        int y = int.parse(dmyMatch.group(3)!);
        return y == targetDate.year &&
            m == targetDate.month &&
            day == targetDate.day;
      }

      d = DateTime.tryParse(s);
      if (d == null) {
        final lower = s.toLowerCase();
        const months = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };
        for (final entry in months.entries) {
          if (lower.contains(entry.key)) {
            final numbers = RegExp(
              r'\d+',
            ).allMatches(lower).map((m) => int.parse(m.group(0)!)).toList();
            if (numbers.isNotEmpty) {
              int year = numbers.firstWhere(
                (n) => n > 1900 && n < 2100,
                orElse: () => targetDate.year,
              );
              int day = numbers.firstWhere(
                (n) => n <= 31 && n != year,
                orElse: () => -1,
              );
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

  Future<void> _loadData({bool showSpinner = false, bool force = false}) async {
    if (showSpinner && _sessions.isEmpty) {
      if (mounted) setState(() => _loading = true);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
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
      debugPrint('Trainer home load error: $e');
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
        final assignedId = data['assignedTrainerId'] ??
            data['trainerId'] ??
            data['assignedTrainer'] ??
            '';
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
    final Map<String, _TrainerSession> sessionMap = {};
    final now = DateTime.now();

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
        } else if (docTrainerId.isEmpty &&
            docTrainerName.isEmpty &&
            clientId != uid) {
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

      if (!_isSameDayDate(rawDate, now)) {
        continue;
      }

      String rawTime = data['startTime']?.toString().trim() ??
          data['time']?.toString().trim() ??
          data['scheduledTime']?.toString().trim() ??
          data['sessionTime']?.toString().trim() ??
          data['start_time']?.toString().trim() ??
          '08:00 AM';
      List<String> timeParts = rawTime.split(' ');
      String parsedTime = timeParts.isNotEmpty ? timeParts[0] : '08:00';
      String parsedAmPm =
          timeParts.length > 1 ? timeParts[1].toUpperCase() : 'AM';

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
      } else if (data['area'] != null && data['area'].toString().isNotEmpty) {
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

      String rawStatus =
          data['status']?.toString().toLowerCase().trim() ?? 'future';
      if (rawStatus == 'completed' || rawStatus == 'done') {
        rawStatus = 'completed';
      } else if (rawStatus == 'live' || rawStatus == 'live now') {
        rawStatus = 'live';
      } else {
        rawStatus = 'future';
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
      sessionMap[uniqueKey] = _TrainerSession(
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
      );
    }

    final loadedList = sessionMap.values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    if (mounted) {
      setState(() {
        _sessions = loadedList;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSessionStatus(_TrainerSession session) async {
    final oldStatus = session.status;
    final newStatus = oldStatus == 'completed' ? 'future' : 'completed';

    setState(() {
      session.status = newStatus;
    });

    try {
      final firestoreStatus = newStatus == 'completed'
          ? 'completed'
          : 'scheduled';
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
        if (newStatus == 'completed') {
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

    // ---> DYNAMIC THEME COLORS <---
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;
    final primaryBlue = Theme.of(context).primaryColor;

    final heroSession = _sessions.cast<_TrainerSession?>().firstWhere(
      (s) => s?.status != 'completed',
      orElse: () => _sessions.isNotEmpty ? _sessions.first : null,
    );

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: widget.isEmbeddedInShell
          ? null
          : _BottomNav(currentIndex: 0, strings: strings),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TopHeaderBand(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // Hero Card
                        if (heroSession != null)
                          _HeroSessionCard(
                            session: heroSession,
                            onComplete: () => _toggleSessionStatus(heroSession),
                            strings: strings,
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: dividerColor,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              strings['noSessionsScheduled'] ??
                                  'No sessions scheduled for today yet.',
                              style: GoogleFonts.workSans(
                                color: subTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),

                        Text(
                          strings['quickAction'] ?? 'Quick Action',
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Quick Actions Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              TrainerMainScreen.switchTab(context, 3);
                            },
                            child: _QuickActionCard(
                              label: strings['addNotes'] ?? 'Add Notes',
                              icon: Icons.chat_outlined,
                              isRed: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TrainerClientReviewsScreen(),
                                ),
                              );
                            },
                            child: _QuickActionCard(
                              label:
                                  strings['reviewFeedback'] ??
                                  'Review Feedback',
                              icon: Icons.star_outline_rounded,
                              isRed: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Today's Sessions Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              strings['todaysSessions'] ?? "Today's Sessions",
                              style: GoogleFonts.workSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                TrainerMainScreen.switchTab(context, 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  strings['viewAll'] ?? 'View All',
                                  style: GoogleFonts.workSans(
                                    color: primaryRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_sessions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              strings['noSessionsToday'] ??
                                  'No sessions today.',
                              style: GoogleFonts.workSans(color: subTextColor),
                            ),
                          )
                        else
                          ..._sessions.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SessionRow(
                                session: s,
                                onToggle: () => _toggleSessionStatus(s),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------
// WIDGETS
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
        color: Theme.of(context).primaryColor, // Dynamic Brand Blue
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
                      color:
                          Colors.white, // Popped to white for better contrast
                      size: 20,
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData &&
                            snapshot.data!.docs.isNotEmpty) {
                          final userEmail =
                              FirebaseAuth.instance.currentUser?.email;
                          final hasUnread = snapshot.data!.docs.any((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final isForMe =
                                TrainerNotificationsScreen.isNotificationForTrainer(
                                  data: data,
                                  uid: uid ?? '',
                                  userEmail: userEmail,
                                );
                            final isUnread =
                                TrainerNotificationsScreen.isNotificationUnread(
                                  data,
                                );
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

class _HeroSessionCard extends StatelessWidget {
  const _HeroSessionCard({
    required this.session,
    required this.onComplete,
    required this.strings,
  });

  final _TrainerSession session;
  final VoidCallback onComplete;
  final Map<String, String> strings;

  @override
  Widget build(BuildContext context) {
    final isCompleted = session.status == 'completed';

    // We keep the static gradient here since it is the "Hero" element and looks beautiful in both modes
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00225D), Color(0xFF001233)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.clientName,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.serviceType,
                      style: GoogleFonts.workSans(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
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
                            size: 16,
                            color: Color(0xFF01BCE3),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              session.area,
                              style: GoogleFonts.workSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF01BCE3),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 90,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      color: Color(0xFF01BCE3),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.time,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      session.amPm,
                      style: GoogleFonts.workSans(
                        color: const Color(0xFF01BCE3),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Google Maps Live Client Navigation Tile (Uber/Delivery style)
          GestureDetector(
            onTap: () {
              TrainerHomeScreen.openGoogleMaps(
                lat: session.latitude,
                lng: session.longitude,
                address: session.address ?? session.area,
              );
            },
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF01BCE3).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF01BCE3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Color(0xFF00225D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                strings['clientLocation'] ?? 'CLIENT LOCATION',
                                style: GoogleFonts.workSans(
                                  color: const Color(0xFF01BCE3),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.open_in_new_rounded,
                              color: Color(0xFF01BCE3),
                              size: 11,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.address != null &&
                                  session.address!.isNotEmpty &&
                                  session.address != 'Location'
                              ? session.address!
                              : (session.area != 'Location'
                                  ? session.area
                                  : (strings['openInGoogleMaps'] ??
                                      'Open in Google Maps')),
                          style: GoogleFonts.workSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_car_rounded,
                          color: Color(0xFF00225D),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings['navigate'] ?? 'Navigate',
                          style: GoogleFonts.workSans(
                            color: const Color(0xFF00225D),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              if (isCompleted)
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
                          size: 18,
                          color: Color(0xFF4ADE80),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            strings['completed'] ?? 'Completed',
                            style: GoogleFonts.workSans(
                              color: const Color(0xFF4ADE80),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (session.canMarkDone)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      strings['markDone'] ?? 'Mark Done',
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (isCompleted || session.canMarkDone)
                const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    TrainerMainScreen.switchTab(context, 3);
                  },
                  icon: const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    strings['addVisitNotes'] ?? 'Add visit notes',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBB0013),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.isRed,
  });

  final String label;
  final IconData icon;
  final bool isRed;

  @override
  Widget build(BuildContext context) {
    // Red stays Red. Dark Blue adapts to Primary Theme Color.
    final boxColor = isRed
        ? const Color(0xFFBB0013)
        : Theme.of(context).primaryColor;

    return Container(
      height: 95,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.workSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onToggle});

  final _TrainerSession session;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isCompleted = session.status == 'completed';
    final isLive = session.status == 'live';

    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    const brandRed = Color(0xFFBB0013);
    const brandNavy = Color(0xFF00225D);

    // Dynamic Row Styling matching mock design
    Color rowBgColor = cardColor;
    Color borderColor = isLive
        ? brandRed
        : isCompleted
        ? dividerColor.withValues(alpha: 0.5)
        : dividerColor.withValues(alpha: 0.5);
    Color timeBoxColor = isLive
        ? brandRed
        : isCompleted
        ? brandNavy
        : const Color(0xFFE2E8F0);
    Color timeTextColor = (isLive || isCompleted)
        ? Colors.white
        : const Color(0xFF334155);
    Color titleColor = isLive ? brandRed : textColor;

    return GestureDetector(
      onTap: () {
        TrainerMainScreen.switchTab(context, 1);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: rowBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isLive ? 1.8 : 1.2),
          boxShadow: isLive
              ? [
                  BoxShadow(
                    color: brandRed.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 60,
              decoration: BoxDecoration(
                color: timeBoxColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    session.time,
                    style: GoogleFonts.workSans(
                      color: timeTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    session.amPm,
                    style: GoogleFonts.workSans(
                      color: timeTextColor.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          session.clientName,
                          style: GoogleFonts.workSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF22C55E),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'DONE ✓',
                            style: GoogleFonts.workSans(
                              color: const Color(0xFF16A34A),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      if (isLive) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: brandRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: subTextColor,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          session.area,
                          style: GoogleFonts.workSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
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
            GestureDetector(
              onTap: () {
                TrainerHomeScreen.openGoogleMaps(
                  lat: session.latitude,
                  lng: session.longitude,
                  address: session.address ?? session.area,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: (isLive ? brandRed : brandNavy).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.navigation_rounded,
                  color: isLive ? brandRed : brandNavy,
                  size: 18,
                ),
              ),
            ),
            Icon(
              isLive
                  ? Icons.keyboard_double_arrow_right_rounded
                  : Icons.chevron_right_rounded,
              color: isLive ? brandRed : subTextColor.withValues(alpha: 0.5),
              size: isLive ? 24 : 20,
            ),
          ],
        ),
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
        color: Theme.of(context).primaryColor, // Dynamic Brand Blue
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
        ).colorScheme.secondary, // Cyan accent
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
