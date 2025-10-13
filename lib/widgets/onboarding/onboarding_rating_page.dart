import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/haptic_service.dart';
import '../../services/localization_service.dart';

/// Onboarding page for app rating prompt
class OnboardingRatingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingRatingPage({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingRatingPage> createState() => _OnboardingRatingPageState();
}

class _OnboardingRatingPageState extends State<OnboardingRatingPage> {
  int _selectedStars = 0;
  bool _hasSubmitted = false;

  Future<void> _handleRating(int stars) async {
    await HapticService.medium();
    
    setState(() {
      _selectedStars = stars;
    });

    // Wait a moment for visual feedback
    await Future.delayed(const Duration(milliseconds: 800));

    if (stars >= 4) {
      // Good rating - prompt for App Store review
      try {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
        }
      } catch (e) {
        debugPrint('Error requesting review: $e');
      }
    }

    setState(() {
      _hasSubmitted = true;
    });

    // Continue after showing thank you
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final localization = LocalizationService();
        final themeConfig = settingsProvider.currentThemeConfig;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeConfig.primaryColor,
                    themeConfig.primaryColor.withValues(alpha: 0.6),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star,
                size: 48,
                color: Colors.white,
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .then(delay: 100.ms)
                .shimmer(duration: 1500.ms),
            
            const SizedBox(height: 40),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _hasSubmitted
                    ? localization.t('thank_you')
                    : localization.t('rate_your_experience'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0, delay: 200.ms),
            
            const SizedBox(height: 16),
            
            // Subtitle
            if (!_hasSubmitted)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  localization.t('rate_experience_subtitle'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0, delay: 400.ms),
            
            const SizedBox(height: 40),
            
            // Star rating
            if (!_hasSubmitted)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starNumber = index + 1;
                  final isSelected = starNumber <= _selectedStars;
                  
                  return GestureDetector(
                    onTap: () => _handleRating(starNumber),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        isSelected ? Icons.star : Icons.star_border,
                        size: 48,
                        color: isSelected
                            ? Colors.amber
                            : AppTheme.textSecondary,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: (600 + index * 100).ms, duration: 400.ms)
                      .scale(delay: (600 + index * 100).ms);
                }),
              ),
            
            if (_hasSubmitted)
              Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green.shade400,
              )
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
          ],
        );
      },
    );
  }
}

