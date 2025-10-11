import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';
import '../services/haptic_service.dart';
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

  Future<void> updateUnifiedNoteView(bool enabled) async {
    await updateSettings(_settings.copyWith(useUnifiedNoteView: enabled));
  }

  Future<void> updateBackgroundStyle(BackgroundStyle style) async {
    await updateSettings(_settings.copyWith(backgroundStyle: style));
  }

  Future<void> setMicPermissionRequested() async {
    await updateSettings(_settings.copyWith(hasRequestedMicPermission: true));
  }

  bool get hasRequestedMicPermission => _settings.hasRequestedMicPermission;

  Future<void> updateAutoCloseAfterEntry(bool enabled) async {
    await updateSettings(_settings.copyWith(autoCloseAfterEntry: enabled));
  }

  bool get autoCloseAfterEntry => _settings.autoCloseAfterEntry;

  Future<void> clearCache() async {
    // Placeholder for cache clearing logic
    notifyListeners();
  }
}

