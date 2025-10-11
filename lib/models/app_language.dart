import 'dart:ui';

/// Supported languages in the app
enum AppLanguage {
  english,
  spanish,
  french,
  german,
  italian,
  portuguese,
  dutch,
  japanese,
  korean,
  chinese,
  arabic,
  russian,
  hindi,
  turkish,
  polish,
  swedish,
  norwegian,
  danish,
  finnish,
}

/// Extension to provide metadata for each language
extension AppLanguageExtension on AppLanguage {
  /// Full name in English
  String get name {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.spanish:
        return 'Spanish';
      case AppLanguage.french:
        return 'French';
      case AppLanguage.german:
        return 'German';
      case AppLanguage.italian:
        return 'Italian';
      case AppLanguage.portuguese:
        return 'Portuguese';
      case AppLanguage.dutch:
        return 'Dutch';
      case AppLanguage.japanese:
        return 'Japanese';
      case AppLanguage.korean:
        return 'Korean';
      case AppLanguage.chinese:
        return 'Chinese';
      case AppLanguage.arabic:
        return 'Arabic';
      case AppLanguage.russian:
        return 'Russian';
      case AppLanguage.hindi:
        return 'Hindi';
      case AppLanguage.turkish:
        return 'Turkish';
      case AppLanguage.polish:
        return 'Polish';
      case AppLanguage.swedish:
        return 'Swedish';
      case AppLanguage.norwegian:
        return 'Norwegian';
      case AppLanguage.danish:
        return 'Danish';
      case AppLanguage.finnish:
        return 'Finnish';
    }
  }

  /// Native name (how locals write it)
  String get nativeName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.spanish:
        return 'Español';
      case AppLanguage.french:
        return 'Français';
      case AppLanguage.german:
        return 'Deutsch';
      case AppLanguage.italian:
        return 'Italiano';
      case AppLanguage.portuguese:
        return 'Português';
      case AppLanguage.dutch:
        return 'Nederlands';
      case AppLanguage.japanese:
        return '日本語';
      case AppLanguage.korean:
        return '한국어';
      case AppLanguage.chinese:
        return '中文';
      case AppLanguage.arabic:
        return 'العربية';
      case AppLanguage.russian:
        return 'Русский';
      case AppLanguage.hindi:
        return 'हिन्दी';
      case AppLanguage.turkish:
        return 'Türkçe';
      case AppLanguage.polish:
        return 'Polski';
      case AppLanguage.swedish:
        return 'Svenska';
      case AppLanguage.norwegian:
        return 'Norsk';
      case AppLanguage.danish:
        return 'Dansk';
      case AppLanguage.finnish:
        return 'Suomi';
    }
  }

  /// Language code (ISO 639-1)
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.spanish:
        return 'es';
      case AppLanguage.french:
        return 'fr';
      case AppLanguage.german:
        return 'de';
      case AppLanguage.italian:
        return 'it';
      case AppLanguage.portuguese:
        return 'pt';
      case AppLanguage.dutch:
        return 'nl';
      case AppLanguage.japanese:
        return 'ja';
      case AppLanguage.korean:
        return 'ko';
      case AppLanguage.chinese:
        return 'zh';
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.russian:
        return 'ru';
      case AppLanguage.hindi:
        return 'hi';
      case AppLanguage.turkish:
        return 'tr';
      case AppLanguage.polish:
        return 'pl';
      case AppLanguage.swedish:
        return 'sv';
      case AppLanguage.norwegian:
        return 'no';
      case AppLanguage.danish:
        return 'da';
      case AppLanguage.finnish:
        return 'fi';
    }
  }

  /// Flag emoji
  String get flag {
    switch (this) {
      case AppLanguage.english:
        return '🇺🇸';
      case AppLanguage.spanish:
        return '🇪🇸';
      case AppLanguage.french:
        return '🇫🇷';
      case AppLanguage.german:
        return '🇩🇪';
      case AppLanguage.italian:
        return '🇮🇹';
      case AppLanguage.portuguese:
        return '🇵🇹';
      case AppLanguage.dutch:
        return '🇳🇱';
      case AppLanguage.japanese:
        return '🇯🇵';
      case AppLanguage.korean:
        return '🇰🇷';
      case AppLanguage.chinese:
        return '🇨🇳';
      case AppLanguage.arabic:
        return '🇸🇦';
      case AppLanguage.russian:
        return '🇷🇺';
      case AppLanguage.hindi:
        return '🇮🇳';
      case AppLanguage.turkish:
        return '🇹🇷';
      case AppLanguage.polish:
        return '🇵🇱';
      case AppLanguage.swedish:
        return '🇸🇪';
      case AppLanguage.norwegian:
        return '🇳🇴';
      case AppLanguage.danish:
        return '🇩🇰';
      case AppLanguage.finnish:
        return '🇫🇮';
    }
  }

  /// Locale for this language
  Locale get locale {
    return Locale(code);
  }
}

/// Helper class for language detection and utilities
class LanguageHelper {
  /// Detect device language and return corresponding AppLanguage
  static AppLanguage detectDeviceLanguage() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    final languageCode = deviceLocale.languageCode.toLowerCase();

    // Match device language code to AppLanguage
    for (final language in AppLanguage.values) {
      if (language.code == languageCode) {
        return language;
      }
    }

    // Default to English if not found
    return AppLanguage.english;
  }

  /// Get AppLanguage from language code
  static AppLanguage? fromCode(String code) {
    for (final language in AppLanguage.values) {
      if (language.code == code.toLowerCase()) {
        return language;
      }
    }
    return null;
  }

  /// Get AppLanguage from name
  static AppLanguage? fromName(String name) {
    for (final language in AppLanguage.values) {
      if (language.name.toLowerCase() == name.toLowerCase()) {
        return language;
      }
    }
    return null;
  }
}

