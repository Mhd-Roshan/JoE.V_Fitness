import 'package:flutter/material.dart';

/// Custom high-performance, low-latency (180ms) page transition for all platforms
class FastFadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FastFadeSlidePageTransitionsBuilder();

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

class AppTheme {
  static const _fastTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FastFadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: FastFadeSlidePageTransitionsBuilder(),
      TargetPlatform.windows: FastFadeSlidePageTransitionsBuilder(),
      TargetPlatform.macOS: FastFadeSlidePageTransitionsBuilder(),
      TargetPlatform.linux: FastFadeSlidePageTransitionsBuilder(),
    },
  );

  // --- LIGHT THEME ---
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA), // bgGrey
    primaryColor: const Color(0xFF003AA3), // headerBlue
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE5E7EB), // borderGrey
    pageTransitionsTheme: _fastTransitionsTheme,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00225D), // darkBlue
      secondary: Color(0xFF01BCE3), // cyanAccent
      error: Color(0xFFC7001A), // primaryRed
      surface: Colors.white,
      onSurface: Color(0xFF00225D), // Main text color (Dark Blue)
      onSurfaceVariant: Color(0xFF6B7280), // Subtitle text color
    ),
  );

  // --- DARK THEME ---
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212), // Dark background
    primaryColor: const Color(0xFF00225D), // Keep header dark blue
    cardColor: const Color(0xFF1E1E1E), // Dark grey for cards
    dividerColor: const Color(0xFF333333), // Dark borders
    pageTransitionsTheme: _fastTransitionsTheme,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF01BCE3), // Lighter blue for dark mode
      secondary: Color(0xFF01BCE3),
      error: Color(0xFFEF5350), // Lighter red
      surface: Color(0xFF1E1E1E),
      onSurface: Colors.white, // Main text color (White)
      onSurfaceVariant: Color(0xFFAAAAAA), // Subtitle text color
    ),
  );
}
