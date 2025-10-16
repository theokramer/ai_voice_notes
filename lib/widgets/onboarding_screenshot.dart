import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

/// Displays a screenshot with device frame mockup and animations
class OnboardingScreenshot extends StatelessWidget {
  final String screenshotPath;
  final int animationDelay;
  
  const OnboardingScreenshot({
    super.key,
    required this.screenshotPath,
    this.animationDelay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final theme = settingsProvider.currentThemeConfig;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenHeight < 700;
        
        return Container(
          constraints: BoxConstraints(
            maxHeight: isSmallScreen ? screenHeight * 0.45 : screenHeight * 0.5,
            maxWidth: 350,
          ),
          child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isSmallScreen ? AppTheme.radiusMedium : AppTheme.radiusXLarge),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.15),
                      blurRadius: isSmallScreen ? 8 : 15,
                      spreadRadius: isSmallScreen ? 1 : 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isSmallScreen ? AppTheme.radiusMedium - 2 : AppTheme.radiusXLarge - 2),
                  child: Image.asset(
                    screenshotPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if screenshot doesn't load
                      return Container(
                        width: 200,
                        height: 400,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.primary.withValues(alpha: 0.3),
                              theme.primary.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.image_rounded,
                          size: 60,
                          color: theme.primary.withValues(alpha: 0.5),
                        ),
                      );
                    },
                  ),
                ),
              ),
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: animationDelay),
              duration: 800.ms,
            )
            .scale(
              delay: Duration(milliseconds: animationDelay),
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            )
            .slideY(
              delay: Duration(milliseconds: animationDelay),
              begin: 0.2,
              end: 0,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}

