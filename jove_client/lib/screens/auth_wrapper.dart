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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      initialData: FirebaseAuth.instance.currentUser,
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFBA0C19)),
            ),
          );
        }

        // If NO user is logged in, go to WelcomeScreen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const WelcomeScreen();
        }

        // If user IS logged in, fetch their Firestore profile
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting &&
                !userSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00225D)),
                ),
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
              isPackageExpired = DateTime.now().isAfter(nextBillingDate.toDate());
            }

            final bool hasActiveSubscription = !isPackageExpired &&
                (userData['hasActiveSubscription'] == true ||
                (userData['subscription'] is Map &&
                    userData['subscription']['status'] == 'Active'));
            final bool hasSeenFirstPreview =
                userData['hasSeenFirstPreview'] == true;
            final bool hasPaidEntryFee =
                userData['hasPaidEntryFee'] == true;
            final bool hasSeenSecondPreview =
                userData['hasSeenSecondPreview'] == true;

            // If a previous paid package has expired, direct client immediately to PackageSelectScreen
            if (isPackageExpired) {
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

            // STAGE D: User paid ₹99 and is currently in their 2nd preview session -> Go straight to Home
            if (!hasSeenSecondPreview) {
              return const HomeDashboardScreen();
            }

            // STAGE E: User used both previews (1st free preview + ₹99 paid preview).
            // On every subsequent restart, they MUST select & pay for a membership package!
            return const PackageSelectScreen();
          },
        );
      },
    );
  }
}
