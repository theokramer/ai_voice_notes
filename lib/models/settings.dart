import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'app_language.dart';

enum ThemePreset {
  oceanBlue,
  sunsetOrange,
  forestGreen,
  aurora,
  midnightPurple,
  cherryBlossom,
  arcticBlue,
  emeraldNight,
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

class Settings {
  final ThemePreset themePreset;
  final AudioQuality audioQuality;
  final bool hapticsEnabled;
  final bool hasRequestedMicPermission;
  final AppLanguage? preferredLanguage;
  final OrganizationMode organizationMode;
  
  /// User preference learning: Map of folder ID -> list of note content keywords that were rejected
  /// When a user moves a note away from an AI-suggested folder, we store the note's content pattern
  /// to avoid suggesting that folder for similar notes in the future
  final Map<String, List<String>> rejectedFolderSuggestions;
  
  Settings({
    this.themePreset = ThemePreset.oceanBlue,
    this.audioQuality = AudioQuality.high,
    this.hapticsEnabled = true,
    this.hasRequestedMicPermission = false,
    this.preferredLanguage,
    this.organizationMode = OrganizationMode.autoOrganize,
    this.rejectedFolderSuggestions = const {},
  });

  Settings copyWith({
    ThemePreset? themePreset,
    AudioQuality? audioQuality,
    bool? hapticsEnabled,
    bool? hasRequestedMicPermission,
    AppLanguage? preferredLanguage,
    OrganizationMode? organizationMode,
    Map<String, List<String>>? rejectedFolderSuggestions,
  }) {
    return Settings(
      themePreset: themePreset ?? this.themePreset,
      audioQuality: audioQuality ?? this.audioQuality,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      hasRequestedMicPermission: hasRequestedMicPermission ?? this.hasRequestedMicPermission,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      organizationMode: organizationMode ?? this.organizationMode,
      rejectedFolderSuggestions: rejectedFolderSuggestions ?? this.rejectedFolderSuggestions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themePreset': themePreset.name,
      'audioQuality': audioQuality.name,
      'hapticsEnabled': hapticsEnabled,
      'hasRequestedMicPermission': hasRequestedMicPermission,
      'preferredLanguage': preferredLanguage?.name,
      'organizationMode': organizationMode.name,
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
        orElse: () => ThemePreset.oceanBlue,
      ),
      audioQuality: AudioQuality.values.firstWhere(
        (e) => e.name == json['audioQuality'],
        orElse: () => AudioQuality.high,
      ),
      hapticsEnabled: json['hapticsEnabled'] ?? true,
      hasRequestedMicPermission: json['hasRequestedMicPermission'] ?? false,
      preferredLanguage: language,
      organizationMode: OrganizationMode.values.firstWhere(
        (e) => e.name == json['organizationMode'],
        orElse: () => OrganizationMode.autoOrganize,
      ),
      rejectedFolderSuggestions: rejectedSuggestions,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Settings.fromJsonString(String jsonString) =>
      Settings.fromJson(jsonDecode(jsonString));
}

