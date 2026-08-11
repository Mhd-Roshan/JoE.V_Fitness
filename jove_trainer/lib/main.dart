import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- ADDED THIS IMPORT FOR LOCALIZATION ---
import 'package:flutter_localizations/flutter_localizations.dart';

// --- ADDED THESE IMPORTS FOR DARK MODE ---
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

// --- IMPORT YOUR LOGIN AND HOME SCREENS ---
import 'screens/home/trainer_home_screen.dart';
import 'screens/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ---> WRAPPED APP IN MULTIPROVIDER FOR THEME STATE <---
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: const JoveTrainerApp(),
    ),
  );
}

// 1. STATEFUL WIDGET TO SUPPORT APP RESTART
class JoveTrainerApp extends StatefulWidget {
  const JoveTrainerApp({super.key});

  // 2. MAGIC RESTART FUNCTION
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_JoveTrainerAppState>()?.restartApp();
  }

  @override
  State<JoveTrainerApp> createState() => _JoveTrainerAppState();
}

class _JoveTrainerAppState extends State<JoveTrainerApp> {
  // 3. CREATE A UNIQUE KEY FOR THE APP
  Key _appKey = UniqueKey();

  // 4. TRACK IF THIS IS THE FIRST OPEN
  bool _isInitialLoad = true;

  // 5. METHOD TO RESTART THE APP (Changes language instantly)
  void restartApp() {
    setState(() {
      _appKey = UniqueKey(); // Destroys and rebuilds the app
      _isInitialLoad = false; // Skips the splash screen so it feels seamless!
    });
  }

  @override
  Widget build(BuildContext context) {
    // ---> LISTEN TO THEME CHANGES <---
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      key: _appKey,
      title: 'JoE.V Trainer',
      debugShowCheckedModeBanner: false,

      // --- ADDED THESE LINES FOR FLUTTER LOCALIZATION ---
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

      // ------------------------------------------------
      // ---> NEW DYNAMIC THEME SETTINGS <---
      // ------------------------------------------------
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      // 6. IF IT IS THE FIRST OPEN, SHOW SPLASH. OTHERWISE, GO STRAIGHT TO AUTH
      home: _isInitialLoad ? const SplashScreen() : const AuthWrapper(),
    );
  }
}

// -------------------------------------------------------------
// ADD THIS AUTH WRAPPER
// This acts as a "traffic cop" to decide where the user goes
// -------------------------------------------------------------
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listens to Firebase to see if a user session is saved on the device
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00225D)),
            ),
          );
        }

        // If Firebase finds a saved login session, send them straight to Home!
        if (snapshot.hasData && snapshot.data != null) {
          return const TrainerHomeScreen();
        }

        // If NO saved session is found, send them to Login.
        return const LoginScreen();
      },
    );
  }
}
