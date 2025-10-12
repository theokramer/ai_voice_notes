import 'dart:convert';
import 'package:flutter/foundation.dart';
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

enum OrganizationMode {
  autoOrganize,  // AI decides folder (can create new folders)
  manualOrganize // Save to Unorganized, batch organize later
}

enum TranscriptionMode {
  plain,      // Just transcribe speech to text
  aiBeautify  // AI structures and beautifies the text
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
  final OrganizationMode organizationMode;
  final TranscriptionMode transcriptionMode;
  final bool showOrganizationHints;
  final bool allowAICreateFolders;
  
  /// User preference learning: Map of folder ID -> list of note content keywords that were rejected
  /// When a user moves a note away from an AI-suggested folder, we store the note's content pattern
  /// to avoid suggesting that folder for similar notes in the future
  final Map<String, List<String>> rejectedFolderSuggestions;
  
  Settings({
    this.themePreset = ThemePreset.modern,
    this.audioQuality = AudioQuality.high,
    this.hapticsEnabled = true,
    this.useUnifiedNoteView = true,
    this.backgroundStyle = BackgroundStyle.clouds, // Default to gentle clouds
    this.hasRequestedMicPermission = false,
    this.autoCloseAfterEntry = false,
    this.preferredLanguage,
    this.organizationMode = OrganizationMode.autoOrganize,
    this.transcriptionMode = TranscriptionMode.aiBeautify,
    this.showOrganizationHints = true,
    this.allowAICreateFolders = true,
    this.rejectedFolderSuggestions = const {},
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
    OrganizationMode? organizationMode,
    TranscriptionMode? transcriptionMode,
    bool? showOrganizationHints,
    bool? allowAICreateFolders,
    Map<String, List<String>>? rejectedFolderSuggestions,
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
      organizationMode: organizationMode ?? this.organizationMode,
      transcriptionMode: transcriptionMode ?? this.transcriptionMode,
      showOrganizationHints: showOrganizationHints ?? this.showOrganizationHints,
      allowAICreateFolders: allowAICreateFolders ?? this.allowAICreateFolders,
      rejectedFolderSuggestions: rejectedFolderSuggestions ?? this.rejectedFolderSuggestions,
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
      'organizationMode': organizationMode.name,
      'transcriptionMode': transcriptionMode.name,
      'showOrganizationHints': showOrganizationHints,
      'allowAICreateFolders': allowAICreateFolders,
      'rejectedFolderSuggestions': rejectedFolderSuggestions,
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
    
    // Parse rejectedFolderSuggestions
    Map<String, List<String>> rejectedSuggestions = {};
    if (json['rejectedFolderSuggestions'] != null) {
      try {
        final rawMap = json['rejectedFolderSuggestions'] as Map<String, dynamic>;
        rawMap.forEach((key, value) {
          if (value is List) {
            rejectedSuggestions[key] = List<String>.from(value);
          }
        });
      } catch (e) {
        debugPrint('Error parsing rejectedFolderSuggestions: $e');
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
      organizationMode: OrganizationMode.values.firstWhere(
        (e) => e.name == json['organizationMode'],
        orElse: () => OrganizationMode.autoOrganize,
      ),
      transcriptionMode: TranscriptionMode.values.firstWhere(
        (e) => e.name == json['transcriptionMode'],
        orElse: () => TranscriptionMode.aiBeautify,
      ),
      showOrganizationHints: json['showOrganizationHints'] ?? true,
      allowAICreateFolders: json['allowAICreateFolders'] ?? true,
      rejectedFolderSuggestions: rejectedSuggestions,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Settings.fromJsonString(String jsonString) =>
      Settings.fromJson(jsonDecode(jsonString));
}

