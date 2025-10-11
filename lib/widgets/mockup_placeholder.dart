import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Reusable widget for displaying app feature mockup placeholders
class MockupPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  final double aspectRatio;

  const MockupPlaceholder({
    super.key,
    required this.icon,
    required this.label,
    this.aspectRatio = 9 / 16, // Default phone aspect ratio
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final theme = settingsProvider.currentThemeConfig;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phone frame mockup
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  border: Border.all(
                    color: theme.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primary.withValues(alpha: 0.1),
                      theme.primary.withValues(alpha: 0.05),
                      theme.primaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 60,
                    color: theme.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .shimmer(
                  delay: 1000.ms,
                  duration: 2000.ms,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
            
            const SizedBox(height: AppTheme.spacing12),
            
            // Label
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

