import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/app_language.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'waveform_visualizer.dart';

/// Stunning overlay widget that shows voice command hints during recording
class RecordingOverlay extends StatefulWidget {
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
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currentLanguage = settingsProvider.preferredLanguage;
    final themeConfig = settingsProvider.currentThemeConfig;

    // Get voice command examples based on current language
    final commands = _getVoiceCommands(currentLanguage);

    // Format duration as M:SS
    final minutes = widget.recordingDuration.inMinutes;
    final seconds = widget.recordingDuration.inSeconds % 60;
    final durationText = '${minutes}:${seconds.toString().padLeft(2, '0')}';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                children: [
                  // Enhanced Status Bar
                  _buildEnhancedStatusBar(context, themeConfig, durationText),
                  
                  const SizedBox(height: 28),
                  
                  // Voice Commands - Horizontal Scroll (No Cropping!)
                  _buildHorizontalVoiceCommands(context, themeConfig, commands),
                  
                  const SizedBox(height: 24),
                  
                  // Professional Action Buttons (ONLY when locked)
                  if (widget.isLocked) ...[
                    _buildStunningActionButtons(context, themeConfig),
                    const SizedBox(height: 24),
                  ],
                  
                  const Spacer(),
                  
                  // Waveform Visualization
                  _buildHeroWaveform(context, themeConfig),
                  
                  const SizedBox(height: 140), // Space for microphone button
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Enhanced status bar with better animations and visual hierarchy
  Widget _buildEnhancedStatusBar(BuildContext context, ThemeConfig themeConfig, String durationText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.glassRecordingSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: themeConfig.accentLight.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtle pulsing recording indicator
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: themeConfig.accentLight,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
          
          const SizedBox(width: 10),
          
          // Status text - professional size
          Text(
            widget.isPaused 
                ? 'Paused $durationText'
                : widget.isLocked 
                    ? 'Locked $durationText' 
                    : 'Recording $durationText',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          
          const SizedBox(width: 10),
          
          // Auto-save indicator
          Icon(
            Icons.cloud_done_outlined,
            size: 16,
            color: themeConfig.accentLight.withOpacity(0.7),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
        .slideY(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// Horizontal scrollable voice commands with full text visibility
  Widget _buildHorizontalVoiceCommands(BuildContext context, ThemeConfig themeConfig, List<_VoiceCommand> commands) {
    return Column(
      children: [
        // Header with instruction
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeConfig.accentLight.withOpacity(0.15),
                themeConfig.accentDark.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: themeConfig.accentLight.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeConfig.accentLight.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeConfig.accentLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: themeConfig.accentLight,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Voice Commands',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
            .slideY(begin: -0.15, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        
        const SizedBox(height: 14),
        
        // Horizontal PageView for commands
        SizedBox(
          height: 135,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: commands.length,
            itemBuilder: (context, index) {
              return _buildCommandCard(
                context, 
                themeConfig, 
                commands[index],
                index,
              );
            },
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            commands.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? themeConfig.accentLight
                    : themeConfig.accentLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ).animate(target: _currentPage == index ? 1 : 0)
                .scaleX(duration: 300.ms, curve: Curves.easeOutCubic),
          ),
        ),
      ],
    );
  }

  /// Individual command card with full text (no cropping!)
  Widget _buildCommandCard(BuildContext context, ThemeConfig themeConfig, _VoiceCommand command, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeConfig.accentLight.withOpacity(0.12),
            themeConfig.accentDark.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: themeConfig.accentLight.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: themeConfig.accentLight.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with enhanced background
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeConfig.accentLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              command.icon,
              color: themeConfig.accentLight,
              size: 20,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Command text - full visibility
          Text(
            command.command,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
          
          const SizedBox(height: 6),
          
          // Description - full visibility
          Flexible(
            child: Text(
              command.description,
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.05,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    )
        .animate(delay: (index * 80).ms)
        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
        .slideX(
          begin: index.isEven ? -0.2 : 0.2, 
          end: 0, 
          duration: 400.ms, 
          curve: Curves.easeOutCubic,
        );
  }

  /// Professional action buttons with clear labels
  Widget _buildStunningActionButtons(BuildContext context, ThemeConfig themeConfig) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Discard button
        _buildPremiumActionButton(
          context: context,
          themeConfig: themeConfig,
          icon: Icons.delete_outline,
          label: 'Discard',
          onPressed: () => _showModernDiscardDialog(context, themeConfig),
          isDestructive: true,
        ),
        
        // Pause/Resume button
        _buildPremiumActionButton(
          context: context,
          themeConfig: themeConfig,
          icon: widget.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: widget.isPaused ? 'Resume' : 'Pause',
          onPressed: widget.isPaused ? widget.onResume : widget.onPause,
          isDestructive: false,
        ),
        
        // Stop button
        _buildPremiumActionButton(
          context: context,
          themeConfig: themeConfig,
          icon: Icons.stop_rounded,
          label: 'Stop',
          onPressed: widget.onStop,
          isDestructive: false,
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// Professional action button with solid colors and clear label
  Widget _buildPremiumActionButton({
    required BuildContext context,
    required ThemeConfig themeConfig,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isDestructive,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDestructive 
                  ? Colors.red.withOpacity(0.2)
                  : themeConfig.accentLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDestructive 
                    ? Colors.red.withOpacity(0.5)
                    : themeConfig.accentLight.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isDestructive 
                  ? Colors.red.shade300
                  : themeConfig.accentLight,
              size: 26,
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Label
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Waveform visualization with professional styling
  Widget _buildHeroWaveform(BuildContext context, ThemeConfig themeConfig) {
    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.glassRecordingSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: themeConfig.accentLight.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: VoiceMemoWaveform(
        isActive: !widget.isPaused,
        height: 120,
        color: themeConfig.accentLight,
        currentAmplitude: widget.amplitude,
        amplitudeHistory: widget.amplitudeHistory,
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// Professional discard confirmation dialog
  void _showModernDiscardDialog(BuildContext context, ThemeConfig themeConfig) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xEE1A1F2E),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: themeConfig.accentLight.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon - subtle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.red.shade300,
                    size: 28,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  'Discard Recording?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 10),
                
                // Description
                Text(
                  'This will permanently delete the current recording. This action cannot be undone.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.glassStrongSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(
                              color: AppTheme.glassBorder.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Discard button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onDiscard?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Discard',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 250.ms, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }

  /// Get voice commands based on language
  List<_VoiceCommand> _getVoiceCommands(AppLanguage? language) {
    language ??= AppLanguage.english;
    
    switch (language) {
      case AppLanguage.german:
        return [
          _VoiceCommand(
            icon: Icons.add_circle_outline,
            command: '"Addition" / "Add to last note"',
            description: 'Append to the last note',
          ),
          _VoiceCommand(
            icon: Icons.title,
            command: '"Title [title]"',
            description: 'Set title for this note',
          ),
          _VoiceCommand(
            icon: Icons.folder_outlined,
            command: '"Folder [name]"',
            description: 'Save to folder',
          ),
        ];
      case AppLanguage.spanish:
        return [
          _VoiceCommand(
            icon: Icons.add_circle_outline,
            command: '"Addition" / "Add to last note"',
            description: 'Append to the last note',
          ),
          _VoiceCommand(
            icon: Icons.title,
            command: '"Title [title]"',
            description: 'Set title for this note',
          ),
          _VoiceCommand(
            icon: Icons.folder_outlined,
            command: '"Folder [name]"',
            description: 'Save to folder',
          ),
        ];
      case AppLanguage.french:
        return [
          _VoiceCommand(
            icon: Icons.add_circle_outline,
            command: '"Addition" / "Add to last note"',
            description: 'Append to the last note',
          ),
          _VoiceCommand(
            icon: Icons.title,
            command: '"Title [title]"',
            description: 'Set title for this note',
          ),
          _VoiceCommand(
            icon: Icons.folder_outlined,
            command: '"Folder [name]"',
            description: 'Save to folder',
          ),
        ];
      case AppLanguage.english:
        return [
          _VoiceCommand(
            icon: Icons.add_circle_outline,
            command: '"Addition" / "Add to last note"',
            description: 'Append to the last note',
          ),
          _VoiceCommand(
            icon: Icons.title,
            command: '"Title [title]"',
            description: 'Set title for this note',
          ),
          _VoiceCommand(
            icon: Icons.folder_outlined,
            command: '"Folder [name]"',
            description: 'Save to folder',
          ),
        ];
    }
  }
}

/// Helper class for voice commands
class _VoiceCommand {
  final IconData icon;
  final String command;
  final String description;
  
  _VoiceCommand({
    required this.icon,
    required this.command,
    required this.description,
  });
}
