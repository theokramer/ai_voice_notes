import 'dart:convert';
import '../widgets/animated_background.dart';

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
  
  Settings({
    this.themePreset = ThemePreset.modern,
    this.audioQuality = AudioQuality.high,
    this.hapticsEnabled = true,
    this.useUnifiedNoteView = true,
    this.backgroundStyle = BackgroundStyle.clouds, // Default to subtle clouds
    this.hasRequestedMicPermission = false,
  });

  Settings copyWith({
    ThemePreset? themePreset,
    AudioQuality? audioQuality,
    bool? hapticsEnabled,
    bool? useUnifiedNoteView,
    BackgroundStyle? backgroundStyle,
    bool? hasRequestedMicPermission,
  }) {
    return Settings(
      themePreset: themePreset ?? this.themePreset,
      audioQuality: audioQuality ?? this.audioQuality,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      useUnifiedNoteView: useUnifiedNoteView ?? this.useUnifiedNoteView,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      hasRequestedMicPermission: hasRequestedMicPermission ?? this.hasRequestedMicPermission,
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
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
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
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Settings.fromJsonString(String jsonString) =>
      Settings.fromJson(jsonDecode(jsonString));
}

