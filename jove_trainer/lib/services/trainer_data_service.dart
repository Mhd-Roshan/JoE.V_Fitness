import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// High-Performance In-Memory Cache and Data Sync Service for Trainer App.
/// Enables 0ms instantaneous screen loads with zero spinners on navigation.
class TrainerDataService extends ChangeNotifier {
  static final TrainerDataService _instance = TrainerDataService._internal();
  factory TrainerDataService() => _instance;
  TrainerDataService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void>? _inFlightPreload;

  // Cached Trainer Profile & Identity
  Map<String, dynamic> trainerUserData = {};
  Map<String, dynamic> trainerDocData = {};
  final Set<String> myTrainerIds = {};
  final Set<String> myTrainerNames = {};
  final Set<String> myTrainerEmails = {};
  final Set<String> myTrainerPhones = {};

  // Cached Collections
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allTrainersDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allUsersDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allSessionsDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allBookingsDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allWorkoutsDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allPlansDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allFeedbacksDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allReviewsDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allVisitNotesDocs = [];

  // Cached Client Profiles Map: clientId -> Map of all profile fields
  final Map<String, Map<String, dynamic>> cachedClientProfiles = {};

  Future<DocumentSnapshot<Map<String, dynamic>>?> _safeDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get();
    } catch (_) {
      return null;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _safeQuery(
    Future<QuerySnapshot<Map<String, dynamic>>> query,
  ) async {
    try {
      return await query;
    } catch (_) {
      return null;
    }
  }

  /// Initial or background preload of all data across the app.
  /// Deduplicates parallel calls so only 1 network burst happens.
  Future<void> preloadAll({bool notify = true, bool force = false}) async {
    if (!force && _inFlightPreload != null) {
      return _inFlightPreload;
    }

    _inFlightPreload = _performPreload(notify: notify);
    await _inFlightPreload;
    _inFlightPreload = null;
  }

  Future<void> _performPreload({bool notify = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    myTrainerIds.add(uid);

    if (user.email != null && user.email!.isNotEmpty) {
      final em = user.email!.toLowerCase().trim();
      myTrainerEmails.add(em);
      myTrainerNames.add(em);
    }
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      final name = user.displayName!.toLowerCase().trim();
      myTrainerNames.add(name);
      for (final part in name.split(' ')) {
        if (part.length > 1) myTrainerNames.add(part);
      }
    }
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      myTrainerPhones.add(user.phoneNumber!.trim());
    }

    try {
      final snaps = await Future.wait([
        _safeDoc(FirebaseFirestore.instance.collection('users').doc(uid)),
        _safeDoc(FirebaseFirestore.instance.collection('trainers').doc(uid)),
        _safeQuery(FirebaseFirestore.instance.collection('trainers').get()),
        _safeQuery(FirebaseFirestore.instance.collection('users').get()),
        _safeQuery(FirebaseFirestore.instance.collection('sessions').get()),
        _safeQuery(FirebaseFirestore.instance.collection('bookings').get()),
        _safeQuery(FirebaseFirestore.instance.collection('workouts').get()),
        _safeQuery(FirebaseFirestore.instance.collection('workout_plans').get()),
        _safeQuery(FirebaseFirestore.instance.collection('feedbacks').get()),
        _safeQuery(FirebaseFirestore.instance.collection('reviews').get()),
        _safeQuery(FirebaseFirestore.instance.collection('visit_notes').get()),
      ]);

      final userDoc = snaps[0] as DocumentSnapshot<Map<String, dynamic>>?;
      final trainerDoc = snaps[1] as DocumentSnapshot<Map<String, dynamic>>?;
      final allTrainersSnap = snaps[2] as QuerySnapshot<Map<String, dynamic>>?;
      final allUsersSnap = snaps[3] as QuerySnapshot<Map<String, dynamic>>?;
      final sessionsSnap = snaps[4] as QuerySnapshot<Map<String, dynamic>>?;
      final bookingsSnap = snaps[5] as QuerySnapshot<Map<String, dynamic>>?;
      final workoutsSnap = snaps[6] as QuerySnapshot<Map<String, dynamic>>?;
      final plansSnap = snaps[7] as QuerySnapshot<Map<String, dynamic>>?;
      final feedbacksSnap = snaps[8] as QuerySnapshot<Map<String, dynamic>>?;
      final reviewsSnap = snaps[9] as QuerySnapshot<Map<String, dynamic>>?;
      final visitNotesSnap = snaps[10] as QuerySnapshot<Map<String, dynamic>>?;

      if (userDoc != null && userDoc.exists) {
        trainerUserData = userDoc.data() ?? {};
        final uData = trainerUserData;
        if (uData['fullName'] != null) {
          final fn = uData['fullName'].toString().toLowerCase().trim();
          myTrainerNames.add(fn);
          for (final part in fn.split(' ')) {
            if (part.length > 1) myTrainerNames.add(part);
          }
        }
        if (uData['name'] != null) {
          final n = uData['name'].toString().toLowerCase().trim();
          myTrainerNames.add(n);
          for (final part in n.split(' ')) {
            if (part.length > 1) myTrainerNames.add(part);
          }
        }
        if (uData['email'] != null) {
          myTrainerEmails.add(uData['email'].toString().toLowerCase().trim());
        }
        if (uData['phone'] != null || uData['phoneNumber'] != null) {
          final p = (uData['phone'] ?? uData['phoneNumber']).toString().trim();
          if (p.isNotEmpty) myTrainerPhones.add(p);
        }
        if (uData['trainerId'] != null) myTrainerIds.add(uData['trainerId'].toString().trim());
        if (uData['id'] != null) myTrainerIds.add(uData['id'].toString().trim());
      }

      if (trainerDoc != null && trainerDoc.exists) {
        trainerDocData = trainerDoc.data() ?? {};
      }

      if (allTrainersSnap != null) {
        allTrainersDocs = allTrainersSnap.docs;
        for (var tDoc in allTrainersDocs) {
          final tData = tDoc.data();
          final tEmail = (tData['email'] ?? '').toString().toLowerCase().trim();
          final tName = (tData['fullName'] ?? tData['name'] ?? '').toString().toLowerCase().trim();
          final tUserId = (tData['userId'] ?? tData['authUid'] ?? tData['uid'] ?? '').toString().trim();
          final tPhone = (tData['phone'] ?? tData['phoneNumber'] ?? '').toString().trim();

          bool isMe = tDoc.id == uid ||
              (tUserId.isNotEmpty && tUserId == uid) ||
              (user.email != null && tEmail.isNotEmpty && tEmail == user.email!.toLowerCase().trim()) ||
              (user.phoneNumber != null && tPhone.isNotEmpty && tPhone == user.phoneNumber!.trim()) ||
              (myTrainerEmails.isNotEmpty && tEmail.isNotEmpty && myTrainerEmails.contains(tEmail)) ||
              (myTrainerPhones.isNotEmpty && tPhone.isNotEmpty && myTrainerPhones.contains(tPhone)) ||
              (myTrainerNames.isNotEmpty && tName.isNotEmpty && myTrainerNames.any((n) => n.isNotEmpty && (tName == n || tName.contains(n) || n.contains(tName)))) ||
              (allTrainersDocs.length == 1);

          if (isMe) {
            myTrainerIds.add(tDoc.id);
            if (tData['trainerId'] != null) myTrainerIds.add(tData['trainerId'].toString().trim());
            if (tData['id'] != null) myTrainerIds.add(tData['id'].toString().trim());
            if (tName.isNotEmpty) {
              myTrainerNames.add(tName);
              for (final part in tName.split(' ')) {
                if (part.length > 1) myTrainerNames.add(part);
              }
            }
            if (tEmail.isNotEmpty) myTrainerEmails.add(tEmail);
            if (tPhone.isNotEmpty) myTrainerPhones.add(tPhone);
            if (trainerDocData.isEmpty) trainerDocData = tData;
          }
        }
      }

      if (allUsersSnap != null) allUsersDocs = allUsersSnap.docs;
      if (sessionsSnap != null) allSessionsDocs = sessionsSnap.docs;
      if (bookingsSnap != null) allBookingsDocs = bookingsSnap.docs;
      if (workoutsSnap != null) allWorkoutsDocs = workoutsSnap.docs;
      if (plansSnap != null) allPlansDocs = plansSnap.docs;
      if (feedbacksSnap != null) allFeedbacksDocs = feedbacksSnap.docs;
      if (reviewsSnap != null) allReviewsDocs = reviewsSnap.docs;
      if (visitNotesSnap != null) allVisitNotesDocs = visitNotesSnap.docs;

      _isInitialized = true;
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('TrainerDataService preload error: $e');
    }
  }

  /// Clear all cache upon logout
  void clear() {
    _isInitialized = false;
    _inFlightPreload = null;
    trainerUserData.clear();
    trainerDocData.clear();
    myTrainerIds.clear();
    myTrainerNames.clear();
    myTrainerEmails.clear();
    myTrainerPhones.clear();
    allTrainersDocs = [];
    allUsersDocs = [];
    allSessionsDocs = [];
    allBookingsDocs = [];
    allWorkoutsDocs = [];
    allPlansDocs = [];
    allFeedbacksDocs = [];
    allReviewsDocs = [];
    allVisitNotesDocs = [];
    cachedClientProfiles.clear();
    notifyListeners();
  }

  /// Get cached client profile details or fetch and cache
  Map<String, dynamic>? getCachedClientProfile(String clientId) {
    return cachedClientProfiles[clientId];
  }

  void cacheClientProfile(String clientId, Map<String, dynamic> data) {
    cachedClientProfiles[clientId] = data;
  }
}
