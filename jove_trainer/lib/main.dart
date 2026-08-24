import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home/trainer_main_screen.dart';
import 'screens/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: const JoveTrainerApp(),
    ),
  );
}

class JoveTrainerApp extends StatefulWidget {
  const JoveTrainerApp({super.key});

  /// Restart function to rebuild language/theme on the fly
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_JoveTrainerAppState>()?.restartApp();
  }

  @override
  State<JoveTrainerApp> createState() => _JoveTrainerAppState();
}

class _JoveTrainerAppState extends State<JoveTrainerApp> {
  Key _appKey = UniqueKey();

  void restartApp() {
    setState(() {
      _appKey = UniqueKey(); // Destroys and rebuilds widget tree cleanly
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      key: _appKey,
      title: 'JoE.V Trainer',
      debugShowCheckedModeBanner: false,

      // --- LOCALIZATION SETTINGS ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ml', ''), // Malayalam
        Locale('hi', ''), // Hindi
        Locale('ta', ''), // Tamil
      ],

      // --- DYNAMIC THEME SETTINGS ---
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      // Clean splash transition on app startup
      home: const SplashScreen(),
    );
  }
}

// -------------------------------------------------------------
// PERSISTENT AUTH GATEKEEPER
// -------------------------------------------------------------
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listens directly to Firebase Auth persistence state
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. While reading the saved session token from device storage:
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // 2. If a valid saved login session is found -> Go to TrainerMainScreen!
        if (snapshot.hasData && snapshot.data != null) {
          return const TrainerMainScreen();
        }

        // 3. If NO active session -> Go to Login.
        return const LoginScreen();
      },
    );
  }
}
