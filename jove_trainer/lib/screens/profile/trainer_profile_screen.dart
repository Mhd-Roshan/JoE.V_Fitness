import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'contact_admin_screen.dart';
import 'app_settings_screen.dart';
import 'trainer_client_reviews_screen.dart';
import '../auth/login_screen.dart';
import '../notifications/trainer_notifications_screen.dart';

import '../../services/language_service.dart';
import '../home/trainer_main_screen.dart';

import '../../services/trainer_data_service.dart';

class TrainerProfileScreen extends StatefulWidget {
  final bool isEmbeddedInShell;
  const TrainerProfileScreen({super.key, this.isEmbeddedInShell = false});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen>
    with AutomaticKeepAliveClientMixin {
  // Keep brand specific colors static
  static const Color primaryRed = Color(0xFFC7001A);

  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  String _fullName = '';
  String _designation = '';
  String _yearsExperience = '0';
  String _phone = '';
  String _email = '';
  String _specializations = '';
  String _profileImageUrl = '';
  int _clientCount = 0;
  int _totalSessions = 0;
  int _totalWorkouts = 0; // Added Workouts
  String _rating = '0.0';
  List<Map<String, dynamic>> _feedbacks = [];

  @override
  void initState() {
    super.initState();
    if (TrainerDataService().isInitialized) {
      _parseFromCache();
      _loadProfileData(showSpinner: false);
    } else {
      _loadProfileData(showSpinner: true);
    }
  }

  void _parseFromCache() {
    final cache = TrainerDataService();
    if (!cache.isInitialized) return;
    _processDocs(
      cache.trainerUserData,
      cache.trainerDocData,
      cache.myTrainerIds,
      cache.myTrainerNames,
      cache.myTrainerEmails,
      cache.myTrainerPhones,
      cache.allUsersDocs,
      cache.allTrainersDocs,
      cache.allSessionsDocs,
      cache.allBookingsDocs,
      cache.allWorkoutsDocs,
      cache.allPlansDocs,
      cache.allFeedbacksDocs,
      cache.allReviewsDocs,
    );
  }

  Future<void> _loadProfileData({bool showSpinner = true, bool force = false}) async {
    if (showSpinner && _fullName.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
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
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processDocs(
    Map<String, dynamic> userData,
    Map<String, dynamic> directTrainerData,
    Set<String> myTrainerIds,
    Set<String> myTrainerNames,
    Set<String> myTrainerEmails,
    Set<String> myTrainerPhones,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allUsersDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allTrainersDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workoutsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plansDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> feedbacksDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviewsDocs,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    final userEmail = user?.email;

    try {
      Map<String, dynamic> trainerData = Map<String, dynamic>.from(directTrainerData);

      if (userData['fullName'] != null) {
        final fn = userData['fullName'].toString().toLowerCase().trim();
        myTrainerNames.add(fn);
        for (final part in fn.split(' ')) {
          if (part.length > 1) myTrainerNames.add(part);
        }
      }
      if (userData['name'] != null) {
        final n = userData['name'].toString().toLowerCase().trim();
        myTrainerNames.add(n);
        for (final part in n.split(' ')) {
          if (part.length > 1) myTrainerNames.add(part);
        }
      }
      if (userData['email'] != null) {
        myTrainerEmails.add(userData['email'].toString().toLowerCase().trim());
      }
      if (userData['phone'] != null || userData['phoneNumber'] != null) {
        final p = (userData['phone'] ?? userData['phoneNumber']).toString().trim();
        if (p.isNotEmpty) myTrainerPhones.add(p);
      }
      if (userData['trainerId'] != null) {
        myTrainerIds.add(userData['trainerId'].toString().trim());
      }
      if (userData['id'] != null) {
        myTrainerIds.add(userData['id'].toString().trim());
      }

      // 2. Fetch Trainer Profile Docs & match all trainers in collection
      for (var tDoc in allTrainersDocs) {
        final tData = tDoc.data();
        final tEmail = (tData['email'] ?? '').toString().toLowerCase().trim();
        final tName = (tData['fullName'] ?? tData['name'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final tUserId = (tData['userId'] ?? tData['authUid'] ?? tData['uid'] ?? '')
            .toString()
            .trim();
        final tPhone =
            (tData['phone'] ?? tData['phoneNumber'] ?? '').toString().trim();

        bool isMe = tDoc.id == uid ||
            (tUserId.isNotEmpty && tUserId == uid) ||
            (userEmail != null &&
                tEmail.isNotEmpty &&
                tEmail == userEmail.toLowerCase().trim()) ||
            (myTrainerEmails.isNotEmpty &&
                tEmail.isNotEmpty &&
                myTrainerEmails.contains(tEmail)) ||
            (myTrainerPhones.isNotEmpty &&
                tPhone.isNotEmpty &&
                myTrainerPhones.contains(tPhone)) ||
            (myTrainerNames.isNotEmpty &&
                tName.isNotEmpty &&
                myTrainerNames.any((n) =>
                    n.isNotEmpty &&
                    (tName == n || tName.contains(n) || n.contains(tName)))) ||
            (allTrainersDocs.length == 1);

        if (isMe) {
          if (trainerData.isEmpty) {
            trainerData = tData;
          }
          myTrainerIds.add(tDoc.id);
          if (tData['trainerId'] != null) {
            myTrainerIds.add(tData['trainerId'].toString().trim());
          }
          if (tData['id'] != null) {
            myTrainerIds.add(tData['id'].toString().trim());
          }
          if (tName.isNotEmpty) {
            myTrainerNames.add(tName);
            for (final part in tName.split(' ')) {
              if (part.length > 1) myTrainerNames.add(part);
            }
          }
          if (tEmail.isNotEmpty) myTrainerEmails.add(tEmail);
          if (tPhone.isNotEmpty) myTrainerPhones.add(tPhone);
        }
      }

      // 3. Count Unique Assigned Clients across users, bookings, and sessions
      final Set<String> assignedClientIds = {};

      for (var uDoc in allUsersDocs) {
        if (uDoc.id == uid) continue;
        final uData = uDoc.data();
          final role = (uData['role'] ?? '').toString().toLowerCase();
          if (role == 'trainer' || role == 'admin') continue;

          final assignedTId = (uData['assignedTrainerId'] ??
                  uData['trainerId'] ??
                  uData['trainer_id'] ??
                  '')
              .toString()
              .trim();
          final assignedTName = (uData['assignedTrainerName'] ??
                  uData['trainerName'] ??
                  uData['trainer'] ??
                  '')
              .toString()
              .toLowerCase()
              .trim();

          bool isAssigned = (assignedTId.isNotEmpty &&
                  myTrainerIds.contains(assignedTId)) ||
              (assignedTName.isNotEmpty &&
                  myTrainerNames.any((n) =>
                      n.isNotEmpty &&
                      (assignedTName == n ||
                          assignedTName.contains(n) ||
                          n.contains(assignedTName))));

          if (isAssigned) {
            assignedClientIds.add(uDoc.id);
          }
        }

      // 4. Count Unique Sessions & Client Bookings
      final Set<String> uniqueSessionIds = {};
      int sessionsCount = 0;
      int completedSessionsCount = 0;

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> combinedSessions = [];
      combinedSessions.addAll(sessionsDocs);
      combinedSessions.addAll(bookingsDocs);

      for (var doc in combinedSessions) {
        final data = doc.data();
        final tId = (data['trainerId'] ??
                data['trainer_id'] ??
                data['assignedTrainerId'] ??
                '')
            .toString()
            .trim();
        final tName = (data['trainerName'] ??
                data['trainer'] ??
                data['assignedTrainerName'] ??
                '')
            .toString()
            .toLowerCase()
            .trim();

        bool isMySession = (tId.isNotEmpty && myTrainerIds.contains(tId)) ||
            (tName.isNotEmpty &&
                myTrainerNames.any((n) =>
                    n.isNotEmpty &&
                    (tName == n || tName.contains(n) || n.contains(tName)))) ||
            (tId.isEmpty && tName.isEmpty);

        if (isMySession) {
          final key = data['bookingId'] ?? data['sessionId'] ?? doc.id;
          if (!uniqueSessionIds.contains(key)) {
            uniqueSessionIds.add(key);
            sessionsCount++;

            final clientId = (data['clientId'] ?? data['userId'] ?? '')
                .toString()
                .trim();
            if (clientId.isNotEmpty && clientId != uid) {
              assignedClientIds.add(clientId);
            }

            final status =
                (data['status'] ?? '').toString().toLowerCase().trim();
            if (status == 'completed' || status == 'done') {
              completedSessionsCount++;
            }
          }
        }
      }

      // 5. Fetch Workouts Count (Strictly Real Data from Firestore)
      int workoutsCount = 0;
      for (var doc in workoutsDocs) {
        final data = doc.data();
        final tId = (data['trainerId'] ?? data['createdBy'] ?? data['userId'] ?? '')
            .toString()
            .trim();
        final tName = (data['trainerName'] ?? data['trainer'] ?? '')
            .toString()
            .toLowerCase()
            .trim();

        if (tId.isNotEmpty && myTrainerIds.contains(tId) ||
            (tName.isNotEmpty &&
                myTrainerNames.any((n) =>
                    n.isNotEmpty &&
                    (tName == n || tName.contains(n) || n.contains(tName))))) {
          workoutsCount++;
        }
      }

      for (var doc in plansDocs) {
        final data = doc.data();
        final tId = (data['trainerId'] ?? data['createdBy'] ?? data['userId'] ?? '')
            .toString()
            .trim();
        final tName = (data['trainerName'] ?? data['trainer'] ?? '')
            .toString()
            .toLowerCase()
            .trim();

        if (tId.isNotEmpty && myTrainerIds.contains(tId) ||
            (tName.isNotEmpty &&
                myTrainerNames.any((n) =>
                    n.isNotEmpty &&
                    (tName == n || tName.contains(n) || n.contains(tName))))) {
          workoutsCount++;
        }
      }

      // If no explicit standalone workout documents, count completed workout sessions from database
      if (workoutsCount == 0 && completedSessionsCount > 0) {
        workoutsCount = completedSessionsCount;
      }

      // 6. Fetch Feedbacks & Calculate Live Accurate Rating (Strictly Real Data)
      List<Map<String, dynamic>> feedbackList = [];
      double totalRatingSum = 0;
      int ratingCount = 0;

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> combinedFeedbacks = [];
      combinedFeedbacks.addAll(feedbacksDocs);
      combinedFeedbacks.addAll(reviewsDocs);

      for (var doc in combinedFeedbacks) {
        final data = doc.data();
        final tId = (data['trainerId'] ?? data['targetId'] ?? data['trainer_id'] ?? '')
            .toString()
            .trim();
        final tName = (data['trainerName'] ?? data['trainer'] ?? '')
            .toString()
            .toLowerCase()
            .trim();

        bool isMyFeedback = (tId.isNotEmpty && myTrainerIds.contains(tId)) ||
            (tName.isNotEmpty &&
                myTrainerNames.any((n) =>
                    n.isNotEmpty &&
                    (tName == n || tName.contains(n) || n.contains(tName))));

        if (isMyFeedback) {
          feedbackList.add(data);
          final r = data['rating'] ?? data['stars'] ?? data['score'] ?? data['rate'];
          if (r != null) {
            final numVal = num.tryParse(r.toString());
            if (numVal != null && numVal > 0) {
              totalRatingSum += numVal;
              ratingCount++;
            }
          }
        }
      }

      String calculatedRating = '0.0';
      if (ratingCount > 0) {
        calculatedRating = (totalRatingSum / ratingCount).toStringAsFixed(1);
      } else if (trainerData['rating'] != null) {
        final r = num.tryParse(trainerData['rating'].toString());
        if (r != null && r > 0) {
          calculatedRating = r.toDouble().toStringAsFixed(1);
        }
      }

      // 7. Resolve Profile Photo
      final resolvedPhoto = (trainerData['photoUrl'] ??
              trainerData['photoURL'] ??
              trainerData['profileImageUrl'] ??
              trainerData['profileImage'] ??
              trainerData['image'] ??
              trainerData['imageUrl'] ??
              trainerData['avatar'] ??
              userData['photoUrl'] ??
              userData['photoURL'] ??
              userData['profileImageUrl'] ??
              userData['profileImage'] ??
              userData['image'] ??
              userData['imageUrl'] ??
              user?.photoURL ??
              '')
          .toString()
          .trim();

      // 8. Resolve Phone Number (Strictly Real Data from Firebase)
      String resolvedPhone = '';
      for (final source in [trainerData, userData]) {
        for (final key in [
          'phone',
          'phoneNumber',
          'contactNumber',
          'mobile',
          'contact',
          'telephone',
        ]) {
          final val = source[key]?.toString().trim();
          if (val != null &&
              val.isNotEmpty &&
              val != '—' &&
              val != 'null' &&
              val != 'undefined') {
            resolvedPhone = val;
            break;
          }
        }
        if (resolvedPhone.isNotEmpty) break;
      }

      if (resolvedPhone.isEmpty && myTrainerPhones.isNotEmpty) {
        resolvedPhone = myTrainerPhones.first;
      }

      if (resolvedPhone.isEmpty &&
          user?.phoneNumber != null &&
          user!.phoneNumber!.isNotEmpty) {
        resolvedPhone = user.phoneNumber!;
      }

      if (resolvedPhone.isEmpty) {
        for (var uDoc in allUsersDocs) {
          final data = uDoc.data();
          if ((data['role'] ?? '').toString().toLowerCase() != 'trainer') continue;
          final email = (data['email'] ?? '').toString().toLowerCase().trim();
          final name = (data['fullName'] ?? data['name'] ?? '').toString().toLowerCase().trim();
          if (uDoc.id == uid ||
              (userEmail != null && email == userEmail.toLowerCase().trim()) ||
              (name.isNotEmpty && myTrainerNames.contains(name))) {
            final p = (data['phone'] ??
                    data['phoneNumber'] ??
                    data['mobile'] ??
                    data['contact'])
                ?.toString()
                .trim();
            if (p != null && p.isNotEmpty && p != '—' && p != 'null') {
              resolvedPhone = p;
              break;
            }
          }
        }
      }

      // 9. Resolve Specializations (Strictly Real Data from Firebase)
      final specs = trainerData['specializations'] ??
          trainerData['specialization'] ??
          trainerData['expertise'] ??
          trainerData['skills'] ??
          userData['specializations'] ??
          userData['specialization'] ??
          userData['expertise'] ??
          userData['skills'];

      String resolvedSpecs = '';
      if (specs is List && specs.isNotEmpty) {
        resolvedSpecs = specs
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .join(', ');
      } else if (specs is String && specs.trim().isNotEmpty) {
        resolvedSpecs = specs.trim();
      }

      // 10. Resolve Designation & Experience
      final resolvedDesignation = (trainerData['designation'] ??
              trainerData['role'] ??
              trainerData['title'] ??
              userData['designation'] ??
              userData['role'] ??
              '')
          .toString()
          .toUpperCase();

      final resolvedExperience = (trainerData['yearsExperience'] ??
              trainerData['experience'] ??
              trainerData['experienceYears'] ??
              userData['yearsExperience'] ??
              userData['experience'] ??
              '')
          .toString();

      if (mounted) {
        setState(() {
          _fullName = (trainerData['fullName'] ??
                  trainerData['name'] ??
                  userData['fullName'] ??
                  userData['name'] ??
                  user?.displayName ??
                  'Trainer')
              .toString();
          _phone = resolvedPhone;
          _email = (trainerData['email'] ??
                  userData['email'] ??
                  userEmail ??
                  'trainer@joevfitness.com')
              .toString();
          _profileImageUrl = resolvedPhoto;
          _designation = resolvedDesignation;
          _yearsExperience = resolvedExperience;
          _specializations = resolvedSpecs;
          _rating = calculatedRating;
          _clientCount = assignedClientIds.length;
          _totalSessions = sessionsCount;
          _totalWorkouts = workoutsCount;
          _feedbacks = feedbackList.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignOut(Map<String, String> strings) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).cardColor;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          strings['signOut'] ?? 'Sign Out',
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: Text(
          strings['signOutConfirm'] ?? 'Are you sure you want to sign out?',
          style: GoogleFonts.workSans(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              strings['cancel'] ?? 'Cancel',
              style: GoogleFonts.workSans(color: subTextColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                TrainerDataService().clear();
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                debugPrint("Error signing out from Firebase: $e");
              } finally {
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            child: Text(
              strings['signOut'] ?? 'Sign Out',
              style: GoogleFonts.workSans(
                color: primaryRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = languageService.strings;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final brandBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: widget.isEmbeddedInShell
          ? null
          : _BottomNav(currentIndex: 4, strings: strings),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: brandBlue))
          : Column(
              children: [
                const _TopHeaderBand(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        _buildProfileHeader(),
                        const SizedBox(height: 24),
                        // Changed to a 2x2 layout to accommodate Workouts
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      strings['clients'] ?? 'Clients',
                                      _clientCount.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatCard(
                                      strings['sessions'] ?? 'Sessions',
                                      _totalSessions.toString(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      strings['workouts'] ?? 'Workouts',
                                      _totalWorkouts.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatCard(
                                      strings['rating'] ?? 'Rating',
                                      _rating,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildPersonalInfoCard(strings),
                        ),
                        const SizedBox(height: 32),
                        _buildFeedbackSection(strings),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              _buildMenuOption(
                                icon: Icons.group_outlined,
                                title: strings['myClient'] ?? 'My Client',
                                subtitle:
                                    '$_clientCount ${strings['usersAssigned'] ?? 'users assigned'}',
                                onTap: () =>
                                    TrainerMainScreen.switchTab(context, 2),
                              ),
                              const SizedBox(height: 12),
                              _buildMenuOption(
                                icon: Icons.call_outlined,
                                title:
                                    strings['contactAdmin'] ?? 'Contact admin',
                                subtitle:
                                    strings['reportIssue'] ??
                                    'Report issue or request leave',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ContactAdminScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildMenuOption(
                                icon: Icons.settings_outlined,
                                title: strings['appSettings'] ?? 'App Settings',
                                subtitle:
                                    strings['appSettingsDesc'] ??
                                    'Language, notifications',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AppSettingsScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleSignOut(strings),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                strings['signOut'] ?? 'SIGN OUT',
                                style: GoogleFonts.workSans(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final brandBlue = Theme.of(context).colorScheme.primary;
    final dividerColor = Theme.of(context).dividerColor;

    String initials = '?';
    if (_fullName.isNotEmpty) {
      final parts = _fullName.trim().split(' ');
      initials = parts.first[0].toUpperCase();
      if (parts.length > 1) initials += parts.last[0].toUpperCase();
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: brandBlue, width: 3),
              ),
              child: ClipOval(
                child: Container(
                  width: 92,
                  height: 92,
                  color: dividerColor,
                  child: _profileImageUrl.isNotEmpty
                      ? Image.network(
                          _profileImageUrl,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.workSans(
                                  fontSize: 32,
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: brandBlue,
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.workSans(
                              fontSize: 32,
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified, color: brandBlue, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _fullName.isNotEmpty ? _fullName : 'Trainer Profile',
          style: GoogleFonts.workSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        if (_designation.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _designation,
            style: GoogleFonts.workSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: subTextColor,
              letterSpacing: 1.0,
            ),
          ),
        ],
        if (_yearsExperience != '0' && _yearsExperience.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '$_yearsExperience Years Professional Experience',
            style: GoogleFonts.workSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: brandBlue,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            decoration: const BoxDecoration(
              color: primaryRed,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.workSans(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.workSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(Map<String, String> strings) {
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings['personalInfo'] ?? 'Personal Information',
            style: GoogleFonts.workSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: dividerColor, thickness: 1),
          ),
          _buildInfoRow(
            Icons.phone_outlined,
            strings['phone'] ?? 'PHONE',
            _phone.isNotEmpty ? _phone : 'Not provided',
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.mail_outline_rounded,
            strings['email'] ?? 'EMAIL',
            _email.isNotEmpty ? _email : 'Not provided',
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.fitness_center_outlined, // Icon representing specialties
            strings['specializations'] ?? 'SPECIALIZATIONS',
            _specializations.isNotEmpty ? _specializations : 'Not provided',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final brandBlue = Theme.of(context).colorScheme.primary;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, color: brandBlue, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.workSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: subTextColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.workSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: value == 'Not provided' ? subTextColor : textColor,
                  fontStyle: value == 'Not provided'
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackSection(Map<String, String> strings) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings['clientFeedback'] ?? 'Client Feedback',
                style: GoogleFonts.workSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainerClientReviewsScreen(),
                  ),
                ),
                child: Text(
                  strings['viewAll'] ?? 'VIEW ALL',
                  style: GoogleFonts.workSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primaryRed,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: _feedbacks.isEmpty
              ? Center(
                  child: Text(
                    strings['noFeedback'] ?? 'No feedback available yet.',
                    style: GoogleFonts.workSans(
                      color: subTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: _feedbacks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 16),
                  itemBuilder: (context, index) =>
                      _buildFeedbackCard(_feedbacks[index], strings),
                ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard(
    Map<String, dynamic> feedback,
    Map<String, String> strings,
  ) {
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final clientName =
        feedback['clientName']?.toString() ??
        strings['anonymous'] ??
        'Anonymous';
    final memberType =
        feedback['memberType']?.toString() ?? strings['member'] ?? 'MEMBER';
    final reviewText = feedback['reviewText']?.toString() ?? '';
    final clientImage = feedback['clientImageUrl']?.toString() ?? '';
    int rating = feedback['rating'] != null
        ? (double.tryParse(feedback['rating'].toString())?.round() ?? 5)
        : 5;
    String initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : 'U';

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: primaryRed,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              reviewText.isNotEmpty
                  ? '"$reviewText"'
                  : (strings['noWrittenReview'] ??
                        'No written review provided.'),
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: reviewText.isNotEmpty ? textColor : subTextColor,
                fontStyle: reviewText.isNotEmpty
                    ? FontStyle.normal
                    : FontStyle.italic,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: dividerColor,
                backgroundImage: clientImage.isNotEmpty
                    ? NetworkImage(clientImage)
                    : null,
                child: clientImage.isEmpty
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      memberType.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.workSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: subTextColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.workSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.workSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subTextColor),
          ],
        ),
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
                  TextSpan(
                    text: 'JoE',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: _KettlebellIcon(size: 18),
                    ),
                  ),
                  TextSpan(
                    text: 'V ',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                  TextSpan(
                    text: 'FITNESS',
                    style: GoogleFonts.workSans(
                      color: const Color(0xFFC7001A),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrainerNotificationsScreen(),
                ),
              ),
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
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _KettlebellPainter()),
  );
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
    final double w = size.width, h = size.height;
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
    Path k = Path.combine(PathOperation.union, handle, body);
    k = Path.combine(
      PathOperation.difference,
      k,
      Path()..addRect(Rect.fromLTRB(0, h * 0.94, w, h)),
    );
    k = Path.combine(
      PathOperation.difference,
      k,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.40, h * 0.20, w * 0.60, h * 0.45),
          Radius.circular(w * 0.1),
        ),
      ),
    );
    canvas.drawPath(k.shift(const Offset(1.5, 1.5)), shadowPaint);
    canvas.drawPath(k, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
