import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;

  // Initialize the shared preferences instance
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- THEME PREFERENCES ---
  static const String _themeKey = 'isDarkMode';

  static bool? getTheme() {
    return _prefs?.getBool(_themeKey);
  }

  static Future<void> saveTheme(bool isDark) async {
    await _prefs?.setBool(_themeKey, isDark);
  }

  // --- ADD MORE PREFERENCES BELOW AS NEEDED ---
  // e.g. User IDs, Onboarding states, etc.
}
