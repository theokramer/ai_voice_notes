import 'dart:ui';

/// Supported languages in the app
enum AppLanguage {
  english,
  spanish,
  french,
  german,
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
    }
  }

  /// Localized display name (translated into the language itself)
  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.spanish:
        return 'Español';
      case AppLanguage.french:
        return 'Français';
      case AppLanguage.german:
        return 'Deutsch';
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

