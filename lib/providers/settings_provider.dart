import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';
import '../models/app_language.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';

class SettingsProvider extends ChangeNotifier {
  Settings _settings = Settings();
  bool _isLoading = false;

  Settings get settings => _settings;
  bool get isLoading => _isLoading;
  
  // Get current theme config based on settings
  ThemeConfig get currentThemeConfig => AppTheme.getThemeConfig(_settings.themePreset);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('settings');
      if (settingsJson != null) {
        _settings = Settings.fromJsonString(settingsJson);
      }
      // Update haptic service with the loaded setting
      HapticService.setEnabled(_settings.hapticsEnabled);
      
      // Update localization service with the loaded language preference
      final language = _settings.preferredLanguage ?? LanguageHelper.detectDeviceLanguage();
      LocalizationService().setLanguage(language);
      debugPrint('🌍 Initialized app with language: ${language.name}');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(Settings newSettings) async {
    _settings = newSettings;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings', _settings.toJsonString());
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> updateThemePreset(ThemePreset preset) async {
    await updateSettings(_settings.copyWith(themePreset: preset));
  }

  Future<void> updateAudioQuality(AudioQuality quality) async {
    await updateSettings(_settings.copyWith(audioQuality: quality));
  }

  Future<void> updateHapticsEnabled(bool enabled) async {
    HapticService.setEnabled(enabled);
    await updateSettings(_settings.copyWith(hapticsEnabled: enabled));
  }


  Future<void> updateBackgroundStyle(BackgroundStyle style) async {
    await updateSettings(_settings.copyWith(backgroundStyle: style));
  }

  Future<void> setMicPermissionRequested() async {
    await updateSettings(_settings.copyWith(hasRequestedMicPermission: true));
  }

  bool get hasRequestedMicPermission => _settings.hasRequestedMicPermission;

  Future<void> toggleSimpleMode(bool enabled) async {
    await updateSettings(_settings.copyWith(isSimpleMode: enabled));
  }

  bool get isSimpleMode => _settings.isSimpleMode;


  Future<void> clearCache() async {
    // Placeholder for cache clearing logic
    notifyListeners();
  }

  Future<void> updatePreferredLanguage(AppLanguage language) async {
    // Update settings
    await updateSettings(_settings.copyWith(preferredLanguage: language));
    // Update localization service
    LocalizationService().setLanguage(language);
    notifyListeners();
  }

  AppLanguage get preferredLanguage => 
      _settings.preferredLanguage ?? LanguageHelper.detectDeviceLanguage();

  // Smart Notes settings

  Future<void> updateOrganizationMode(OrganizationMode mode) async {
    await updateSettings(_settings.copyWith(organizationMode: mode));
  }


  
  /// Add a rejected folder suggestion for user preference learning
  /// [folderId] - The folder that was rejected
  /// [noteContent] - The content of the note (will be processed into keywords)
  Future<void> addRejectedFolderSuggestion(String folderId, String noteContent) async {
    // Extract keywords from note content (first 100 chars, lowercased)
    final contentPattern = noteContent.trim().toLowerCase().substring(
      0,
      noteContent.length > 100 ? 100 : noteContent.length,
    );
    
    final updatedRejections = Map<String, List<String>>.from(_settings.rejectedFolderSuggestions);
    
    if (!updatedRejections.containsKey(folderId)) {
      updatedRejections[folderId] = [];
    }
    
    // Add the pattern if not already present
    if (!updatedRejections[folderId]!.contains(contentPattern)) {
      updatedRejections[folderId]!.add(contentPattern);
      
      // Limit to 50 patterns per folder to avoid unbounded growth
      if (updatedRejections[folderId]!.length > 50) {
        updatedRejections[folderId]!.removeAt(0); // Remove oldest
      }
      
      debugPrint('📊 Added rejected suggestion for folder $folderId');
      await updateSettings(_settings.copyWith(rejectedFolderSuggestions: updatedRejections));
    }
  }
  
  /// Check if a folder should be avoided for a given note content
  /// Returns true if the folder was previously rejected for similar content
  bool shouldAvoidFolderSuggestion(String folderId, String noteContent) {
    final rejectedPatterns = _settings.rejectedFolderSuggestions[folderId];
    if (rejectedPatterns == null || rejectedPatterns.isEmpty) {
      return false;
    }
    
    final contentLower = noteContent.trim().toLowerCase();
    
    // Check if any rejected pattern matches (simple substring match)
    for (final pattern in rejectedPatterns) {
      if (contentLower.contains(pattern) || pattern.contains(contentLower.substring(0, contentLower.length > 100 ? 100 : contentLower.length))) {
        debugPrint('🚫 Avoiding folder $folderId due to previous rejection');
        return true;
      }
    }
    
    return false;
  }
  
  /// Clear old rejections (can be called periodically, e.g., once a month)
  Future<void> clearOldRejections() async {
    await updateSettings(_settings.copyWith(rejectedFolderSuggestions: {}));
    debugPrint('🗑️ Cleared all rejected folder suggestions');
  }
}


