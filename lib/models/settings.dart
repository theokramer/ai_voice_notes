import 'dart:convert';
import '../widgets/animated_background.dart';
import 'app_language.dart';

enum ThemePreset {
  modern,
  oceanBlue,
  sunsetOrange,
  forestGreen,
  aurora,
}

enum AudioQuality {
  low,
  medium,
  high,
}

class Settings {
  final ThemePreset themePreset;
  final AudioQuality audioQuality;
  final bool hapticsEnabled;
  final bool useUnifiedNoteView;
  final BackgroundStyle backgroundStyle;
  final bool hasRequestedMicPermission;
  final bool autoCloseAfterEntry;
  final AppLanguage? preferredLanguage;
  
  Settings({
    this.themePreset = ThemePreset.modern,
    this.audioQuality = AudioQuality.high,
    this.hapticsEnabled = true,
    this.useUnifiedNoteView = true,
    this.backgroundStyle = BackgroundStyle.clouds, // Default to gentle clouds
    this.hasRequestedMicPermission = false,
    this.autoCloseAfterEntry = false,
    this.preferredLanguage,
  });

  Settings copyWith({
    ThemePreset? themePreset,
    AudioQuality? audioQuality,
    bool? hapticsEnabled,
    bool? useUnifiedNoteView,
    BackgroundStyle? backgroundStyle,
    bool? hasRequestedMicPermission,
    bool? autoCloseAfterEntry,
    AppLanguage? preferredLanguage,
  }) {
    return Settings(
      themePreset: themePreset ?? this.themePreset,
      audioQuality: audioQuality ?? this.audioQuality,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      useUnifiedNoteView: useUnifiedNoteView ?? this.useUnifiedNoteView,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      hasRequestedMicPermission: hasRequestedMicPermission ?? this.hasRequestedMicPermission,
      autoCloseAfterEntry: autoCloseAfterEntry ?? this.autoCloseAfterEntry,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themePreset': themePreset.name,
      'audioQuality': audioQuality.name,
      'hapticsEnabled': hapticsEnabled,
      'useUnifiedNoteView': useUnifiedNoteView,
      'backgroundStyle': backgroundStyle.name,
      'hasRequestedMicPermission': hasRequestedMicPermission,
      'autoCloseAfterEntry': autoCloseAfterEntry,
      'preferredLanguage': preferredLanguage?.name,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    AppLanguage? language;
    if (json['preferredLanguage'] != null) {
      try {
        language = AppLanguage.values.firstWhere(
          (e) => e.name == json['preferredLanguage'],
        );
      } catch (e) {
        language = null;
      }
    }
    
    return Settings(
      themePreset: ThemePreset.values.firstWhere(
        (e) => e.name == json['themePreset'],
        orElse: () => ThemePreset.modern,
      ),
      audioQuality: AudioQuality.values.firstWhere(
        (e) => e.name == json['audioQuality'],
        orElse: () => AudioQuality.high,
      ),
      hapticsEnabled: json['hapticsEnabled'] ?? true,
      useUnifiedNoteView: json['useUnifiedNoteView'] ?? true,
      backgroundStyle: BackgroundStyle.values.firstWhere(
        (e) => e.name == json['backgroundStyle'],
        orElse: () => BackgroundStyle.clouds,
      ),
      hasRequestedMicPermission: json['hasRequestedMicPermission'] ?? false,
      autoCloseAfterEntry: json['autoCloseAfterEntry'] ?? false,
      preferredLanguage: language,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Settings.fromJsonString(String jsonString) =>
      Settings.fromJson(jsonDecode(jsonString));
}

