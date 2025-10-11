import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'app_language.dart';

/// Stores user responses from onboarding questions
class OnboardingData {
  // Engagement questions
  String? hearAboutUs;
  String? noteTakingStyle;
  String? captureIdeasTiming;
  
  // Settings questions
  String? useCase;
  AudioQuality? audioQuality;
  bool? autoCloseAfterEntry;
  
  // Language selection
  AppLanguage? selectedLanguage;

  /// Check if all required onboarding questions have been answered
  bool get isComplete =>
      hearAboutUs != null &&
      noteTakingStyle != null &&
      captureIdeasTiming != null &&
      useCase != null &&
      audioQuality != null &&
      autoCloseAfterEntry != null;

  /// Save onboarding data to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Engagement questions
    if (hearAboutUs != null) {
      await prefs.setString('onboarding_hear_about_us', hearAboutUs!);
    }
    
    if (noteTakingStyle != null) {
      await prefs.setString('onboarding_note_taking_style', noteTakingStyle!);
    }
    
    if (captureIdeasTiming != null) {
      await prefs.setString('onboarding_capture_ideas_timing', captureIdeasTiming!);
    }
    
    // Settings questions
    if (useCase != null) {
      await prefs.setString('onboarding_use_case', useCase!);
    }
    
    if (audioQuality != null) {
      await prefs.setString('onboarding_audio_quality', audioQuality!.name);
    }
    
    if (autoCloseAfterEntry != null) {
      await prefs.setBool('onboarding_auto_close_after_entry', autoCloseAfterEntry!);
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
    data.noteTakingStyle = prefs.getString('onboarding_note_taking_style');
    data.captureIdeasTiming = prefs.getString('onboarding_capture_ideas_timing');
    
    // Settings questions
    data.useCase = prefs.getString('onboarding_use_case');
    
    final audioQualityString = prefs.getString('onboarding_audio_quality');
    if (audioQualityString != null) {
      data.audioQuality = AudioQuality.values.firstWhere(
        (e) => e.name == audioQualityString,
        orElse: () => AudioQuality.medium,
      );
    }
    
    data.autoCloseAfterEntry = prefs.getBool('onboarding_auto_close_after_entry');
    
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
