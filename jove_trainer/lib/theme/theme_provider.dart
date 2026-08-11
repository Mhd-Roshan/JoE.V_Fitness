import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // Default to following the Device's System Theme!
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();

    // Look for saved theme, default to 'system' if nothing is saved yet
    final savedTheme = prefs.getString('theme_mode') ?? 'system';

    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  // Use this function to change the theme from the settings screen
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners(); // Updates the entire app instantly!

    // Save the choice to the device so it remembers next time you open the app
    final prefs = await SharedPreferences.getInstance();
    String saveString = 'system';
    if (mode == ThemeMode.light) saveString = 'light';
    if (mode == ThemeMode.dark) saveString = 'dark';

    await prefs.setString('theme_mode', saveString);
  }
}
