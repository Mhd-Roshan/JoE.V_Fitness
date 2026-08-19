import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- 1. IMPORT LOCALIZATION

import 'screens/splash_screen.dart'; // <-- IMPORTANT: Point to your splash screen

void main() async {
  // 1. Ensure Flutter bindings are ready before launching Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp();

  // 3. Initialize Easy Localization
  await EasyLocalization.ensureInitialized(); // <-- 2. INIT LOCALIZATION

  // 4. Run UI Wrapped in Localization Config
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'), // English
        Locale('ml'), // Malayalam
        Locale('hi'), // Hindi
        Locale('ta'), // Tamil
      ],
      path: 'assets/translations', // <-- Folder where your JSON files will live
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JoE.V FITNESS',
      debugShowCheckedModeBanner: false,

      // --- 3. ADD THESE 3 LINES SO THE APP KNOWS THE LANGUAGE ---
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // ---------------------------------------------------------
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBA0C19)),
        useMaterial3: true,
      ),

      // 4. Set the Splash Screen as the VERY FIRST thing the app sees
      home: const SplashScreen(),
    );
  }
}
