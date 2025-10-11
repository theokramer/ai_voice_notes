import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';

/// Stores user responses from onboarding questions
class OnboardingData {
  String? noteFrequency;
  String? useCase;
  AudioQuality? audioQuality;
  bool? autoCloseAfterEntry;

  /// Check if all onboarding questions have been answered
  bool get isComplete =>
      noteFrequency != null &&
      useCase != null &&
      audioQuality != null &&
      autoCloseAfterEntry != null;

  /// Save onboarding data to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (noteFrequency != null) {
      await prefs.setString('onboarding_note_frequency', noteFrequency!);
    }
    
    if (useCase != null) {
      await prefs.setString('onboarding_use_case', useCase!);
    }
    
    if (audioQuality != null) {
      await prefs.setString('onboarding_audio_quality', audioQuality!.name);
    }
    
    if (autoCloseAfterEntry != null) {
      await prefs.setBool('onboarding_auto_close_after_entry', autoCloseAfterEntry!);
    }
  }

  /// Load onboarding data from SharedPreferences
  static Future<OnboardingData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = OnboardingData();
    
    data.noteFrequency = prefs.getString('onboarding_note_frequency');
    data.useCase = prefs.getString('onboarding_use_case');
    
    final audioQualityString = prefs.getString('onboarding_audio_quality');
    if (audioQualityString != null) {
      data.audioQuality = AudioQuality.values.firstWhere(
        (e) => e.name == audioQualityString,
        orElse: () => AudioQuality.medium,
      );
    }
    
    data.autoCloseAfterEntry = prefs.getBool('onboarding_auto_close_after_entry');
    
    return data;
  }
}
