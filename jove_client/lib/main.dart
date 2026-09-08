import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/app_notification_service.dart';
import 'services/local_storage_service.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';

void main() async {
  // 1. Ensure Flutter bindings are ready before launching Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize SharedPreferences via LocalStorageService
  await LocalStorageService.init();

  // 3. Initialize Firebase
  await Firebase.initializeApp();

  // 4. Initialize Easy Localization
  await EasyLocalization.ensureInitialized();

  // 5. Initialize Notification Service
  await AppNotificationService.instance.initialize();

  // 6. Run UI Wrapped in Providers and Localization Config
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('ml'),
          Locale('hi'),
          Locale('ta'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch ThemeProvider for changes
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: AppNotificationService.navigatorKey,
      title: 'JoE.V FITNESS',
      debugShowCheckedModeBanner: false,

      // --- LOCALIZATION ---
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // --- THEME MANAGEMENT ---
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: themeProvider.currentTheme, // Note: You might need to update this depending on how you expose light/dark in ThemeProvider
      
      home: const SplashScreen(),
    );
  }
}
