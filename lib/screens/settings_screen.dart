import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../models/app_language.dart';
import '../providers/settings_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/animated_background.dart';
import '../widgets/theme_preview_card.dart';
import '../widgets/settings/settings_section.dart';
import 'organization_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        return Scaffold(
          body: AnimatedBackground(
            style: settingsProvider.settings.backgroundStyle,
            themeConfig: themeConfig,
            child: SafeArea(
              top: false, // Allow header to extend into safe area
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Animated Header with smooth collapsing effect
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SettingsHeaderDelegate(
                      onBackPressed: () {
                        HapticService.light();
                        Navigator.pop(context);
                      },
                      expandedHeight: 120.0 + MediaQuery.of(context).padding.top,
                      collapsedHeight: 60.0 + MediaQuery.of(context).padding.top,
                      themeConfig: themeConfig,
                    ),
                  ),
                  // Add spacing between header and content
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppTheme.spacing16),
                  ),
                  // Settings list
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                    SettingsSection(
                      title: LocalizationService().t('language'),
                      children: [
                        _buildLanguageSelector(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    SettingsSection(
                      title: LocalizationService().t('appearance'),
                      children: [
                        _buildThemeSelector(context, settingsProvider.currentThemeConfig),
                        _buildBackgroundStyleSelector(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    SettingsSection(
                      title: LocalizationService().t('recording'),
                      children: [
                        _buildAudioQualitySelector(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    SettingsSection(
                      title: 'Smart Notes',
                      children: [
                        _buildTranscriptionModeSelector(context, settingsProvider.currentThemeConfig),
                        _buildAutoOrganizeToggle(context, settingsProvider.currentThemeConfig),
                        _buildAllowAICreateFoldersToggle(context, settingsProvider.currentThemeConfig),
                        _buildShowOrganizationHintsToggle(context, settingsProvider.currentThemeConfig),
                        _buildOrganizeNowButton(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    SettingsSection(
                      title: LocalizationService().t('preferences'),
                      children: [
                        _buildHapticsToggle(context, settingsProvider.currentThemeConfig),
                        _buildUnifiedNoteViewToggle(context, settingsProvider.currentThemeConfig),
                        _buildAutoCloseToggle(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    SettingsSection(
                      title: 'Data',
                      children: [
                        _buildClearCacheButton(context, settingsProvider.currentThemeConfig),
                        _buildDeleteAllNotesButton(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    SettingsSection(
                      title: 'About',
                      children: [
                        _buildAboutTile(context, settingsProvider.currentThemeConfig),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing32),
                      ]),
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

  Widget _buildAutoCloseToggle(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.timer,
          title: 'Auto-Close After Entry',
          subtitle: 'Automatically close note after 2 seconds',
          trailing: Switch(
            value: provider.settings.autoCloseAfterEntry,
            activeTrackColor: themeConfig.primaryColor,
            onChanged: (value) async {
              await HapticService.light();
              await provider.updateAutoCloseAfterEntry(value);
            },
          ),
        );
      },
    );
  }

  Widget _buildLanguageSelector(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        final localization = LocalizationService();
        final currentLanguage = provider.preferredLanguage;
        
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.language,
          title: localization.t('settings_language'),
          subtitle: '${currentLanguage.flag} ${currentLanguage.name} • ${localization.t('settings_language_subtitle')}',
          onTap: () async {
            await HapticService.light();
            // Show language selector modal directly
            if (context.mounted) {
              _showLanguageModal(context, provider);
            }
          },
        );
      },
    );
  }

  void _showLanguageModal(BuildContext context, SettingsProvider settingsProvider) {
    final localization = LocalizationService();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          border: Border.all(
            color: AppTheme.glassBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      localization.t('select_language'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
            ),
            
            const Divider(height: 1, color: AppTheme.glassBorder),
            
            // Beta disclaimer
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localization.t('language_beta_disclaimer'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Language list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: AppLanguage.values.length,
                itemBuilder: (context, index) {
                  final language = AppLanguage.values[index];
                  final isSelected = language == settingsProvider.preferredLanguage;
                  
                  return _buildLanguageListItem(
                    context,
                    language,
                    isSelected,
                    settingsProvider,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageListItem(
    BuildContext context,
    AppLanguage language,
    bool isSelected,
    SettingsProvider settingsProvider,
  ) {
    return InkWell(
      onTap: () async {
        await HapticService.medium();
        await settingsProvider.updatePreferredLanguage(language);
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? settingsProvider.currentThemeConfig.primary
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              language.flag,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        language.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? settingsProvider.currentThemeConfig.primary
                                  : AppTheme.textPrimary,
                            ),
                      ),
                      if (language != AppLanguage.english) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'BETA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    language.nativeName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: settingsProvider.currentThemeConfig.primary,
                size: 24,
              ),
          ],
        ),
      ),
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

  Widget _buildTranscriptionModeSelector(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        final mode = provider.settings.transcriptionMode;
        final modeName = mode == TranscriptionMode.aiBeautify ? 'AI Beautify' : 'Plain Text';
        
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.auto_awesome,
          title: 'Transcription Mode',
          subtitle: modeName,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                modeName,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          onTap: () {
            HapticService.light();
            _showTranscriptionModeDialog(context);
          },
        );
      },
    );
  }

  Widget _buildAutoOrganizeToggle(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        final isAuto = provider.settings.organizationMode == OrganizationMode.autoOrganize;
        return _buildToggleTile(
          context,
          themeConfig,
          icon: Icons.auto_fix_high,
          title: 'Automatic Organization',
          subtitle: 'AI organizes notes as you record',
          value: isAuto,
          onChanged: (value) async {
            HapticService.light();
            await provider.updateOrganizationMode(
              value ? OrganizationMode.autoOrganize : OrganizationMode.manualOrganize,
            );
          },
        );
      },
    );
  }

  Widget _buildAllowAICreateFoldersToggle(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        final isAutoOrg = provider.settings.organizationMode == OrganizationMode.autoOrganize;
        // Disable this toggle if auto-organization is off
        final onChanged = isAutoOrg ? (bool value) {
          HapticService.light();
          provider.updateAllowAICreateFolders(value);
        } : (bool value) {};
        
        return _buildToggleTile(
          context,
          themeConfig,
          icon: Icons.create_new_folder,
          title: 'Allow AI to Create Folders',
          subtitle: 'AI can create new folders when appropriate',
          value: isAutoOrg && provider.settings.allowAICreateFolders,
          onChanged: onChanged,
        );
      },
    );
  }

  Widget _buildShowOrganizationHintsToggle(BuildContext context, ThemeConfig themeConfig) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        return _buildToggleTile(
          context,
          themeConfig,
          icon: Icons.info_outline,
          title: 'Show Organization Hints',
          subtitle: 'Brief notifications when notes are saved',
          value: provider.settings.showOrganizationHints,
          onChanged: (value) async {
            HapticService.light();
            await provider.updateShowOrganizationHints(value);
          },
        );
      },
    );
  }

  Widget _buildOrganizeNowButton(BuildContext context, ThemeConfig themeConfig) {
    return Consumer3<NotesProvider, SettingsProvider, FoldersProvider>(
      builder: (context, notesProvider, settingsProvider, foldersProvider, child) {
        // Count unorganized notes (both null and explicit unorganized folder ID)
        final unorganizedFolderId = foldersProvider.unorganizedFolderId;
        final unorganizedCount = notesProvider.notes.where((n) {
          return n.folderId == null || n.folderId == unorganizedFolderId;
        }).length;
        
        return _buildTile(
          context,
          themeConfig,
          icon: Icons.folder_special,
          title: 'Unorganized Notes: $unorganizedCount',
          subtitle: unorganizedCount > 0 ? 'Tap to organize now' : 'All notes organized!',
          trailing: unorganizedCount > 0 ? Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.textSecondary,
          ) : Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
          onTap: unorganizedCount > 0 ? () {
            HapticService.light();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrganizationScreen()),
            );
          } : null,
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

  Widget _buildToggleTile(
    BuildContext context,
    ThemeConfig themeConfig, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: themeConfig.primaryColor,
            ),
          ],
        ),
      ),
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

  void _showTranscriptionModeDialog(BuildContext context) {
    final provider = context.read<SettingsProvider>();
    final themeConfig = provider.currentThemeConfig;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          decoration: BoxDecoration(
            color: const Color(0xEE1A1F2E),
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
                'Transcription Mode',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppTheme.spacing16),
              ...TranscriptionMode.values.map((mode) {
                final isSelected = provider.settings.transcriptionMode == mode;
                final modeName = mode == TranscriptionMode.aiBeautify ? 'AI Beautify' : 'Plain Text';
                final modeDesc = mode == TranscriptionMode.aiBeautify
                    ? 'AI structures with headings and formatting'
                    : 'Direct transcription, no formatting';
                
                return GestureDetector(
                  onTap: () async {
                    await HapticService.medium();
                    await provider.updateTranscriptionMode(mode);
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: themeConfig.primaryColor,
                                size: 20,
                              ),
                            if (isSelected) const SizedBox(width: AppTheme.spacing12),
                            Text(
                              modeName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          modeDesc,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
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
      case BackgroundStyle.softBlobs:
        return 'Soft Blobs'; // Legacy support only
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
                      // None (Default/Recommended)
                      _buildBackgroundStyleOption(
                        context,
                        BackgroundStyle.none,
                        'None',
                        'Clean static gradient (Recommended)',
                        Icons.gradient,
                        provider,
                        themeConfig,
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      // Other options
                      _buildBackgroundStyleOption(
                        context,
                        BackgroundStyle.clouds,
                        'Gentle Clouds',
                        'Ultra-subtle floating clouds',
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

// Custom SliverPersistentHeaderDelegate for animated settings header
class _SettingsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onBackPressed;
  final double expandedHeight;
  final double collapsedHeight;
  final ThemeConfig themeConfig;

  _SettingsHeaderDelegate({
    required this.onBackPressed,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.themeConfig,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate progress based on how much the header has shrunk
    final double shrinkProgress = (shrinkOffset / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
    
    // Get safe area insets
    final safePadding = MediaQuery.of(context).padding.top;
    
    // Interpolate values based on scroll progress
    final double fontSize = 48 - (shrinkProgress * 26); // 48 -> 22
    final double topPadding = 56 - (shrinkProgress * 40); // 56 -> 16
    final double bottomPadding = 24 - (shrinkProgress * 8); // 24 -> 16
    final double horizontalPadding = 24 - (shrinkProgress * 4); // 24 -> 20
    final double backButtonSize = 46 - (shrinkProgress * 6); // 46 -> 40
    
    // Background opacity increases as we scroll - only show when scrolling
    final double backgroundOpacity = shrinkProgress * 0.4; // 0 -> 0.4 (starts transparent, becomes glass)
    final double blurAmount = shrinkProgress * 20; // 0 -> 20 (no blur at top, full blur when scrolled)
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            safePadding + topPadding, // Add safe area to top padding
            horizontalPadding,
            bottomPadding,
          ),
          decoration: BoxDecoration(
            // Dark glassmorphism frosting - only visible when scrolling
            color: AppTheme.glassDarkSurface.withValues(alpha: backgroundOpacity),
            border: shrinkProgress > 0.5 ? const Border(
              bottom: BorderSide(
                color: AppTheme.glassBorder,
                width: 1.5,
              ),
            ) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button - clean and properly sized
              GestureDetector(
                onTap: onBackPressed,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: backButtonSize,
                      height: backButtonSize,
                      decoration: AppTheme.glassDecoration(
                        radius: AppTheme.radiusMedium,
                        color: AppTheme.glassDarkSurface,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              // Settings title
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: shrinkProgress * 4), // Subtle offset when scrolling
                  child: Text(
                    'Settings',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          height: 1.0,
                          color: AppTheme.textPrimary,
                        ),
                    overflow: TextOverflow.visible,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant _SettingsHeaderDelegate oldDelegate) {
    return true; // Always rebuild for smooth animation
  }
}

