import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---> IMPORT LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class SessionHistoryTab extends StatefulWidget {
  const SessionHistoryTab({super.key, required this.clientId});
  final String clientId;

  @override
  State<SessionHistoryTab> createState() => _SessionHistoryTabState();
}

class _VisitSession {
  final String id;
  final String time;
  final DateTime? dateObj;
  final String status;
  final String area;
  final String serviceType;
  final String? notes;

  _VisitSession({
    required this.id,
    required this.time,
    this.dateObj,
    required this.status,
    required this.area,
    required this.serviceType,
    this.notes,
  });
}

class _SessionHistoryTabState extends State<SessionHistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  List<_VisitSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  // Real Firestore read only — queries both sessions and bookings collections
  Future<void> _loadSessions() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('sessions')
            .where('clientId', isEqualTo: widget.clientId)
            .get(),
        FirebaseFirestore.instance
            .collection('sessions')
            .where('userId', isEqualTo: widget.clientId)
            .get(),
        FirebaseFirestore.instance
            .collection('bookings')
            .where('clientId', isEqualTo: widget.clientId)
            .get(),
        FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: widget.clientId)
            .get(),
      ]);

      final Map<String, _VisitSession> sessionMap = {};

      for (var snap in results) {
        for (var d in snap.docs) {
          final data = d.data();
          final rawDate = data['scheduledDate'] ??
              data['date'] ??
              data['sessionDate'] ??
              data['bookingDate'] ??
              data['createdAt'];

          DateTime? parsedDate;
          if (rawDate is Timestamp) {
            parsedDate = rawDate.toDate();
          } else if (rawDate is DateTime) {
            parsedDate = rawDate;
          } else if (rawDate is String && rawDate.isNotEmpty) {
            parsedDate = DateTime.tryParse(rawDate);
          }

          final rawTime = data['startTime'] ??
              data['time'] ??
              data['scheduledTime'] ??
              data['sessionTime'] ??
              '—';

          String area = '—';
          if (data['location'] is Map) {
            area = data['location']['title'] ?? data['location']['address'] ?? '—';
          } else if (data['area'] != null && data['area'].toString().isNotEmpty) {
            area = data['area'].toString();
          }

          final uniqueKey = data['bookingId'] ?? data['sessionId'] ?? d.id;
          sessionMap[uniqueKey] = _VisitSession(
            id: d.id,
            time: rawTime.toString(),
            dateObj: parsedDate,
            status: data['status']?.toString() ?? 'scheduled',
            area: area,
            serviceType: data['serviceType']?.toString() ?? data['sessionType']?.toString() ?? 'Session',
            notes: data['notes'] ?? data['sessionNotes'],
          );
        }
      }

      final sessions = sessionMap.values.toList();
      // Sorts chronologically by date descending
      sessions.sort((a, b) {
        if (a.dateObj != null && b.dateObj != null) {
          return b.dateObj!.compareTo(a.dateObj!);
        }
        return 0;
      });

      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Session history load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS <---
    final brandBlue = Theme.of(context).colorScheme.primary;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: brandBlue,
        ), // Dynamic loading color
      );
    }
    if (_sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: Text(
            strings['noSessionsRecorded'] ?? 'No sessions recorded yet.',
            style: GoogleFonts.workSans(
              color: subTextColor, // Dynamic empty text color
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) =>
          _SessionVisitCard(session: _sessions[index]),
    );
  }
}

class _SessionVisitCard extends StatelessWidget {
  const _SessionVisitCard({required this.session});
  final _VisitSession session;

  static const _monthKeys = [
    '',
    'monthJan',
    'monthFeb',
    'monthMar',
    'monthApr',
    'monthMay',
    'monthJun',
    'monthJul',
    'monthAug',
    'monthSep',
    'monthOct',
    'monthNov',
    'monthDec',
  ];

  static const _weekdayKeys = [
    '',
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;
    final isDone = session.status == 'completed' || session.status == 'done';

    // ---> DYNAMIC THEME COLORS FOR CARD <---
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;

    // Check if it's dark mode to adjust the green badge safely
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greenBadgeText = isDark
        ? const Color(0xFF4ADE80)
        : const Color(0xFF15803D);

    // Build translated Date Label
    String dateLabel = '—';
    if (session.dateObj != null) {
      final weekDayStr =
          strings[_weekdayKeys[session.dateObj!.weekday]] ??
          _weekdayKeys[session.dateObj!.weekday].toUpperCase();
      final monthStr =
          strings[_monthKeys[session.dateObj!.month]] ??
          _monthKeys[session.dateObj!.month].toUpperCase();
      dateLabel = '$weekDayStr, ${session.dateObj!.day} $monthStr ${session.dateObj!.year}';
    }

    // Build translated Status
    String displayStatus = session.status;
    if (isDone) {
      displayStatus = strings['done'] ?? 'Done';
    } else if (session.status == 'scheduled' || session.status == 'confirmed' || session.status == 'upcoming') {
      displayStatus = strings['statusScheduled'] ?? 'Confirmed';
    } else if (session.status == 'canceled' || session.status == 'cancelled') {
      displayStatus = strings['statusCanceled'] ?? 'Canceled';
    } else {
      displayStatus = session.status.isNotEmpty
          ? session.status[0].toUpperCase() + session.status.substring(1)
          : '';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor, // Dynamic Card Background
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor), // Dynamic Border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings['timeWord'] ?? 'Time',
                    style: GoogleFonts.workSans(
                      fontSize: 11,
                      color: subTextColor, // Dynamic SubText
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.time,
                    style: GoogleFonts.workSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor, // Dynamic Main Text
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.workSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textColor, // Dynamic Date Text
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDone
                                ? const Color(0xFF22C55E).withValues(
                                    alpha: 0.15,
                                  ) // Dynamic Green tint
                                : dividerColor, // Dynamic Grey tint
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            displayStatus,
                            style: GoogleFonts.workSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDone ? greenBadgeText : subTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              color: subTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.fitness_center, size: 13, color: subTextColor),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            session.serviceType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              color: subTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: dividerColor), // Dynamic border
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                session.notes!,
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  color: textColor, // Dynamic Notes text
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
