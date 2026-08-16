import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- YOUR IMPORTS ---
import 'welcome_screen.dart'; // <--- Now pointing to Welcome Screen first!
import 'auth/assessment_screen.dart';
import 'trainer_selection_screen.dart';
import 'home_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 👇 THIS IS THE MAGIC LINE THAT FIXES THE RESTART BUG 👇
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

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const AssessmentScreen();
            }

            final userData =
                userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final bool hasCompletedAssessment =
                userData['assessmentCompleted'] ?? false;
            final String? assignedTrainerId = userData['assignedTrainerId'];

            // Perfect Routing!
            if (!hasCompletedAssessment) {
              return const AssessmentScreen();
            } else if (assignedTrainerId == null || assignedTrainerId.isEmpty) {
              return const SelectTrainerScreen();
            } else {
              return const HomeDashboardScreen();
            }
          },
        );
      },
    );
  }
}
