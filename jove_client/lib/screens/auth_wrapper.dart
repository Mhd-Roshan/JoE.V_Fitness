import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- YOUR IMPORTS ---
import 'welcome_screen.dart';
import 'auth/assessment_screen.dart';
import 'auth/package_select_screen.dart';
import 'entry_pass_paywall_screen.dart';
import 'trainer_selection_screen.dart';
import 'home_dashboard_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Stream<User?> _authStream;
  Stream<DocumentSnapshot>? _userStream;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  void _updateUserStream(String? uid) {
    if (_currentUid != uid) {
      _currentUid = uid;
      if (uid != null) {
        _userStream = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots();
      } else {
        _userStream = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      initialData: FirebaseAuth.instance.currentUser,
      stream: _authStream,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CustomLoadingIndicator()),
          );
        }

        // If NO user is logged in, go to WelcomeScreen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const WelcomeScreen();
        }

        // Setup stream for this specific user
        _updateUserStream(authSnapshot.data!.uid);

        // If user IS logged in, fetch their Firestore profile
        return StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting &&
                !userSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(child: CustomLoadingIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const AssessmentScreen();
            }

            final userData =
                userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final bool hasCompletedAssessment =
                userData['assessmentCompleted'] ?? false;
            final String? assignedTrainerId = userData['assignedTrainerId'];

            // 1. Initial Assessment Check
            if (!hasCompletedAssessment) {
              return const AssessmentScreen();
            }

            // 2. Subscription & Expiry Check
            Timestamp? nextBillingDate = userData['subscription'] is Map
                ? userData['subscription']['nextBillingDate'] as Timestamp?
                : userData['packageEndDate'] as Timestamp?;
            bool isPackageExpired = false;
            if (nextBillingDate != null) {
              isPackageExpired = DateTime.now().isAfter(
                nextBillingDate.toDate(),
              );
            }

            final bool hasActiveSubscription =
                !isPackageExpired &&
                (userData['hasActiveSubscription'] == true ||
                    (userData['subscription'] is Map &&
                        userData['subscription']['status'] == 'Active'));
            final bool hasSeenFirstPreview =
                userData['hasSeenFirstPreview'] == true;
            final bool hasPaidEntryFee = userData['hasPaidEntryFee'] == true;

            // If a previous paid package has expired AND they haven't paid the ₹99 entry fee, block them
            // (If they HAVE paid ₹99, they simply downgrade to basic app access)
            if (isPackageExpired && !hasPaidEntryFee) {
              return const PackageSelectScreen();
            }

            // STAGE A: Full Package Member (Full unlimited active access)
            if (hasActiveSubscription) {
              if (assignedTrainerId == null || assignedTrainerId.isEmpty) {
                return const SelectTrainerScreen();
              }
              return const HomeDashboardScreen();
            }

            // STAGE B: User hasn't previewed the app yet -> Show Package Selection with "Explore App" option
            if (!hasSeenFirstPreview) {
              return const PackageSelectScreen();
            }

            // STAGE C: User previewed once, but hasn't paid ₹99 Entry Pass yet -> Show ₹99 Paywall
            if (!hasPaidEntryFee) {
              return const EntryPassPaywallScreen();
            }

            // STAGE D: User paid ₹99 -> Permanent basic app access. Never ask again.
            if (hasPaidEntryFee) {
              return const HomeDashboardScreen();
            }

            // Fallback (should not be reached based on above logic, but required by Dart)
            return const PackageSelectScreen();
          },
        );
      },
    );
  }
}
