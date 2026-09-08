import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../services/local_storage_service.dart';
import '../theme/app_theme_controller.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _hasUserOverride = false;

  ThemeProvider() {
    _initializeTheme();
  }

  bool get isDarkMode => _isDarkMode;

  void _initializeTheme() {
    final storedTheme = LocalStorageService.getTheme();
    if (storedTheme != null) {
      _isDarkMode = storedTheme;
      _hasUserOverride = true;
    } else {
      _isDarkMode = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
    
    // Sync with legacy AppThemeController
    AppThemeController.isDarkMode.value = _isDarkMode;
    
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    HapticFeedback.mediumImpact();
    _isDarkMode = !_isDarkMode;
    _hasUserOverride = true;
    
    // Sync with legacy AppThemeController
    AppThemeController.isDarkMode.value = _isDarkMode;
    
    notifyListeners();

    // Save to SharedPreferences
    await LocalStorageService.saveTheme(_isDarkMode);
  }

  void didChangePlatformBrightness() {
    if (!_hasUserOverride) {
      final isSystemDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      if (_isDarkMode != isSystemDark) {
        _isDarkMode = isSystemDark;
        notifyListeners();
      }
    }
  }

  // --- Theme Colors (Migrated from AppThemeController) ---
  Color get scaffoldBg => _isDarkMode ? const Color(0xFF000000) : const Color(0xFFFAFAFA);
  Color get cardBg => _isDarkMode ? const Color(0xFF121212) : Colors.white;
  Color get textMain => _isDarkMode ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
  Color get textSub => _isDarkMode ? const Color(0xFFA8A8A8) : const Color(0xFF757575);
  Color get border => _isDarkMode ? const Color(0xFF262626) : const Color(0xFFEEEEEE);
  Color get iconBadgeBg => _isDarkMode ? const Color(0xFF262626) : const Color(0xFFF0F2F5);
  Color get navBg => _isDarkMode ? const Color(0xFF121212) : const Color(0xFF00215F);

  static const Color primaryRed = Color(0xFFBA0C19);

  ThemeData get currentTheme => _isDarkMode ? _darkTheme : _lightTheme;

  ThemeData get _lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFEEEEEE),
      colorScheme: const ColorScheme.light(
        primary: primaryRed,
        secondary: Color(0xFF00215F),
        surface: Colors.white,
        error: Colors.red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFAFA),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
        titleTextStyle: TextStyle(color: Color(0xFF1A1A1A), fontSize: 20, fontWeight: FontWeight.bold),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF1A1A1A)),
      ),
    );
  }

  ThemeData get _darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF121212),
      dividerColor: const Color(0xFF262626),
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: Color(0xFF3B82F6),
        surface: Color(0xFF121212),
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF5F5F5)),
        titleTextStyle: TextStyle(color: Color(0xFFF5F5F5), fontSize: 20, fontWeight: FontWeight.bold),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFF5F5F5)),
        bodyMedium: TextStyle(color: Color(0xFFF5F5F5)),
      ),
    );
  }
}
