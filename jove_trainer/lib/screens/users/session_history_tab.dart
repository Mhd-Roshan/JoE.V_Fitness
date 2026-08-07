import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SessionHistoryTab extends StatefulWidget {
  const SessionHistoryTab({super.key, required this.clientId});
  final String clientId;

  @override
  State<SessionHistoryTab> createState() => _SessionHistoryTabState();
}

class _VisitSession {
  final String id;
  final String time;
  final String dateLabel;
  final String status;
  final String area;
  final String serviceType;
  final String? notes;
  final String? recordingUrl;
  final String? recordingDuration;

  _VisitSession({
    required this.id,
    required this.time,
    required this.dateLabel,
    required this.status,
    required this.area,
    required this.serviceType,
    this.notes,
    this.recordingUrl,
    this.recordingDuration,
  });
}

class _SessionHistoryTabState extends State<SessionHistoryTab> {
  bool _loading = true;
  List<_VisitSession> _sessions = [];

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = [
    '',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  // Real Firestore read only — no fallback sample sessions.
  Future<void> _loadSessions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('clientId', isEqualTo: widget.clientId)
          .get();

      final sessions = snap.docs.map((d) {
        final data = d.data();
        final dateStr = data['scheduledDate'] as String?;
        String dateLabel = '—';
        if (dateStr != null) {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null) {
            dateLabel =
                '${_weekdays[parsed.weekday]} ${parsed.day} ${_months[parsed.month]}';
          }
        }
        return _VisitSession(
          id: d.id,
          time: data['scheduledTime'] ?? '—',
          dateLabel: dateLabel,
          status: data['status'] ?? 'scheduled',
          area: data['area'] ?? '—',
          serviceType: data['serviceType'] ?? 'Session',
          notes: data['notes'],
          recordingUrl: data['recordingUrl'],
          recordingDuration: data['recordingDuration'],
        );
      }).toList()..sort((a, b) => b.dateLabel.compareTo(a.dateLabel));

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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sessions.isEmpty) {
      return const Center(
        child: Text(
          'No sessions recorded yet.',
          style: TextStyle(color: Color(0xFF808080)),
        ),
      );
    }

    return ListView.separated(
      itemCount: _sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) =>
          _SessionVisitCard(session: _sessions[index]),
    );
  }
}

class _SessionVisitCard extends StatefulWidget {
  const _SessionVisitCard({required this.session});
  final _VisitSession session;

  @override
  State<_SessionVisitCard> createState() => _SessionVisitCardState();
}

class _SessionVisitCardState extends State<_SessionVisitCard> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _loadingAudio = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = widget.session.recordingUrl;
    if (url == null) return;

    if (_player == null) {
      setState(() => _loadingAudio = true);
      _player = AudioPlayer();
      try {
        await _player!.setUrl(url);
      } catch (e) {
        debugPrint('Audio load error: $e');
        setState(() => _loadingAudio = false);
        return;
      }
      _player!.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _player!.seek(Duration.zero);
          }
        });
      });
      setState(() => _loadingAudio = false);
    }

    if (_isPlaying) {
      await _player!.pause();
    } else {
      await _player!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final isDone = s.status == 'completed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EA)),
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
                  const Text(
                    'Time',
                    style: TextStyle(fontSize: 11, color: Color(0xFF808080)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.time,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00225D),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        s.dateLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00225D),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFE6E8EA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isDone
                              ? 'Done'
                              : s.status[0].toUpperCase() +
                                    s.status.substring(1),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDone
                                ? const Color(0xFF15803D)
                                : const Color(0xFF808080),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Color(0xFF808080),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        s.area,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF808080),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.fitness_center,
                        size: 13,
                        color: Color(0xFF808080),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        s.serviceType,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF808080),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (s.notes != null && s.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE6E8EA)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s.notes!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF00225D)),
              ),
            ),
          ],
          if (s.recordingUrl != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _loadingAudio ? null : _togglePlay,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00225D),
                        shape: BoxShape.circle,
                      ),
                      child: _loadingAudio
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _WaveformDecoration(),
                        const SizedBox(height: 4),
                        Text(
                          'Recorded Note',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00225D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s.recordingDuration != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      s.recordingDuration!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF808080),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Purely decorative waveform bars — a visual cue that this is an
/// audio clip, not a real rendering of the recording's amplitude data
/// (that would require decoding the audio file's PCM samples, which
/// just_audio doesn't expose directly).
class _WaveformDecoration extends StatelessWidget {
  const _WaveformDecoration();

  static const _heights = [
    4.0,
    10.0,
    6.0,
    14.0,
    8.0,
    16.0,
    10.0,
    6.0,
    12.0,
    8.0,
    14.0,
    6.0,
    10.0,
    16.0,
    8.0,
    12.0,
    6.0,
    10.0,
    14.0,
    8.0,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          for (int i = 0; i < _heights.length; i++) ...[
            Container(
              width: 2.5,
              height: _heights[i],
              decoration: BoxDecoration(
                color: i.isEven
                    ? const Color(0xFF01BCE3)
                    : const Color(0xFF7459D9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (i != _heights.length - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}
