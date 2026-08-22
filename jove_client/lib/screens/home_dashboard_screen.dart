import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'booking_screen.dart';
import 'trainer_selection_screen.dart';
import 'reschedule_screen.dart';
import 'progress_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'health_profile_screen.dart';

class _Formatters {
  static final DateFormat date = DateFormat('yyyy-MM-dd');
  static final DateFormat displayDate = DateFormat('MMM d');
  static final DateFormat fullDate = DateFormat('dd MMM yyyy');

  // Safely parses tricky strings like "10:30PM", " 09:00 AM ", or "14:30"
  static DateTime? safeParseDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null ||
        dateStr.isEmpty ||
        timeStr == null ||
        timeStr.isEmpty) {
      return null;
    }

    try {
      DateTime date = DateFormat('yyyy-MM-dd').parse(dateStr);

      String t = timeStr.trim().toUpperCase();
      bool isPM = t.contains('PM');
      bool isAM = t.contains('AM');

      // Strip all letters and spaces, leaving only "10:30"
      t = t.replaceAll(RegExp(r'[A-Z\s]'), '');

      List<String> timeParts = t.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      if (isPM && hour < 12) {
        hour += 12;
      }
      if (isAM && hour == 12) {
        hour = 0;
      }

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      return null;
    }
  }
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);

  late final Stream<DocumentSnapshot> _userStream;
  late final Stream<QuerySnapshot> _bookingStream;
  late final Stream<QuerySnapshot> _dietStream;

  bool _isNavigating = false;

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

    _dietStream = FirebaseFirestore.instance
        .collection('diet_plans')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  Future<void> _handleStandardNavigation(Widget screen, int index) async {
    if (_isNavigating) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isNavigating = true);
    _selectedIndexNotifier.value = index;

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, b) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 150),
      ),
    );

    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  Future<void> _handleBookingNavigation([
    Map<String, dynamic>? userData,
  ]) async {
    if (_isNavigating) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isNavigating = true);
    _selectedIndexNotifier.value = 1;

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
      Widget nextScreen = (trainerId == null || trainerId.isEmpty)
          ? const SelectTrainerScreen()
          : BookingScreen(trainerId: trainerId);

      if (!mounted) {
        return;
      }

      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a, b) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('error_loading_data'.tr())));
      }
    } finally {
      if (mounted) {
        _selectedIndexNotifier.value = 0;
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

      DateTime? sessionDateTime = _Formatters.safeParseDateTime(
        dateStr,
        timeStr,
      );

      if (sessionDateTime == null) {
        throw Exception('Invalid date/time format');
      }

      DateTime now = DateTime.now();

      // Ensure that sessions that have already started/passed CANNOT be rescheduled
      if (!sessionDateTime.isAfter(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot reschedule a session that has already started.'.tr(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Check if trying to reschedule strictly within the 2-hour window
      if (sessionDateTime.difference(now).inMinutes < 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_reschedule_2hrs'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a, b) =>
              RescheduleScreen(bookingId: bookingId, bookingData: bookingData),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_processing_datetime'.tr())));
    }
  }

  Future<void> _handleCompleteSession(String bookingId) async {
    try {
      HapticFeedback.mediumImpact();
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'completed',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session completed successfully!'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_updating_session'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBody: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          final userData =
              userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderSection(
                      userData: userData,
                      onProfileTap: () =>
                          _handleStandardNavigation(const ProfileScreen(), 4),
                    ),
                    _UpcomingSessionSection(
                      bookingStream: _bookingStream,
                      onReschedule: _handleRescheduleClick,
                      onComplete: _handleCompleteSession,
                    ),
                    _QuickActionsSection(
                      onBookingTap: () => _handleBookingNavigation(userData),
                      onHealthTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HealthProfileScreen(),
                          ),
                        );
                      },
                      onDietTap: () =>
                          _handleStandardNavigation(const ChatScreen(), 3),
                    ),
                    _TodayProgressSection(
                      userData: userData,
                      onProgressTap: () =>
                          _handleStandardNavigation(const ProgressScreen(), 2),
                    ),
                    _DietPlansSection(dietStream: _dietStream),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              RepaintBoundary(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _FloatingNavBar(
                    selectedIndexNotifier: _selectedIndexNotifier,
                    onBookingTap: () => _handleBookingNavigation(userData),
                    onStatsTap: () =>
                        _handleStandardNavigation(const ProgressScreen(), 2),
                    onChatsTap: () =>
                        _handleStandardNavigation(const ChatScreen(), 3),
                    onProfileTap: () =>
                        _handleStandardNavigation(const ProfileScreen(), 4),
                    isNavigating: _isNavigating,
                  ),
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
  final VoidCallback onProfileTap;

  const _HeaderSection({required this.userData, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final String userName =
        userData['fullName'] ??
        userData['name'] ??
        userData['firstName'] ??
        'athlete_fallback'.tr();
    final String profilePic =
        userData['profilePic'] ?? userData['imageUrl'] ?? '';
    final String todayDate = _Formatters.fullDate.format(DateTime.now());

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
          _BouncingButton(
            onTap: onProfileTap,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
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
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSessionSection extends StatelessWidget {
  final Stream<QuerySnapshot> bookingStream;
  final Function(String, Map<String, dynamic>) onReschedule;
  final Function(String) onComplete;

  const _UpcomingSessionSection({
    required this.bookingStream,
    required this.onReschedule,
    required this.onComplete,
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
          String displayDate = 'tbd'.tr();
          DateTime? closestSessionDate;

          final DateTime now = DateTime.now();
          final String todayFormatted = _Formatters.date.format(now);

          if (bookingSnapshot.hasData &&
              bookingSnapshot.data!.docs.isNotEmpty) {
            for (var doc in bookingSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'cancelled' ||
                  data['status'] == 'completed') {
                continue;
              }

              // Use robust parsing mechanism
              final sessionDateTime = _Formatters.safeParseDateTime(
                data['date'],
                data['time'],
              );

              if (sessionDateTime != null) {
                if (closestSessionDate == null ||
                    sessionDateTime.isBefore(closestSessionDate)) {
                  closestSessionDate = sessionDateTime;
                  bookingId = doc.id;
                  bookingData = data;
                  hasBooking = true;
                }
              } else {
                // Fallback for corrupted date/time
                if ((data['date'] ?? '').compareTo(todayFormatted) >= 0) {
                  if (!hasBooking) {
                    bookingId = doc.id;
                    bookingData = data;
                    hasBooking = true;
                  }
                }
              }
            }

            if (hasBooking && bookingData != null) {
              if (bookingData['date'] == todayFormatted) {
                displayDate = 'today'.tr();
              } else {
                try {
                  DateTime parsed = _Formatters.date.parse(bookingData['date']);
                  displayDate = _Formatters.displayDate.format(parsed);
                } catch (_) {
                  displayDate = bookingData['date'];
                }
              }
            }
          }

          bool isTodaySunday = now.weekday == DateTime.sunday;
          bool isNextBookingNotToday =
              hasBooking && bookingData!['date'] != todayFormatted;

          final String cardHeaderTitle =
              (isTodaySunday || isNextBookingNotToday || !hasBooking)
              ? '${'rest_day'.tr()} 🌴 • ${'upcoming_session'.tr()}'
              : 'upcoming_session'.tr();

          bool isSessionReached = false;
          if (hasBooking && closestSessionDate != null) {
            isSessionReached = !closestSessionDate.isAfter(now);
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
                      cardHeaderTitle,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
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
                        child: Text(
                          'confirmed'.tr(),
                          style: const TextStyle(
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
                    bookingData!['sessionType'] ?? 'training_session'.tr(),
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
                        bookingData['trainerName'] ?? 'trainer'.tr(),
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$displayDate • ${bookingData['time'] ?? 'tbd'.tr()}',
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
                      if (isSessionReached) ...[
                        Expanded(
                          child: _BouncingButton(
                            onTap: () => onComplete(bookingId!),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Complete Session'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
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
                                      ? 'pending'.tr()
                                      : 'arriving'.tr(),
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
                          child: _BouncingButton(
                            onTap: () => onReschedule(bookingId!, bookingData!),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBB0013),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'reschedule_btn'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  Text(
                    'rest_day'.tr(),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'rest_day_desc'.tr(),
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

class _DietPlansSection extends StatelessWidget {
  final Stream<QuerySnapshot> dietStream;
  const _DietPlansSection({required this.dietStream});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'diet_plans'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black87,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 90,
          child: StreamBuilder<QuerySnapshot>(
            stream: dietStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'no_diet_plans'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final data =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final String title = data['title'] ?? 'Diet Plan';
                  final String date = data['createdAt'] != null
                      ? _Formatters.fullDate.format(
                          (data['createdAt'] as Timestamp).toDate(),
                        )
                      : 'Recent';
                  return _BouncingButton(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening PDF...')),
                      );
                    },
                    child: Container(
                      width: 260,
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Color(0xFFE53935),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
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

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onBookingTap;
  final VoidCallback onHealthTap;
  final VoidCallback onDietTap;
  const _QuickActionsSection({
    required this.onBookingTap,
    required this.onHealthTap,
    required this.onDietTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'quick_action_title'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _QuickActionPill(
                title: 'booking_action'.tr(),
                icon: Icons.calendar_month_outlined,
                pillColor: const Color.fromARGB(255, 180, 4, 22),
                iconColor: const Color(0xFFBB0013),
                textColor: Colors.white,
                onTap: onBookingTap,
              ),
              _QuickActionPill(
                title: 'health_action'.tr(),
                icon: Icons.monitor_heart_outlined,
                pillColor: const Color.fromARGB(255, 143, 228, 240),
                iconColor: const Color.fromARGB(255, 0, 14, 199),
                onTap: onHealthTap,
              ),
              _QuickActionPill(
                title: 'diet_action'.tr(),
                icon: Icons.restaurant_menu_outlined,
                pillColor: const Color.fromARGB(78, 0, 233, 20),
                iconColor: const Color.fromARGB(255, 69, 221, 77),
                onTap: onDietTap,
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
  final VoidCallback onProgressTap;
  const _TodayProgressSection({
    required this.userData,
    required this.onProgressTap,
  });

  @override
  Widget build(BuildContext context) {
    final double exactCardWidth =
        (MediaQuery.of(context).size.width - 48 - 16) / 2;
    final String today = _Formatters.date.format(DateTime.now());

    final dailyWeightMap = userData['dailyWeight'] as Map<String, dynamic>?;
    final String weight =
        dailyWeightMap?[today]?.toString() ??
        userData['weight']?.toString() ??
        '0';

    final dailySleepMap = userData['dailySleep'] as Map<String, dynamic>?;
    final String sleep =
        dailySleepMap?[today]?.toString() ??
        userData['sleep']?.toString() ??
        '0';

    final dailyStepsMap = userData['dailySteps'] as Map<String, dynamic>?;
    final String steps =
        dailyStepsMap?[today]?.toString() ??
        userData['steps']?.toString() ??
        '0';

    final dailyHydrationMap =
        userData['dailyHydration'] as Map<String, dynamic>?;
    final double hydNum =
        (dailyHydrationMap?[today] as num?)?.toDouble() ?? 0.0;
    final double hydVal = hydNum / 1000;
    final String hydration = (hydVal % 1 == 0)
        ? hydVal.toInt().toString()
        : hydVal.toStringAsFixed(1);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'today_progress'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: onProgressTap,
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _ProgressCard(
                exactWidth: exactCardWidth,
                title: 'weight_progress'.tr(),
                value: weight,
                unit: 'kg_unit'.tr(),
                icon: Icons.monitor_weight_outlined,
                iconColor: const Color(0xFFFF9500),
                onTap: onProgressTap,
              ),
              _ProgressCard(
                exactWidth: exactCardWidth,
                title: 'daily_hydration'.tr(),
                value: hydration,
                unit: 'liters_unit'.tr(),
                icon: Icons.water_drop_outlined,
                iconColor: const Color(0xFF007AFF),
                onTap: onProgressTap,
              ),
              _ProgressCard(
                exactWidth: exactCardWidth,
                title: 'sleep_duration'.tr(),
                value: sleep,
                unit: 'hours_unit'.tr(),
                icon: Icons.nightlight_outlined,
                iconColor: const Color(0xFFAF52DE),
                onTap: onProgressTap,
              ),
              _ProgressCard(
                exactWidth: exactCardWidth,
                title: 'daily_steps'.tr(),
                value: steps,
                unit: 'steps_unit'.tr(),
                icon: Icons.directions_walk_outlined,
                iconColor: const Color(0xFF34C759),
                onTap: onProgressTap,
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
  final VoidCallback onTap;
  const _ProgressCard({
    required this.exactWidth,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BouncingButton(
      onTap: onTap,
      child: Container(
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
      ),
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
    return _BouncingButton(
      onTap: onTap,
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
                label: 'home_nav'.tr(),
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
                label: 'booking_nav'.tr(),
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
                label: 'stats_nav'.tr(),
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
                label: 'chats_nav'.tr(),
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
                label: 'profile_nav'.tr(),
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
    final bool isSelected = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
