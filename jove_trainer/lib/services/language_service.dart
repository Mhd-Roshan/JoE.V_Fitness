import '../l10n/app_en.dart' as loc_en;
import '../l10n/app_ml.dart' as loc_ml;
import '../l10n/app_hi.dart' as loc_hi;
import '../l10n/app_ta.dart' as loc_ta;

class LanguageService {
  String currentLanguage = 'en'; // Default to English

  void setLanguage(String langCode) {
    currentLanguage = langCode;
  }

  // Any screen can call `languageService.strings` to get the correct map!
  Map<String, String> get strings {
    switch (currentLanguage) {
      case 'ml':
        return loc_ml.AppStrings.ml;
      case 'hi':
        return loc_hi.AppStrings.hi;
      case 'ta':
        return loc_ta.AppStrings.ta;
      case 'en':
      default:
        return loc_en.AppStrings.en;
    }
  }
}

// Global instance to use anywhere in the app
final languageService = LanguageService();
