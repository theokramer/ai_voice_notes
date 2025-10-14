import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/app_language.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'waveform_visualizer.dart';

/// Overlay widget that shows voice command hints during recording
class RecordingOverlay extends StatelessWidget {
  final bool isLocked;
  final bool isPaused;
  final VoidCallback? onStop;
  final VoidCallback? onDiscard;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final Duration recordingDuration;
  final double amplitude;
  final List<double> amplitudeHistory;

  const RecordingOverlay({
    super.key,
    required this.isLocked,
    required this.isPaused,
    this.onStop,
    this.onDiscard,
    this.onPause,
    this.onResume,
    required this.recordingDuration,
    required this.amplitude,
    required this.amplitudeHistory,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currentLanguage = settingsProvider.preferredLanguage;
    final themeConfig = settingsProvider.currentThemeConfig;

    // Get voice command examples based on current language
    final examples = _getVoiceCommandExamples(currentLanguage);

    // Format duration as M:SS
    final minutes = recordingDuration.inMinutes;
    final seconds = recordingDuration.inSeconds % 60;
    final durationText = '${minutes}:${seconds.toString().padLeft(2, '0')}';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Stack(
          children: [
              // Main content area
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Status with timer and save indicator (top)
                      _buildCompactStatusBar(context, themeConfig, durationText),
                      
                      const SizedBox(height: 32),
                      
                      // Voice Commands Available (persistent, no fade out)
                      _buildVoiceCommands(context, themeConfig, examples),
                      
                      const SizedBox(height: 32),
                      
                      // Action buttons (ONLY when locked)
                      if (isLocked) ...[
                        _buildActionButtons(context, themeConfig),
                        const SizedBox(height: 32),
                      ],
                      
                      const Spacer(),
                      
                      // Waveform visualization (at bottom above mic)
                      _buildWaveform(context, themeConfig),
                      
                      const SizedBox(height: 100), // Space for microphone button above
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatusBar(BuildContext context, ThemeConfig themeConfig, String durationText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: themeConfig.accentLight.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeConfig.accentLight.withOpacity(0.3),
          width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
          // Recording indicator
                        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: themeConfig.accentLight,
                            shape: BoxShape.circle,
                          ),
                        ).animate(onPlay: (controller) => controller.repeat())
                            .fadeIn(duration: 500.ms)
                            .then()
                            .fadeOut(duration: 500.ms),
                        const SizedBox(width: 8),
          // Compact status text
                        Text(
            isPaused 
                ? 'Paused $durationText'
                : isLocked 
                    ? 'Locked $durationText' 
                    : 'Recording $durationText',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
          const SizedBox(width: 8),
          // Save status indicator (smaller)
          Icon(
            Icons.cloud_upload_outlined,
            size: 14,
            color: themeConfig.accentLight.withOpacity(0.7),
          ).animate(onPlay: (controller) => controller.repeat())
              .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.1, 1.1), duration: 1000.ms)
              .then()
              .scale(begin: const Offset(1.1, 1.1), end: const Offset(1.0, 1.0), duration: 1000.ms),
        ],
      ),
    );
  }


  Widget _buildVoiceCommands(BuildContext context, ThemeConfig themeConfig, List<String> examples) {
    return Column(
      children: [
        Text(
          'Voice Commands Available:',
          style: TextStyle(
            color: AppTheme.textPrimary.withOpacity(0.8),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...examples.map((example) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '• $example',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeConfig themeConfig) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Discard button (icon only)
        _buildCompactActionButton(
          context: context,
          themeConfig: themeConfig,
          icon: Icons.delete_outline,
          onPressed: () => _showDiscardConfirmation(context),
          isDestructive: true,
        ),
        // Pause/Play button (icon only)
        _buildCompactActionButton(
          context: context,
          themeConfig: themeConfig,
          icon: isPaused ? Icons.play_arrow : Icons.pause,
          onPressed: isPaused ? onResume : onPause,
          isDestructive: false,
        ),
        // Stop button (icon only)
        _buildCompactActionButton(
          context: context,
          themeConfig: themeConfig,
          icon: Icons.stop,
          onPressed: onStop,
          isDestructive: false,
        ),
      ],
    );
  }

  Widget _buildCompactActionButton({
    required BuildContext context,
    required ThemeConfig themeConfig,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDestructive,
  }) {
    final backgroundColor = isDestructive 
        ? Colors.red.withOpacity(0.2)
        : themeConfig.accentLight.withOpacity(0.2);
    final borderColor = isDestructive 
        ? Colors.red.withOpacity(0.5)
        : themeConfig.accentLight.withOpacity(0.5);
    final iconColor = isDestructive 
        ? Colors.red
        : themeConfig.accentLight;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }


  Widget _buildWaveform(BuildContext context, ThemeConfig themeConfig) {
    return Container(
      height: 120, // Increased height for prominence
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: VoiceMemoWaveform(
        isActive: !isPaused, // Don't animate when paused
        height: 120,
        color: themeConfig.accentLight,
        currentAmplitude: amplitude,
        amplitudeHistory: amplitudeHistory,
      ),
    );
  }

  void _showDiscardConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.glassStrongSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: Text(
          'Discard Recording?',
          style: TextStyle(
            color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
        ),
        content: Text(
          'This will permanently delete the current recording.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDiscard?.call();
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getVoiceCommandExamples(AppLanguage language) {
    switch (language) {
      case AppLanguage.german:
        return [
          'Neuer Ordner [Name]',
          'An letzte Notiz',
          'Notiz [Titel] in [Ordner]',
          'Ordner [Name] erstellen',
        ];
      case AppLanguage.spanish:
        return [
          'Nueva carpeta [nombre]',
          'Añadir a última nota',
          'Nota [título] en [carpeta]',
          'Crear carpeta [nombre]',
        ];
      case AppLanguage.french:
        return [
          'Nouveau dossier [nom]',
          'Ajouter à dernière note',
          'Note [titre] dans [dossier]',
          'Créer dossier [nom]',
        ];
      case AppLanguage.english:
        return [
          'New folder [name]',
          'Append to last note',
          'Note [title] in [folder]',
          'Create folder [name]',
        ];
    }
  }
}
