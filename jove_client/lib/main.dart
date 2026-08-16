import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart'; // <-- IMPORTANT: Point to your splash screen

void main() async {
  // 1. Ensure Flutter bindings are ready before launching Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp();

  // 3. Run UI
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JoE.V FITNESS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBA0C19)),
        useMaterial3: true,
      ),

      // 4. Set the Splash Screen as the VERY FIRST thing the app sees
      home: const SplashScreen(),
    );
  }
}
