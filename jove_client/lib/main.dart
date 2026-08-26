import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- 1. IMPORT LOCALIZATION

import 'screens/splash_screen.dart'; // <-- IMPORTANT: Point to your splash screen
import 'theme/app_theme_controller.dart';
import 'services/app_notification_service.dart';

void main() async {
  // 1. Ensure Flutter bindings are ready before launching Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize theme observer for automatic system dark mode switching
  AppThemeController.initialize();

  // 2. Initialize Firebase
  await Firebase.initializeApp();

  // 3. Initialize Easy Localization
  await EasyLocalization.ensureInitialized(); // <-- 2. INIT LOCALIZATION

  // 4. Initialize Notification Service (FCM & Real-time Local Push)
  await AppNotificationService.instance.initialize();

  // 5. Run UI Wrapped in Localization Config
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
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          navigatorKey: AppNotificationService.navigatorKey,
          title: 'JoE.V FITNESS',
          debugShowCheckedModeBanner: false,

          // --- LOCALIZATION ---
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,

          // --- THEME MANAGEMENT ---
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: AppThemeController.lightTheme,
          darkTheme: AppThemeController.darkTheme,

          // 4. Set the Splash Screen as the VERY FIRST thing the app sees
          home: const SplashScreen(),
        );
      },
    );
  }
}
