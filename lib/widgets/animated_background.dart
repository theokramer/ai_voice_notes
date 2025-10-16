import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Simple background widget with subtle top gradient indicator
class AnimatedBackground extends StatelessWidget {
  final ThemeConfig themeConfig;
  final Widget child;

  const AnimatedBackground({
    super.key,
    required this.themeConfig,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
      return Container(
            decoration: BoxDecoration(
        color: AppTheme.background, // Solid dark background
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
                colors: [
            themeConfig.primaryColor.withOpacity(0.04), // Very subtle theme color hint
            AppTheme.background.withOpacity(0.0), // Fade to transparent
          ],
          stops: const [0.0, 0.3], // Gradient covers ~15-20% of screen
        ),
      ),
      child: child,
    );
  }
}
