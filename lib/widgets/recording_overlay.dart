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
                      
                      const SizedBox(height: 28),
                      
                      // Voice Commands Available (persistent, no fade out)
                      _buildVoiceCommands(context, themeConfig, examples),
                      
                      const SizedBox(height: 28),
                      
                      // Action buttons (ONLY when locked)
                      if (isLocked) ...[
                        _buildActionButtons(context, themeConfig),
                        const SizedBox(height: 28),
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
    // Parse commands with their icons
    final commands = _parseCommandExamples(examples);
    
    return Column(
      children: [
        // Compact Header with instruction
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: themeConfig.accentLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: themeConfig.accentLight.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic_rounded,
                    color: themeConfig.accentLight,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
              Text(
                'Voice Commands',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Say commands after recording starts',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.8),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
            .slideY(begin: -0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
        
        // Compact Command Cards in rows
        _buildCompactCommandCards(themeConfig, commands),
      ],
    );
  }

  Widget _buildCompactCommandCards(ThemeConfig themeConfig, List<_VoiceCommandDisplay> commands) {
    final nonTipCommands = commands.where((cmd) => !cmd.isTip).toList();
    
    return Column(
      children: [
        // All three commands in a single row with equal heights
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildCompactCommandCard(themeConfig, nonTipCommands[0])
                    .animate(delay: 0.ms)
                    .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                    .slideX(begin: -0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactCommandCard(themeConfig, nonTipCommands[1])
                    .animate(delay: 80.ms)
                    .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                    .slideY(begin: -0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactCommandCard(themeConfig, nonTipCommands[2])
                    .animate(delay: 160.ms)
                    .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                    .slideX(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Combination note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: themeConfig.accentLight.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: themeConfig.accentLight.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: themeConfig.accentLight.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'You can combine commands:',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '"title Meeting in folder Work"',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        )
            .animate(delay: 240.ms)
            .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
            .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildCompactCommandCard(ThemeConfig themeConfig, _VoiceCommandDisplay cmd) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: themeConfig.accentDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: themeConfig.accentLight.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Command text - reasonable size
          Text(
            cmd.command,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          
          // Description - reasonable size
          Text(
            cmd.description,
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.05,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  List<_VoiceCommandDisplay> _parseCommandExamples(List<String> examples) {
    final commands = <_VoiceCommandDisplay>[];
    
    for (final example in examples) {
      if (example.isEmpty) continue;
      
      // Check if it's the tip
      if (example.startsWith('💡')) {
        commands.add(_VoiceCommandDisplay(
          isTip: true,
          text: example.substring(2).trim(),
          icon: Icons.lightbulb,
          command: '',
          description: '',
        ));
        continue;
      }
      
      // Parse command format: "command" → description
      final parts = example.split('→');
      if (parts.length != 2) continue;
      
      final commandPart = parts[0].trim().replaceAll('"', '').replaceAll('•', '').trim();
      final description = parts[1].trim();
      
      // Determine icon based on description/command
      IconData icon;
      if (commandPart.contains('neu') || commandPart.contains('new') || 
          commandPart.contains('nouvelle') || commandPart.contains('nuevo')) {
        icon = Icons.create_new_folder_outlined;
      } else if (commandPart.contains('ergänzung') || commandPart.contains('addition') || 
                 commandPart.contains('ajout') || commandPart.contains('adición') ||
                 commandPart.contains('letzten') || commandPart.contains('last') ||
                 commandPart.contains('última') || commandPart.contains('dernière')) {
        icon = Icons.add_circle_outline;
      } else if (commandPart.contains('titel') || commandPart.contains('title') || 
                 commandPart.contains('titre') || commandPart.contains('título')) {
        icon = Icons.title;
      } else if (commandPart.contains('ordner') || commandPart.contains('folder') || 
                 commandPart.contains('dossier') || commandPart.contains('carpeta')) {
        icon = Icons.folder_outlined;
      } else {
        icon = Icons.layers_outlined; // For combined commands
      }
      
      commands.add(_VoiceCommandDisplay(
        isTip: false,
        text: commandPart,
        icon: icon,
        command: commandPart.split('/').first.trim(), // Take first variant for display
        description: description,
      ));
    }
    
    return commands;
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

  List<String> _getVoiceCommandExamples(AppLanguage? language) {
    language ??= AppLanguage.english; // Default fallback
    switch (language) {
      case AppLanguage.german:
        return [
          '"ergänzung" / "zur letzten notiz" → An die letzte Notiz anhängen',
          '"titel [Titel]" → Titel für diese Notiz setzen',
          '"ordner [Name]" → In Ordner speichern',
        ];
      case AppLanguage.spanish:
        return [
          '"adición" / "añadir a la última" → Añadir a la última nota',
          '"título [título]" → Establecer título para esta nota',
          '"carpeta [nombre]" → Guardar en carpeta',
        ];
      case AppLanguage.french:
        return [
          '"ajout" / "ajouter à dernière note" → Ajouter à la dernière note',
          '"titre [titre]" → Définir titre pour cette note',
          '"dossier [nom]" → Sauvegarder dans dossier',
        ];
      case AppLanguage.english:
        return [
          '"addition" / "add to last note" → Append to the last note',
          '"title [title]" → Set title for this note',
          '"folder [name]" → Save to folder',
        ];
    }
  }
}

/// Helper class to parse and display voice commands
class _VoiceCommandDisplay {
  final bool isTip;
  final String text;
  final IconData icon;
  final String command;
  final String description;
  
  _VoiceCommandDisplay({
    required this.isTip,
    required this.text,
    required this.icon,
    required this.command,
    required this.description,
  });
}
