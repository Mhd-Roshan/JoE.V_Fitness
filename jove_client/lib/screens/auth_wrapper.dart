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

            // 2. Subscription & Payment States
            final bool hasActiveSubscription =
                userData['hasActiveSubscription'] == true ||
                (userData['subscription'] is Map &&
                    userData['subscription']['status'] == 'Active');
            final bool hasSeenFirstPreview =
                userData['hasSeenFirstPreview'] == true;
            final bool hasPaidEntryFee =
                userData['hasPaidEntryFee'] == true;

            // STAGE A: Full Package Member (Full unlimited access)
            if (hasActiveSubscription) {
              if (assignedTrainerId == null || assignedTrainerId.isEmpty) {
                return const SelectTrainerScreen();
              }
              return const HomeDashboardScreen();
            }

            // STAGE B: First-time Logged in User (Gets to see the entire app on their 1st session)
            if (!hasSeenFirstPreview) {
              if (assignedTrainerId == null || assignedTrainerId.isEmpty) {
                return const SelectTrainerScreen();
              }
              return const HomeDashboardScreen();
            }

            // STAGE C: Returning user who hasn't paid ₹99 Entry Pass yet
            if (!hasPaidEntryFee) {
              return const EntryPassPaywallScreen();
            }

            // STAGE D: User paid ₹99, now on next reopen MUST select & pay for a membership package
            return const PackageSelectScreen();
          },
        );
      },
    );
  }
}
