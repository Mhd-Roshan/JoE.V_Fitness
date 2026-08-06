import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const JoveTrainerApp());
}

class JoveTrainerApp extends StatelessWidget {
  const JoveTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JoE.V Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00225D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00225D),
          primary: const Color(0xFF00225D),
        ),
        fontFamily: 'WorkSans',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
