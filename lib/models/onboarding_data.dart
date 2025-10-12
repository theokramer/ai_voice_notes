import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'app_language.dart';

/// Stores user responses from onboarding questions
class OnboardingData {
  // Engagement questions
  String? hearAboutUs;
  
  // Settings questions
  String? useCase;
  AudioQuality? audioQuality;
  bool? aiAutopilot; // true = autopilot, false = hybrid/assisted
  
  // Language selection
  AppLanguage? selectedLanguage;

  /// Check if all required onboarding questions have been answered
  bool get isComplete =>
      hearAboutUs != null &&
      useCase != null &&
      audioQuality != null &&
      aiAutopilot != null;

  /// Save onboarding data to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Engagement questions
    if (hearAboutUs != null) {
      await prefs.setString('onboarding_hear_about_us', hearAboutUs!);
    }
    
    // Settings questions
    if (useCase != null) {
      await prefs.setString('onboarding_use_case', useCase!);
    }
    
    if (audioQuality != null) {
      await prefs.setString('onboarding_audio_quality', audioQuality!.name);
    }
    
    if (aiAutopilot != null) {
      await prefs.setBool('onboarding_ai_autopilot', aiAutopilot!);
    }
    
    // Language
    if (selectedLanguage != null) {
      await prefs.setString('onboarding_selected_language', selectedLanguage!.name);
    }
  }

  /// Load onboarding data from SharedPreferences
  static Future<OnboardingData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = OnboardingData();
    
    // Engagement questions
    data.hearAboutUs = prefs.getString('onboarding_hear_about_us');
    
    // Settings questions
    data.useCase = prefs.getString('onboarding_use_case');
    
    final audioQualityString = prefs.getString('onboarding_audio_quality');
    if (audioQualityString != null) {
      data.audioQuality = AudioQuality.values.firstWhere(
        (e) => e.name == audioQualityString,
        orElse: () => AudioQuality.medium,
      );
    }
    
    data.aiAutopilot = prefs.getBool('onboarding_ai_autopilot');
    
    // Language
    final languageString = prefs.getString('onboarding_selected_language');
    if (languageString != null) {
      try {
        data.selectedLanguage = AppLanguage.values.firstWhere(
          (e) => e.name == languageString,
        );
      } catch (e) {
        data.selectedLanguage = null;
      }
    }
    
    return data;
  }
}
