import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppThemeController with WidgetsBindingObserver {
  // Singleton for observing system theme changes
  static final AppThemeController _instance = AppThemeController._internal();

  AppThemeController._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Call this in main() to ensure the observer is registered early
  static void initialize() {
    _instance; 
  }

  static bool _hasUserOverride = false;

  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(
    PlatformDispatcher.instance.platformBrightness == Brightness.dark,
  );

  @override
  void didChangePlatformBrightness() {
    if (!_hasUserOverride) {
      final isSystemDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      if (isDarkMode.value != isSystemDark) {
        isDarkMode.value = isSystemDark;
      }
    }
  }

  static bool get isDark => isDarkMode.value;

  // Instagram-style Theme Colors
  static Color get scaffoldBg =>
      isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA);

  static Color get cardBg =>
      isDark ? const Color(0xFF121212) : Colors.white;

  static Color get textMain =>
      isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);

  static Color get textSub =>
      isDark ? const Color(0xFFA8A8A8) : const Color(0xFF757575);

  static Color get border =>
      isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE);

  static Color get iconBadgeBg =>
      isDark ? const Color(0xFF262626) : const Color(0xFFF0F2F5);

  static Color get navBg =>
      isDark ? const Color(0xFF121212) : const Color(0xFF00215F);

  static const Color primaryRed = Color(0xFFBA0C19);

  /// Toggle between Light and Dark Mode app-wide with haptic feedback & cloud sync
  static Future<void> toggleTheme() async {
    HapticFeedback.mediumImpact();
    isDarkMode.value = !isDarkMode.value;
    _hasUserOverride = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'isDarkMode': isDarkMode.value}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving theme preference: $e');
      }
    }
  }

  /// Initialize theme from user document
  static void initFromUserData(Map<String, dynamic>? data) {
    if (data != null && data['isDarkMode'] is bool) {
      _hasUserOverride = true;
      isDarkMode.value = data['isDarkMode'];
    } else {
      _hasUserOverride = false;
      isDarkMode.value = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
  }

  /// App-wide Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFEEEEEE),
      colorScheme: const ColorScheme.light(
        primary: primaryRed,
        surface: Colors.white,
        onSurface: Color(0xFF1A1A1A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFAFA),
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FastFadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _FastFadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: _FastFadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: _FastFadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: _FastFadeSlidePageTransitionsBuilder(),
        },
      ),
    );
  }

  /// App-wide Instagram AMOLED Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF121212),
      dividerColor: const Color(0xFF262626),
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        surface: Color(0xFF121212),
        onSurface: Color(0xFFF5F5F5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Color(0xFFF5F5F5),
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FastFadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _FastFadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: _FastFadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: _FastFadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: _FastFadeSlidePageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _FastFadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FastFadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.06, 0.0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: curvedAnimation,
        child: child,
      ),
    );
  }
}
