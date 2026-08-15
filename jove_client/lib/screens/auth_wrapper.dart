import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- UPDATE THESE IMPORTS TO MATCH YOUR ACTUAL FILE LOCATIONS ---
import 'welcome_screen.dart'; // <--- Put your actual 'Get Started' screen here
import 'auth/assessment_screen.dart';
import 'trainer_selection_screen.dart';
import 'home_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Check if the user is authenticated in Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Show loading while checking auth state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFBA0C19)),
            ),
          );
        }

        // 2. If NO user is logged in, show the Get Started / Welcome Screen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const WelcomeScreen(); // <-- Change to your actual Get Started Screen class
        }

        // 3. If user IS logged in, fetch their Firestore profile to see where they left off
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00225D)),
                ),
              );
            }

            // If user doc doesn't exist yet (very rare edge case), send to Assessment
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const AssessmentScreen();
            }

            final userData =
                userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final bool hasCompletedAssessment =
                userData['assessmentCompleted'] ?? false;
            final String? assignedTrainerId = userData['assignedTrainerId'];

            // 4. Perfect Routing Logic!
            if (!hasCompletedAssessment) {
              return const AssessmentScreen(); // Needs to finish assessment
            } else if (assignedTrainerId == null || assignedTrainerId.isEmpty) {
              return const SelectTrainerScreen(); // Needs to pick a trainer
            } else {
              return const HomeDashboardScreen(); // Everything is done, go to Home!
            }
          },
        );
      },
    );
  }
}
