import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'notification_screen.dart';

class RescheduleScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const RescheduleScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  late List<DateTime> _next6Days;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _reasonController = TextEditingController();

  bool _isChecking = false;
  bool _isUpdating = false;
  String _availabilityStatus = 'none';

  // BookingScreen Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _activeBlue = Color(0xFF003AA3);
  static const Color _redButtonColor = Color(0xFFBB0013);

  @override
  void initState() {
    super.initState();
    _generateNext6Days();
    _parseInitialTime();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _parseInitialTime() {
    try {
      if (widget.bookingData['time'] != null ||
          widget.bookingData['startTime'] != null) {
        String timeStr =
            widget.bookingData['startTime'] ?? widget.bookingData['time'];
        final parts = timeStr.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);
        if (parts.length > 1) {
          if (parts[1].toUpperCase() == 'PM' && hour != 12) {
            hour += 12;
          }
          if (parts[1].toUpperCase() == 'AM' && hour == 12) {
            hour = 0;
          }
        }
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
      } else {
        _selectedTime = const TimeOfDay(hour: 10, minute: 30);
      }
    } catch (e) {
      _selectedTime = const TimeOfDay(hour: 10, minute: 30);
    }
  }

  void _generateNext6Days() {
    _next6Days = [];
    DateTime today = DateTime.now();
    for (int i = 0; i < 6; i++) {
      _next6Days.add(today.add(Duration(days: i)));
    }
    _selectedDate = _next6Days[1];
  }

  int _timeOfDayToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  int _parseTimeToMinutes(String timeStr) {
    if (timeStr.isEmpty) {
      return 0;
    }
    bool isPm = timeStr.toUpperCase().contains("PM");
    bool isAm = timeStr.toUpperCase().contains("AM");
    String clean = timeStr.replaceAll(RegExp(r'[^\d:]'), '');
    List<String> parts = clean.split(":");
    int h = int.tryParse(parts[0]) ?? 0;
    int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    if (isPm && h < 12) {
      h += 12;
    }
    if (isAm && h == 12) {
      h = 0;
    }
    return h * 60 + m;
  }

  String _formatTimeStrict(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedTime = picked;
      _availabilityStatus = 'none';
    });
  }

  // --- 60-MINUTE NON-OVERLAPPING CONFLICT ENGINE ---
  Future<void> _checkAvailability() async {
    if (_selectedTime == null || _selectedDate == null) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isChecking = true;
      _availabilityStatus = 'none';
    });

    try {
      final DateTime now = DateTime.now();
      final DateTime selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Check if time is in past
      if (selectedDateTime.isBefore(now)) {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _availabilityStatus = 'past';
          });
        }
        return;
      }

      final String newDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final String dayOfWeek = DateFormat('EEEE').format(_selectedDate!);
      final String trainerId =
          widget.bookingData['trainerId']?.toString() ?? '';

      int requestedStart = _timeOfDayToMinutes(_selectedTime!);
      int requestedEnd = requestedStart + 60;

      // 1. Verify within Trainer's working shifts
      if (trainerId.isNotEmpty) {
        final availSnap = await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .collection('availability')
            .where('dayOfWeek', isEqualTo: dayOfWeek)
            .get();

        if (availSnap.docs.isNotEmpty) {
          bool withinWorkingHours = availSnap.docs.any((d) {
            int s = _parseTimeToMinutes(d.data()['startTime'] ?? '06:00 AM');
            int e = _parseTimeToMinutes(d.data()['endTime'] ?? '08:00 PM');
            return requestedStart >= s && requestedEnd <= e;
          });

          if (!withinWorkingHours) {
            if (mounted) {
              setState(() {
                _isChecking = false;
                _availabilityStatus = 'taken';
              });
            }
            return;
          }
        }
      }

      // 2. Fetch existing bookings for this date and trainer
      final bookingsQuery = FirebaseFirestore.instance
          .collection('bookings')
          .where('date', isEqualTo: newDateStr);

      final sessionsQuery = FirebaseFirestore.instance
          .collection('sessions')
          .where('scheduledDate', isEqualTo: newDateStr);

      final results = await Future.wait([
        trainerId.isNotEmpty
            ? bookingsQuery.where('trainerId', isEqualTo: trainerId).get()
            : bookingsQuery.get(),
        trainerId.isNotEmpty
            ? sessionsQuery.where('trainerId', isEqualTo: trainerId).get()
            : sessionsQuery.get(),
      ]);

      bool hasOverlap(Map<String, dynamic> data, String docId) {
        // Exclude the current session being rescheduled
        if (docId == widget.bookingId) {
          return false;
        }
        if (data['status'] == 'cancelled' || data['status'] == 'rejected') {
          return false;
        }

        int bStart =
            data['startMinutes'] ??
            _parseTimeToMinutes(data['startTime'] ?? data['time'] ?? '00:00');
        int bEnd = data['endMinutes'] ?? (bStart + 60);

        return (requestedStart < bEnd) && (requestedEnd > bStart);
      }

      bool isColliding =
          results[0].docs.any((d) => hasOverlap(d.data(), d.id)) ||
          results[1].docs.any((d) => hasOverlap(d.data(), d.id));

      if (mounted) {
        setState(() {
          _isChecking = false;
          _availabilityStatus = isColliding ? 'taken' : 'available';
        });
      }
    } catch (e) {
      debugPrint("Error checking availability: $e");
      if (mounted) {
        setState(() {
          _isChecking = false;
          _availabilityStatus = 'none';
        });
      }
    }
  }

  // --- CONFIRM RESCHEDULE & NOTIFY TRAINER/ADMIN ---
  Future<void> _confirmReschedule() async {
    if (_selectedDate == null || _selectedTime == null) {
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final String newDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final String newTimeStr = _formatTimeStrict(_selectedTime!);
      final String formattedFullDate = DateFormat(
        'EEEE, MMM d',
      ).format(_selectedDate!);

      int startMin = _timeOfDayToMinutes(_selectedTime!);
      int endMin = startMin + 60;
      TimeOfDay endTod = TimeOfDay(
        hour: (endMin ~/ 60) % 24,
        minute: endMin % 60,
      );
      final String newEndTimeStr = _formatTimeStrict(endTod);

      final String trainerId =
          widget.bookingData['trainerId']?.toString() ?? '';
      final String trainerName =
          widget.bookingData['trainerName']?.toString() ?? 'Trainer';
      final String clientName =
          widget.bookingData['clientName']?.toString() ??
          FirebaseAuth.instance.currentUser?.displayName ??
          'Client';
      final String sessionType =
          widget.bookingData['sessionType']?.toString() ?? 'Training Session';

      final batch = FirebaseFirestore.instance.batch();

      // 1. Update in bookings collection
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId);
      batch.update(bookingRef, {
        'date': newDateStr,
        'scheduledDate': newDateStr,
        'time': newTimeStr,
        'startTime': newTimeStr,
        'endTime': newEndTimeStr,
        'startMinutes': startMin,
        'endMinutes': endMin,
        'status': 'confirmed',
        'rescheduled': true,
        'rescheduleReason': _reasonController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Synchronize to sessions collection
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.bookingId);
      batch.set(sessionRef, {
        'bookingId': widget.bookingId,
        'sessionId': widget.bookingId,
        'trainerId': trainerId,
        'trainerName': trainerName,
        'clientName': clientName,
        'scheduledDate': newDateStr,
        'date': newDateStr,
        'startTime': newTimeStr,
        'endTime': newEndTimeStr,
        'time': newTimeStr,
        'startMinutes': startMin,
        'endMinutes': endMin,
        'durationMinutes': 60,
        'serviceType': sessionType,
        'status': 'rescheduled',
        'rescheduleReason': _reasonController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Dispatch Notification to Trainer
      if (trainerId.isNotEmpty) {
        final notifTrainerRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();
        batch.set(notifTrainerRef, {
          'userId': trainerId,
          'recipientRole': 'trainer',
          'type': 'session_rescheduled',
          'title': 'Session Rescheduled',
          'body':
              '$clientName rescheduled $sessionType to $formattedFullDate ($newTimeStr - $newEndTimeStr).',
          'sessionId': widget.bookingId,
          'bookingId': widget.bookingId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Dispatch Notification to Admin
      final notifAdminRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();
      batch.set(notifAdminRef, {
        'recipientRole': 'admin',
        'type': 'session_rescheduled',
        'title': 'Session Rescheduled: $clientName',
        'body':
            'Trainer: $trainerName | $formattedFullDate ($newTimeStr - $newEndTimeStr)',
        'sessionId': widget.bookingId,
        'bookingId': widget.bookingId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reschedule_success'.tr()),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Reschedule error: $e");
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('reschedule_fail'.tr())));
      setState(() => _isUpdating = false);
    }
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
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'reschedule_title'.tr(),
                style: const TextStyle(
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
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _textMain,
                size: 24,
              ),
              onPressed: () async {
                HapticFeedback.selectionClick();
                await Future.delayed(const Duration(milliseconds: 50));

                if (!mounted) {
                  return;
                }

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, a, b) => const NotificationScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                            child: child,
                          );
                        },
                    transitionDuration: const Duration(milliseconds: 150),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentMonthYear = DateFormat('MMM yyyy').format(_selectedDate!);
    String oldDateDisplay = '';
    try {
      DateTime oldDt = DateTime.parse(widget.bookingData['date']);
      oldDateDisplay = DateFormat('MMM dd, yyyy').format(oldDt).toUpperCase();
    } catch (e) {
      oldDateDisplay = widget.bookingData['date'] ?? 'tbd'.tr();
    }

    String trainerName = widget.bookingData['trainerName'] ?? 'unassigned'.tr();

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(child: _buildTopAppBar()),
              const SizedBox(height: 12),

              // Current Session Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'current_session'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textMain,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _activeBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: _activeBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.bookingData['sessionType'] ??
                                    'training_default'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: _textMain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'trainer_name_format'.tr(
                                        namedArgs: {'trainerName': trainerName},
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
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
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: Colors.grey.shade500,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'date_label'.tr(),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              oldDateDisplay,
                              style: const TextStyle(
                                color: _textMain,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.grey.shade500,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'time_label'.tr(),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.bookingData['time'] ??
                                  widget.bookingData['startTime'] ??
                                  '',
                              style: const TextStyle(
                                color: _textMain,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Date Selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'select_new_date'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      currentMonthYear,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 88,
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: _next6Days.map((date) {
                      bool isSelected = _selectedDate == date;
                      return _BouncingButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedDate = date;
                            _availabilityStatus = 'none';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(right: 12),
                          width: 58,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected ? _activeBlue : Colors.white,
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _activeBlue.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE').format(date).toUpperCase(),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  DateFormat('d').format(date),
                                  style: TextStyle(
                                    color: isSelected ? _activeBlue : _textMain,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Time Selection & Reason
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'select_time_title'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textMain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _BouncingButton(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: _bgColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedTime == null
                                        ? 'select_time_btn'.tr()
                                        : _formatTimeStrict(_selectedTime!),
                                    style: const TextStyle(
                                      color: _textMain,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _BouncingButton(
                          onTap: _isChecking ? null : _checkAvailability,
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _redButtonColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _isChecking
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'btn_check'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (_availabilityStatus == 'available') ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'time_available'.tr(),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_availabilityStatus == 'taken') ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cancel,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'slot_booked'.tr(),
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_availabilityStatus == 'past') ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.access_time_filled,
                              color: Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'cannot_book_past'.tr(),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 24),

                    Text(
                      'reason_optional'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'reason_hint'.tr(),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Confirm Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _BouncingButton(
                  onTap: (_availabilityStatus == 'available' && !_isUpdating)
                      ? () {
                          HapticFeedback.mediumImpact();
                          _confirmReschedule();
                        }
                      : null,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          (_availabilityStatus == 'available' && !_isUpdating)
                          ? _redButtonColor
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'confirm_changes'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bouncing Button for interaction feedback
class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _BouncingButton({required this.child, required this.onTap});
  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
