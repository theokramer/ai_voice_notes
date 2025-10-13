import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/localization_service.dart';
import '../language_selector.dart';

/// First onboarding page with video and language selector
class OnboardingVideoPage extends StatelessWidget {
  final VideoPlayerController? videoController;
  final bool isVideoInitialized;
  final bool videoHasFlownOut;

  const OnboardingVideoPage({
    super.key,
    required this.videoController,
    required this.isVideoInitialized,
    required this.videoHasFlownOut,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final localization = LocalizationService();
        final themeConfig = settingsProvider.currentThemeConfig;

        return Column(
          children: [
            const Spacer(),
            
            // Language selector at top
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: LanguageSelector(),
            ),
            
            const SizedBox(height: 32),
            
            // Video with fly-out animation
            AnimatedSlide(
              offset: videoHasFlownOut ? const Offset(0, -2) : Offset.zero,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInBack,
              child: AnimatedOpacity(
                opacity: videoHasFlownOut ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: themeConfig.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: isVideoInitialized && videoController != null
                          ? VideoPlayer(videoController!)
                          : Container(
                              color: Colors.black.withValues(alpha: 0.3),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Title and subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    localization.t('onboarding_video_title'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localization.t('onboarding_video_subtitle'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const Spacer(flex: 2),
          ],
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.1, end: 0, duration: 600.ms);
      },
    );
  }
}

