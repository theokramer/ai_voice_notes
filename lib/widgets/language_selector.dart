import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/app_language.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';

/// Language selector button that opens a modal to choose language
class LanguageSelector extends StatelessWidget {
  final bool showPulseAnimation;

  const LanguageSelector({
    super.key,
    this.showPulseAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final currentLanguage = settingsProvider.preferredLanguage;
        
        return GestureDetector(
          onTap: () async {
            await HapticService.light();
            _showLanguageModal(context, settingsProvider);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppTheme.glassStrongSurface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.glassBorder.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentLanguage.flag,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  currentLanguage.code.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ).animate(
          onPlay: showPulseAnimation
              ? (controller) => controller.repeat(reverse: true)
              : null,
        ).then(delay: 600.ms).scale(
              begin: const Offset(1, 1),
              end: const Offset(1.05, 1.05),
              duration: 1200.ms,
              curve: Curves.easeInOut,
            );
      },
    );
  }

  void _showLanguageModal(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
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
            
            // Language list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: AppLanguage.values.length,
                itemBuilder: (context, index) {
                  final language = AppLanguage.values[index];
                  final isSelected = language == settingsProvider.preferredLanguage;
                  
                  return _LanguageListItem(
                    language: language,
                    isSelected: isSelected,
                    onTap: () async {
                      await HapticService.medium();
                      await settingsProvider.updatePreferredLanguage(language);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageListItem extends StatelessWidget {
  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageListItem({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return InkWell(
          onTap: onTap,
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
                      Text(
                        language.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? settingsProvider.currentThemeConfig.primary
                                  : AppTheme.textPrimary,
                            ),
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
      },
    );
  }
}

