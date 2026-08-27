import 'package:jove_client/widgets/custom_loading_indicator.dart';
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
import '../services/wearable_sync_manager.dart';
import '../services/main_tab_controller.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/package_required_modal.dart';
import 'auth/package_select_screen.dart';

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
  final int initialTab;
  const HomeDashboardScreen({super.key, this.initialTab = 0});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    WearableSyncManager.instance.initialize();
    _markSessionPreviewSeen(uid);

    if (widget.initialTab != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MainTabController.switchTab(widget.initialTab);
      });
    }
  }

  void _markSessionPreviewSeen(String uid) {
    if (uid.isEmpty) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .then((doc) {
          if (doc.exists) {
            final data = doc.data() ?? {};
            final Map<String, dynamic> updates = {};
            if (data['hasSeenFirstPreview'] != true) {
              updates['hasSeenFirstPreview'] = true;
              updates['firstPreviewSeenAt'] = FieldValue.serverTimestamp();
            }
            if (data['hasPaidEntryFee'] == true &&
                data['hasSeenSecondPreview'] != true) {
              updates['hasSeenSecondPreview'] = true;
              updates['secondPreviewSeenAt'] = FieldValue.serverTimestamp();
            }
            if (updates.isNotEmpty) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .set(updates, SetOptions(merge: true));
            }
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF000000)
              : const Color(0xFFFAFAFA),
          extendBody: true,
          body: Stack(
            children: [
              // --- SWIPABLE PAGES (ZERO JANK, 120HZ SMOOTH) ---
              PageView(
                controller: MainTabController.pageController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                onPageChanged: (index) {
                  if (MainTabController.selectedIndex.value != index) {
                    HapticFeedback.selectionClick();
                    MainTabController.selectedIndex.value = index;
                  }
                },
                children: const [
                  // Page 0: Home Tab
                  _HomeTabView(),

                  // Page 1: Booking Tab
                  _BookingTabWrapper(),

                  // Page 2: Progress Tab
                  ProgressScreen(showBottomNav: false),

                  // Page 3: Chat Tab
                  ChatScreen(showBottomNav: false),

                  // Page 4: Profile Tab
                  ProfileScreen(showBottomNav: false),
                ],
              ),

              // --- PERSISTENT FLOATING BOTTOM NAV BAR ---
              if (!isKeyboardOpen)
                RepaintBoundary(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _FloatingNavBar(
                      selectedIndexNotifier: MainTabController.selectedIndex,
                      onTabTap: (index) => MainTabController.switchTab(index),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeTabView extends StatefulWidget {
  const _HomeTabView();

  @override
  State<_HomeTabView> createState() => _HomeTabViewState();
}

class _HomeTabViewState extends State<_HomeTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  late final Stream<DocumentSnapshot> _userStream;
  late final Stream<QuerySnapshot> _bookingStream;
  bool _hasActiveSubscription = false;

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
  }

  void _handleRescheduleClick(
    String bookingId,
    Map<String, dynamic> bookingData,
  ) {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Session Rescheduling');
      return;
    }
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
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Session Completion');
      return;
    }
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
    super.build(context);


    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return Center(child: CustomLoadingIndicator());
        }

        final userData =
            userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

        Timestamp? nextBillingDate = userData['subscription'] is Map
            ? userData['subscription']['nextBillingDate'] as Timestamp?
            : userData['packageEndDate'] as Timestamp?;
        bool isPackageExpired = false;
        if (nextBillingDate != null) {
          isPackageExpired = DateTime.now().isAfter(nextBillingDate.toDate());
        }

        _hasActiveSubscription =
            !isPackageExpired &&
            (userData['hasActiveSubscription'] == true ||
                (userData['subscription'] is Map &&
                    userData['subscription']['status'] == 'Active'));

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                child: _HeaderSection(
                  userData: userData,
                  onProfileTap: () => MainTabController.switchTab(4),
                ),
              ),

              if (isPackageExpired)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBB0013), Color(0xFF80000D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFBB0013).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Package Expired',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Renew or switch your membership package to resume full access.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PackageSelectScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFBB0013),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Renew',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              RepaintBoundary(
                child: _UpcomingSessionSection(
                  bookingStream: _bookingStream,
                  onReschedule: _handleRescheduleClick,
                  onComplete: _handleCompleteSession,
                ),
              ),
              RepaintBoundary(
                child: _QuickActionsSection(
                  onBookingTap: () => MainTabController.switchTab(1),
                  onHealthTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HealthProfileScreen(),
                      ),
                    );
                  },
                  onDietTap: () => MainTabController.switchTab(3),
                ),
              ),
              RepaintBoundary(
                child: _TodayProgressSection(
                  userData: userData,
                  onProgressTap: () => MainTabController.switchTab(2),
                ),
              ),
              RepaintBoundary(
                child: _DietPlansSection(
                  userId: currentUser?.uid ?? '',
                  onSeeAllTap: () => MainTabController.switchTab(3),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _BookingTabWrapper extends StatefulWidget {
  const _BookingTabWrapper();

  @override
  State<_BookingTabWrapper> createState() => _BookingTabWrapperState();
}

class _BookingTabWrapperState extends State<_BookingTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Stream<DocumentSnapshot> _userStream;
  late final Stream<QuerySnapshot> _trainersStream;

  @override
  void initState() {
    super.initState();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
    _trainersStream = FirebaseFirestore.instance
        .collection('trainers')
        .limit(1)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        final userData =
            userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final String? assignedTrainerId = userData['assignedTrainerId'];
        if (assignedTrainerId != null && assignedTrainerId.isNotEmpty) {
          return BookingScreen(
            trainerId: assignedTrainerId,
            showBottomNav: false,
          );
        }

        // Preview Mode fallback: Load default/featured trainer so user can preview the booking interface
        return StreamBuilder<QuerySnapshot>(
          stream: _trainersStream,
          builder: (context, trainerSnapshot) {
            final docs = trainerSnapshot.data?.docs ?? [];
            if (docs.isNotEmpty) {
              return BookingScreen(
                trainerId: docs.first.id,
                showBottomNav: false,
              );
            }
            return const SelectTrainerScreen();
          },
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onProfileTap;

  const _HeaderSection({required this.userData, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    String rawUserName =
        userData['fullName'] ??
        userData['name'] ??
        userData['firstName'] ??
        currentUser?.displayName ??
        '';
    final String userName = rawUserName.trim().isNotEmpty
        ? rawUserName
        : 'athlete_fallback'.tr();
    final String profilePic =
        userData['photoURL'] ??
        userData['photoUrl'] ??
        userData['profilePic'] ??
        userData['imageUrl'] ??
        currentUser?.photoURL ??
        '';
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todayDate,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: TextStyle(
                    color: AppThemeController.isDark
                        ? const Color(0xFFF5F5F5)
                        : Colors.black87,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _BouncingButton(
            onTap: onProfileTap,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppThemeController.isDark
                      ? const Color(0xFF262626)
                      : Colors.white,
                  width: 2,
                ),
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
                onBackgroundImageError: profilePic.isNotEmpty
                    ? (_, _) {}
                    : null,
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
                    Expanded(
                      child: Text(
                        cardHeaderTitle,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasBooking) ...[
                      const SizedBox(width: 8),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

class _DietPlansSection extends StatefulWidget {
  final String userId;
  final VoidCallback onSeeAllTap;

  const _DietPlansSection({required this.userId, required this.onSeeAllTap});

  @override
  State<_DietPlansSection> createState() => _DietPlansSectionState();
}

class _DietPlansSectionState extends State<_DietPlansSection> {
  Stream<QuerySnapshot>? _clientDietPlansStream;
  late final Stream<QuerySnapshot> _dietPlanTemplatesStream;
  late final Stream<QuerySnapshot> _legacyDietPlansStream;

  @override
  void initState() {
    super.initState();
    if (widget.userId.isNotEmpty) {
      _clientDietPlansStream = FirebaseFirestore.instance
          .collection('clientDietPlans')
          .where('clientId', isEqualTo: widget.userId)
          .snapshots();
    }
    _dietPlanTemplatesStream = FirebaseFirestore.instance
        .collection('dietPlanTemplates')
        .limit(10)
        .snapshots();
    _legacyDietPlansStream = FirebaseFirestore.instance
        .collection('diet_plans')
        .limit(10)
        .snapshots();
  }

  // --- FETCH TEMPLATE + SUBCOLLECTION MEALS FROM FIREBASE ---
  static Future<Map<String, dynamic>> _fetchDietPlanData(
    String templateId,
    Map<String, dynamic> fallbackData,
  ) async {
    try {
      if (templateId.isNotEmpty) {
        final docSnap = await FirebaseFirestore.instance
            .collection('dietPlanTemplates')
            .doc(templateId)
            .get();

        if (docSnap.exists) {
          final mealsSnap = await FirebaseFirestore.instance
              .collection('dietPlanTemplates')
              .doc(templateId)
              .collection('meals')
              .get();

          final data = docSnap.data() ?? <String, dynamic>{};
          if (mealsSnap.docs.isNotEmpty) {
            data['meals'] = mealsSnap.docs.map((d) => d.data()).toList();
          }
          return data;
        }
      }
      return fallbackData;
    } catch (e) {
      return fallbackData;
    }
  }

  // --- HYPER-AGGRESSIVE MEAL EXTRACTION ---
  static List<dynamic> _extractMealsAggressively(Map<String, dynamic> data) {
    final possibleKeys = [
      'meals',
      'mealSequence',
      'mealPlan',
      'schedule',
      'dailyMeals',
      'items',
      'foodItems',
      'meal',
      'sequence',
      'list',
    ];

    for (String key in possibleKeys) {
      if (data[key] != null) {
        if (data[key] is List) {
          return data[key] as List<dynamic>;
        } else if (data[key] is Map) {
          return (data[key] as Map).values.toList();
        }
      }
    }

    for (var val in data.values) {
      if (val is List && val.isNotEmpty && val.first is Map) {
        return val;
      } else if (val is Map && val.isNotEmpty && val.values.first is Map) {
        return val.values.toList();
      }
    }

    return [];
  }

  static void _showDietPlanDashboard(
    BuildContext context,
    String templateId,
    String title,
    Map<String, dynamic> rawData,
  ) {
    final bool isDark = AppThemeController.isDark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              // Handle Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF333333)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFF00225D).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: isDark
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF00225D),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFF5F5F5)
                              : const Color(0xFF1A1A1A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 16,
                color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
              ),

              // Fetch Data & Display Dashboard
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _fetchDietPlanData(templateId, rawData),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CustomLoadingIndicator());
                    }

                    var data = snapshot.data ?? rawData;

                    String calories = data['calories']?.toString() ?? '0';
                    String protein = data['protein']?.toString() ?? '0';
                    String fats =
                        data['fat']?.toString() ??
                        data['fats']?.toString() ??
                        '0';
                    String carbs =
                        data['carbs']?.toString() ??
                        data['netCarbsLimit']?.toString() ??
                        '0';

                    String fastingWindow =
                        data['fastingWindow']?.toString() ?? '';
                    String hydrationGoal =
                        data['hydrationGoal']?.toString() ?? '';
                    List<dynamic> prohibitions = data['prohibitions'] ?? [];

                    List<dynamic> meals = _extractMealsAggressively(data);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. MACRO STATS GRID
                          Row(
                            children: [
                              Expanded(
                                child: _buildMacroCard(
                                  "Daily Calories",
                                  calories,
                                  "kcal",
                                  Icons.local_fire_department,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMacroCard(
                                  "Protein",
                                  protein,
                                  "g",
                                  Icons.fitness_center,
                                  isDark
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF00225D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMacroCard(
                                  "Healthy Fats",
                                  fats,
                                  "g",
                                  Icons.water_drop_outlined,
                                  Colors.lightBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMacroCard(
                                  "Net Carbs",
                                  carbs,
                                  "g",
                                  Icons.eco_outlined,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 2. EXTRA INFO
                          if (fastingWindow.isNotEmpty ||
                              hydrationGoal.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fastingWindow.isNotEmpty)
                                  Expanded(
                                    child: _buildInfoCard(
                                      "Fasting Window",
                                      fastingWindow,
                                      "Fasting Protocol",
                                      Colors.indigo.shade100,
                                    ),
                                  ),
                                if (fastingWindow.isNotEmpty &&
                                    hydrationGoal.isNotEmpty)
                                  const SizedBox(width: 12),
                                if (hydrationGoal.isNotEmpty)
                                  Expanded(
                                    child: _buildInfoCard(
                                      "Hydration Goal",
                                      hydrationGoal,
                                      "Include electrolytes",
                                      Colors.cyan.shade100,
                                    ),
                                  ),
                              ],
                            ),

                          if (prohibitions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF262626)
                                      : Colors.grey.shade200,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Prohibitions",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? const Color(0xFFF5F5F5)
                                          : const Color(0xFF00225D),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...prohibitions.map(
                                    (rule) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.cancel_outlined,
                                            color: Color(0xFFBA0C19),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              rule.toString(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? const Color(0xFFE5E5E5)
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),
                          Text(
                            "Meal Sequence",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFF5F5F5)
                                  : const Color(0xFF00225D),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. MEAL SEQUENCE LIST
                          if (meals.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Balanced meals scheduled for this plan.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFA8A8A8)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ] else ...[
                            ...meals.map((mealData) {
                              if (mealData is! Map) {
                                return const SizedBox();
                              }

                              final m = mealData as Map<String, dynamic>;

                              final name =
                                  m['name'] ??
                                  m['mealName'] ??
                                  m['meal'] ??
                                  m['title'] ??
                                  '-';
                              final time = m['time'] ?? m['mealTime'] ?? '';
                              final items =
                                  m['ingredients'] ??
                                  m['items'] ??
                                  m['food'] ??
                                  m['description'] ??
                                  '-';
                              final mealImage =
                                  m['image'] ??
                                  m['imageUrl'] ??
                                  m['photoUrl'] ??
                                  m['imageURL'] ??
                                  '';

                              String p =
                                  m['protein']?.toString() ??
                                  m['p']?.toString() ??
                                  '0';
                              String c =
                                  m['carbs']?.toString() ??
                                  m['c']?.toString() ??
                                  '0';
                              String f =
                                  m['fats']?.toString() ??
                                  m['fat']?.toString() ??
                                  m['f']?.toString() ??
                                  '0';

                              if (m['macros'] != null && m['macros'] is Map) {
                                final mac = m['macros'] as Map;
                                p = mac['protein']?.toString() ?? p;
                                c = mac['carbs']?.toString() ?? c;
                                f =
                                    mac['fats']?.toString() ??
                                    mac['fat']?.toString() ??
                                    f;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF262626)
                                        : Colors.grey.shade200,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF262626)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: mealImage.toString().isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                mealImage.toString(),
                                                cacheWidth: 300,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Icon(
                                                      Icons.restaurant_rounded,
                                                      color: isDark
                                                          ? Colors.grey.shade600
                                                          : Colors.grey,
                                                    ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.restaurant_rounded,
                                              color: isDark
                                                  ? Colors.grey.shade600
                                                  : Colors.grey,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isDark
                                                  ? const Color(0xFFF5F5F5)
                                                  : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          if (time.toString().isNotEmpty)
                                            Text(
                                              time.toString(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? const Color(0xFFA8A8A8)
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            items.toString(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? const Color(0xFFD4D4D4)
                                                  : Colors.grey.shade700,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "P: ${p}g  •  C: ${c}g  •  F: ${f}g",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? const Color(0xFFA8A8A8)
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildMacroCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    final bool isDark = AppThemeController.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFA8A8A8)
                        : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? const Color(0xFFF5F5F5)
                      : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFA8A8A8)
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoCard(
    String title,
    String value,
    String subtitle,
    Color accentColor,
  ) {
    final bool isDark = AppThemeController.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppThemeController.isDark;
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF5F5F5) : Colors.black87,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSeeAllTap,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: isDark ? const Color(0xFFF5F5F5) : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 94,
          child: StreamBuilder<QuerySnapshot>(
            stream: _clientDietPlansStream,
            builder: (context, clientSnap) {
              final clientDocs = clientSnap.data?.docs ?? [];
              if (clientDocs.isNotEmpty) {
                return _buildDietList(context, clientDocs, isClientPlan: true);
              }

              // Fallback to dietPlanTemplates
              return StreamBuilder<QuerySnapshot>(
                stream: _dietPlanTemplatesStream,
                builder: (context, tplSnap) {
                  final tplDocs = tplSnap.data?.docs ?? [];
                  if (tplDocs.isNotEmpty) {
                    return _buildDietList(
                      context,
                      tplDocs,
                      isClientPlan: false,
                    );
                  }

                  // Fallback to legacy diet_plans
                  return StreamBuilder<QuerySnapshot>(
                    stream: _legacyDietPlansStream,
                    builder: (context, legSnap) {
                      final legDocs = legSnap.data?.docs ?? [];
                      if (legDocs.isNotEmpty) {
                        return _buildDietList(
                          context,
                          legDocs,
                          isClientPlan: false,
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF121212)
                              : const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF262626)
                                : Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu_rounded,
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'no_diet_plans'.tr(),
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFA8A8A8)
                                    : Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDietList(
    BuildContext context,
    List<QueryDocumentSnapshot> docs, {
    required bool isClientPlan,
  }) {
    final bool isDark = AppThemeController.isDark;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;

        final String title =
            data['templateName'] ??
            data['title'] ??
            data['name'] ??
            'Diet Plan';
        final String templateId = data['templateId']?.toString() ?? doc.id;

        String subtitle = 'Active Plan';
        if (data['calories'] != null) {
          subtitle = '${data['calories']} kcal';
        } else if (data['goal'] != null) {
          subtitle = data['goal'].toString();
        } else if (data['category'] != null) {
          subtitle = data['category'].toString();
        } else if (data['assignedAt'] != null) {
          subtitle = _Formatters.fullDate.format(
            (data['assignedAt'] as Timestamp).toDate(),
          );
        } else if (data['createdAt'] != null) {
          subtitle = _Formatters.fullDate.format(
            (data['createdAt'] as Timestamp).toDate(),
          );
        }

        return _BouncingButton(
          onTap: () {
            HapticFeedback.lightImpact();
            _showDietPlanDashboard(context, templateId, title, data);
          },
          child: Container(
            width: 260,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
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
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: isDark
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF2E7D32),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFFF5F5F5)
                              : Colors.black87,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFA8A8A8)
                              : Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppThemeController.isDark
                  ? const Color(0xFFF5F5F5)
                  : Colors.black87,
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
    final String today = _Formatters.date.format(DateTime.now());

    final dailyWeightMap = userData['dailyWeight'] as Map<String, dynamic>?;
    final String weight =
        dailyWeightMap?[today]?.toString() ??
        userData['weight']?.toString() ??
        '0';

    final dailySleepMap = userData['dailySleep'] as Map<String, dynamic>?;
    final String sleep = dailySleepMap?[today]?.toString() ?? '0';

    final dailyStepsMap = userData['dailySteps'] as Map<String, dynamic>?;
    final String steps = dailyStepsMap?[today]?.toString() ?? '0';

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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppThemeController.isDark
                      ? const Color(0xFFF5F5F5)
                      : Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: onProgressTap,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppThemeController.isDark
                      ? const Color(0xFFF5F5F5)
                      : Colors.black87,
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
                title: 'Activity',
                subtitle: steps != '0' ? '$steps steps' : '+3 points',
                icon: Icons.directions_run_rounded,
                cardBgColor: const Color(0xFFFEF3C7),
                darkCardBgColor: const Color(0xFF261D02),
                darkBorderColor: const Color(0xFF8C6D08),
                iconColor: const Color(0xFF8C7000),
                darkIconColor: const Color(0xFFFFC107),
                titleColor: const Color(0xFF5A4400),
                subtitleColor: const Color(0xFF8A6D00),
                darkSubtitleColor: const Color(0xFFFFD54F),
                onTap: onProgressTap,
              ),
              _ProgressCard(
                title: 'Body',
                subtitle: weight != '0' ? '$weight kg' : '+1 point',
                icon: Icons.accessibility_new_rounded,
                cardBgColor: const Color(0xFFEDE9FE),
                darkCardBgColor: const Color(0xFF1E1238),
                darkBorderColor: const Color(0xFF6D3FB8),
                iconColor: const Color(0xFF5B3FB0),
                darkIconColor: const Color(0xFFA78BFA),
                titleColor: const Color(0xFF331F75),
                subtitleColor: const Color(0xFF5B3FB0),
                darkSubtitleColor: const Color(0xFFDDD6FE),
                onTap: onProgressTap,
              ),
              _ProgressCard(
                title: 'Hydration',
                subtitle: hydration != '0' ? '$hydration L' : '+2 points',
                icon: Icons.water_drop_rounded,
                cardBgColor: const Color(0xFFE0F2FE),
                darkCardBgColor: const Color(0xFF032238),
                darkBorderColor: const Color(0xFF0284C7),
                iconColor: const Color(0xFF0284C7),
                darkIconColor: const Color(0xFF38BDF8),
                titleColor: const Color(0xFF075985),
                subtitleColor: const Color(0xFF0369A1),
                darkSubtitleColor: const Color(0xFF7DD3FC),
                onTap: onProgressTap,
              ),
              _ProgressCard(
                title: 'Sleep',
                subtitle: sleep != '0' ? '$sleep hrs' : '+1 point',
                icon: Icons.nightlight_round,
                cardBgColor: const Color(0xFFF3E8FF),
                darkCardBgColor: const Color(0xFF260D38),
                darkBorderColor: const Color(0xFF9333EA),
                iconColor: const Color(0xFF7E22CE),
                darkIconColor: const Color(0xFFC084FC),
                titleColor: const Color(0xFF581C87),
                subtitleColor: const Color(0xFF7E22CE),
                darkSubtitleColor: const Color(0xFFE879F9),
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
  final String title;
  final String subtitle;
  final IconData icon;
  final Color cardBgColor;
  final Color darkCardBgColor;
  final Color darkBorderColor;
  final Color iconColor;
  final Color darkIconColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color darkSubtitleColor;
  final VoidCallback onTap;

  const _ProgressCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cardBgColor,
    required this.darkCardBgColor,
    required this.darkBorderColor,
    required this.iconColor,
    required this.darkIconColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.darkSubtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppThemeController.isDark;
    return _BouncingButton(
      onTap: onTap,
      child: Container(
        width: 155,
        height: 140,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? darkCardBgColor : cardBgColor,
          borderRadius: BorderRadius.circular(22),
          border: isDark
              ? Border.all(
                  color: darkBorderColor.withValues(alpha: 0.5),
                  width: 1.4,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? darkBorderColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isDark ? 12 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? darkBorderColor.withValues(alpha: 0.25)
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDark ? darkIconColor : iconColor,
                size: 24,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : titleColor.withValues(alpha: 0.85),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? darkSubtitleColor : subtitleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
  final Function(int) onTabTap;

  const _FloatingNavBar({
    required this.selectedIndexNotifier,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeController.isDark
            ? const Color(0xFF121212)
            : const Color.fromARGB(255, 0, 33, 95),
        borderRadius: BorderRadius.circular(40),
        border: AppThemeController.isDark
            ? Border.all(color: const Color(0xFF262626), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppThemeController.isDark ? 0.35 : 0.15,
            ),
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
                  HapticFeedback.selectionClick();
                  onTabTap(0);
                },
              ),
              _NavItem(
                index: 1,
                icon: Icons.calendar_today_rounded,
                label: 'booking_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabTap(1);
                },
              ),
              _NavItem(
                index: 2,
                icon: Icons.bar_chart_rounded,
                label: 'stats_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabTap(2);
                },
              ),
              _NavItem(
                index: 3,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'chats_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabTap(3);
                },
              ),
              _NavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                label: 'profile_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabTap(4);
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
    bool isSelected = selectedIndex == index;
    return Expanded(
      flex: isSelected ? 4 : 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            padding: isSelected
                ? const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0)
                : const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.white70,
                  size: 20,
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
