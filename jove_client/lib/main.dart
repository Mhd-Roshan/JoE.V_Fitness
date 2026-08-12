import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Wakes up Firebase!
import 'screens/splash_screen.dart';

void main() async {
  // 1. You must ensure Flutter bindings are ready before launching Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase database and authentication
  await Firebase.initializeApp();

  // 3. Run your UI
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JoE.V FITNESS',
      debugShowCheckedModeBanner: false, // Removes the little "DEBUG" banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBA0C19)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
