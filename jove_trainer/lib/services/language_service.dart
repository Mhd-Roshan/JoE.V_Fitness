import 'package:flutter/foundation.dart';

class LanguageService extends ChangeNotifier {
  static const List<String> supportedLanguages = ['en', 'ml', 'hi', 'ta'];

  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'ml': 'മലയാളം',
    'hi': 'हिंदी',
    'ta': 'தமிழ்',
  };

  String get languageName => _languageNames[_currentLanguage] ?? 'English';

  void setLanguage(String langCode) {
    _currentLanguage = langCode;
    notifyListeners();
  }
}

// Singleton instance
final languageService = LanguageService();
