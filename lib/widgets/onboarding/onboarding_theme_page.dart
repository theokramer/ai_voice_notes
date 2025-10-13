import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../models/settings.dart';
import '../../services/haptic_service.dart';
import '../../services/localization_service.dart';
import '../theme_preview_card.dart';

/// Onboarding page for theme selection
class OnboardingThemePage extends StatelessWidget {
  const OnboardingThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final localization = LocalizationService();

        return Column(
          children: [
            const SizedBox(height: 60),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                localization.t('choose_theme'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 12),
            
            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                localization.t('personalize_experience'),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0, delay: 200.ms),
            
            const SizedBox(height: 40),
            
            // Theme grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: ThemePreset.values.length,
                  itemBuilder: (context, index) {
                    final preset = ThemePreset.values[index];
                    final isSelected = settingsProvider.settings.themePreset == preset;

                    return ThemePreviewCard(
                      preset: preset,
                      isSelected: isSelected,
                      onTap: () async {
                        await HapticService.light();
                        await settingsProvider.updateThemePreset(preset);
                      },
                    )
                        .animate()
                        .fadeIn(delay: (100 * index).ms, duration: 400.ms)
                        .slideY(begin: 0.3, end: 0, delay: (100 * index).ms);
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

