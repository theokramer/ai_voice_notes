import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../providers/settings_provider.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/animated_background.dart';
import '../widgets/theme_preview_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          body: AnimatedBackground(
            style: settingsProvider.settings.backgroundStyle,
            themeConfig: settingsProvider.currentThemeConfig,
            child: SafeArea(
          child: Column(
            children: [
              // Header - simplified without BackdropFilter for better performance
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticService.light();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacing12),
                        decoration: BoxDecoration(
                          color: AppTheme.glassStrongSurface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                  ],
                ),
              ),
              // Settings list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing24,
                  ),
                  children: [
                    _buildSection(
                      context,
                      settingsProvider.currentThemeConfig,
                      title: 'Appearance',
                      children: [
                        _buildThemeSelector(context, settingsProvider.currentThemeConfig),
                        _buildBackgroundStyleSelector(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    _buildSection(
                      context,
                      settingsProvider.currentThemeConfig,
                      title: 'Recording',
                      children: [
                        _buildAudioQualitySelector(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    _buildSection(
                      context,
                      settingsProvider.currentThemeConfig,
                      title: 'Preferences',
                      children: [
                        _buildHapticsToggle(context, settingsProvider.currentThemeConfig),
                        _buildUnifiedNoteViewToggle(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    _buildSection(
                      context,
                      settingsProvider.currentThemeConfig,
                      title: 'Data',
                      children: [
                        _buildClearCacheButton(context, settingsProvider.currentThemeConfig),
                        _buildDeleteAllNotesButton(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    _buildSection(
                      context,
                      settingsProvider.currentThemeConfig,
                      title: 'About',
                      children: [
                        _buildAboutTile(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    ThemeConfig themeConfig, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spacing8,
            bottom: AppTheme.spacing12,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
          ),
        ),
        // Removed BackdropFilter for better performance
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassStrongSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.glassBorder, width: 1.5),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildHapticsToggle(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.vibration,
          title: 'Haptic Feedback',
          subtitle: 'Feel vibrations when interacting',
          trailing: Switch(
            value: provider.settings.hapticsEnabled,
            activeTrackColor: themeConfig.primaryColor,
            onChanged: (value) async {
              if (value) await HapticService.light();
              await provider.updateHapticsEnabled(value);
            },
          ),
        );
      },
    );
  }

  Widget _buildUnifiedNoteViewToggle(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.description,
          title: 'Unified Note View',
          subtitle: 'Show notes as flowing document',
          trailing: Switch(
            value: provider.settings.useUnifiedNoteView,
            activeTrackColor: themeConfig.primaryColor,
            onChanged: (value) async {
              await HapticService.light();
              await provider.updateUnifiedNoteView(value);
            },
          ),
        );
      },
    );
  }

  Widget _buildThemeSelector(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.palette,
          title: 'Theme',
          subtitle: _getThemeName(provider.settings.themePreset),
          onTap: () {
            HapticService.light();
            _showThemeDialog(context);
          },
        );
      },
    );
  }

  Widget _buildBackgroundStyleSelector(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.wallpaper,
          title: 'Background Animation',
          subtitle: _getBackgroundStyleName(provider.settings.backgroundStyle),
          onTap: () {
            HapticService.light();
            _showBackgroundStyleDialog(context);
          },
        );
      },
    );
  }

  Widget _buildAudioQualitySelector(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.mic,
          title: 'Audio Quality',
          subtitle: _getAudioQualityName(provider.settings.audioQuality),
          onTap: () {
            HapticService.light();
            _showAudioQualityDialog(context);
          },
        );
      },
    );
  }

  Widget _buildDeleteAllNotesButton(BuildContext context, ThemeConfig themeConfig) {
    return _buildTile(
      context,
      themeConfig,
      icon: Icons.delete_forever,
      title: 'Delete All Notes',
      subtitle: 'Permanently delete all your notes',
      onTap: () {
        HapticService.light();
        _showDeleteAllNotesDialog(context);
      },
    );
  }

  Widget _buildClearCacheButton(BuildContext context, ThemeConfig themeConfig) {
    return _buildTile(
      context,
      themeConfig,
      icon: Icons.delete_outline,
      title: 'Clear Cache',
      subtitle: 'Free up storage space',
      onTap: () async {
        await HapticService.light();
        await _clearCache(context);
      },
    );
  }

  Widget _buildAboutTile(BuildContext context, ThemeConfig themeConfig) {
    return _buildTile(
      context,
      themeConfig,
      icon: Icons.info_outline,
      title: 'App Version',
      subtitle: '1.0.0',
    );
  }

  Widget _buildTile(
    BuildContext context,
    ThemeConfig themeConfig, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.glassBorder.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                color: themeConfig.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                icon,
                color: themeConfig.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAllNotesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          decoration: BoxDecoration(
            color: AppTheme.glassStrongSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            border: Border.all(color: AppTheme.glassBorder, width: 1.5),
            boxShadow: AppTheme.cardShadow,
          ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade400,
                        size: 28,
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Text(
                        'Delete All Notes?',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    'This action cannot be undone. All your notes will be permanently deleted.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticService.light();
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacing16,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.glassSurface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              border:
                                  Border.all(color: AppTheme.glassBorder, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await HapticService.medium();
                            final notesProvider = context.read<NotesProvider>();
                            await notesProvider.deleteAllNotes();
                            if (context.mounted) {
                              Navigator.pop(context);
                              CustomSnackbar.show(
                                context,
                                message: 'All notes deleted',
                                type: SnackbarType.success,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacing16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.red.shade600,
                                  Colors.red.shade700,
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: AppTheme.buttonShadow,
                            ),
                            child: Center(
                              child: Text(
                                'Delete All',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .animate()
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: AppTheme.animationFast,
            curve: Curves.easeOut,
          )
          .fadeIn(duration: AppTheme.animationFast),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final provider = context.read<SettingsProvider>();

    showDialog(
      context: context,
      barrierColor: Colors.black87,  // Darker backdrop for better focus
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(AppTheme.spacing24),
          decoration: BoxDecoration(
            // Much more opaque background for perfect text readability
            color: const Color(0xEE1A1F2E),  // 93% opacity dark blue-grey
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            border: Border.all(
              color: AppTheme.glassBorder.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose Theme',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      HapticService.light();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'Select a color scheme for your app',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: ThemePreset.values.map((preset) {
                      final isSelected = provider.settings.themePreset == preset;
                      return ThemePreviewCard(
                        preset: preset,
                        isSelected: isSelected,
                        onTap: () async {
                          await HapticService.medium();
                          await provider.updateThemePreset(preset);
                          if (context.mounted) {
                            Navigator.pop(context);
                            CustomSnackbar.show(
                              context,
                              message: 'Theme updated',
                              type: SnackbarType.success,
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: AppTheme.animationFast,
            curve: Curves.easeOut,
          )
          .fadeIn(duration: AppTheme.animationFast),
    );
  }

  void _showAudioQualityDialog(BuildContext context) {
    final provider = context.read<SettingsProvider>();
    final themeConfig = provider.currentThemeConfig;

    showDialog(
      context: context,
      barrierColor: Colors.black87,  // Darker backdrop for better focus
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          decoration: BoxDecoration(
            // Much more opaque background for perfect text readability
            color: const Color(0xEE1A1F2E),  // 93% opacity dark blue-grey
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            border: Border.all(
              color: AppTheme.glassBorder.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Quality',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  ...AudioQuality.values.map((quality) {
                    final isSelected = provider.settings.audioQuality == quality;
                    return GestureDetector(
                      onTap: () async {
                        await HapticService.medium();
                        await provider.updateAudioQuality(quality);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? themeConfig.primaryColor.withValues(alpha: 0.2)
                              : AppTheme.glassSurface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: isSelected
                                ? themeConfig.primaryColor
                                : AppTheme.glassBorder,
                            width: isSelected ? 2 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: themeConfig.primaryColor,
                                size: 20,
                              ),
                            if (isSelected) const SizedBox(width: AppTheme.spacing12),
                            Text(
                              _getAudioQualityName(quality),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          )
          .animate()
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: AppTheme.animationFast,
            curve: Curves.easeOut,
          )
          .fadeIn(duration: AppTheme.animationFast),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final provider = context.read<SettingsProvider>();
    await provider.clearCache();

    if (context.mounted) {
      await HapticService.success();
      CustomSnackbar.show(
        context,
        message: 'Cache cleared',
        type: SnackbarType.success,
      );
    }
  }

  String _getThemeName(ThemePreset preset) {
    switch (preset) {
      case ThemePreset.modern:
        return 'Modern Dark';
      case ThemePreset.oceanBlue:
        return 'Ocean Blue';
      case ThemePreset.sunsetOrange:
        return 'Sunset Orange';
      case ThemePreset.forestGreen:
        return 'Forest Green';
      case ThemePreset.aurora:
        return 'Aurora';
    }
  }

  String _getAudioQualityName(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.low:
        return 'Low (Faster)';
      case AudioQuality.medium:
        return 'Medium';
      case AudioQuality.high:
        return 'High (Best)';
    }
  }

  String _getBackgroundStyleName(BackgroundStyle style) {
    switch (style) {
      case BackgroundStyle.none:
        return 'None';
      case BackgroundStyle.clouds:
        return 'Gentle Clouds';
      case BackgroundStyle.meshGradient:
        return 'Mesh Gradient';
    }
  }

  void _showBackgroundStyleDialog(BuildContext context) {
    final provider = context.read<SettingsProvider>();
    final themeConfig = provider.currentThemeConfig;

    showDialog(
      context: context,
      barrierColor: Colors.black87,  // Darker backdrop for better focus
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(AppTheme.spacing24),
          decoration: BoxDecoration(
            // Much more opaque background for perfect text readability
            color: const Color(0xEE1A1F2E),  // 93% opacity dark blue-grey
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            border: Border.all(
              color: AppTheme.glassBorder.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Background Animation',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose your perfect backdrop',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      HapticService.light();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // All backgrounds grouped together
                      _buildBackgroundStyleOption(
                        context,
                        BackgroundStyle.clouds,
                        'Gentle Clouds',
                        'Soft floating clouds (Recommended)',
                        Icons.cloud_outlined,
                        provider,
                        themeConfig,
                      ),
                      _buildBackgroundStyleOption(
                        context,
                        BackgroundStyle.meshGradient,
                        'Mesh Gradient',
                        'Flowing morphing gradients',
                        Icons.grain,
                        provider,
                        themeConfig,
                      ),
                      _buildBackgroundStyleOption(
                        context,
                        BackgroundStyle.none,
                        'None',
                        'Static gradient, no animation',
                        Icons.gradient,
                        provider,
                        themeConfig,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: AppTheme.animationFast,
            curve: Curves.easeOut,
          )
          .fadeIn(duration: AppTheme.animationFast),
    );
  }

  Widget _buildBackgroundStyleOption(
    BuildContext context,
    BackgroundStyle style,
    String title,
    String description,
    IconData icon,
    SettingsProvider provider,
    ThemeConfig themeConfig,
  ) {
    final isSelected = provider.settings.backgroundStyle == style;
    
    return GestureDetector(
      onTap: () async {
        await HapticService.medium();
        await provider.updateBackgroundStyle(style);
        if (context.mounted) {
          Navigator.pop(context);
          CustomSnackbar.show(
            context,
            message: 'Background updated',
            type: SnackbarType.success,
            themeConfig: themeConfig,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: isSelected
              ? themeConfig.primaryColor.withValues(alpha: 0.25)
              : const Color(0x30FFFFFF),  // Slightly lighter for better contrast
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? themeConfig.primaryColor : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? themeConfig.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.glassBorder.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? themeConfig.primaryColor : AppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: themeConfig.primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

