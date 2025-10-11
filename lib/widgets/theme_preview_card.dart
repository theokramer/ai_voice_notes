import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/settings.dart';
import '../services/localization_service.dart';

class ThemePreviewCard extends StatefulWidget {
  final ThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemePreviewCard({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<ThemePreviewCard> createState() => _ThemePreviewCardState();
}

class _ThemePreviewCardState extends State<ThemePreviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getThemeName() {
    final loc = LocalizationService();
    switch (widget.preset) {
      case ThemePreset.modern:
        return loc.t('theme_modern');
      case ThemePreset.oceanBlue:
        return loc.t('theme_ocean');
      case ThemePreset.sunsetOrange:
        return loc.t('theme_sunset');
      case ThemePreset.forestGreen:
        return loc.t('theme_forest');
      case ThemePreset.aurora:
        return loc.t('theme_aurora');
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = AppTheme.getThemeConfig(widget.preset);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: widget.isSelected
                      ? config.accentColor
                      : AppTheme.glassBorder,
                  width: widget.isSelected ? 3 : 1.5,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: config.accentColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : AppTheme.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: Column(
                  children: [
                    // Live preview section
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: config.backgroundGradient,
                      ),
                      child: Stack(
                        children: [
                          // Mini animated elements
                          Positioned(
                            left: 16,
                            top: 16,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.glassStrongSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.glassBorder,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.mic_rounded,
                                size: 20,
                                color: config.accentColor,
                              ),
                            )
                                .animate(
                                  onPlay: (controller) =>
                                      controller.repeat(reverse: true),
                                )
                                .shimmer(
                                  duration: 2.seconds,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                          ),
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: config.accentColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: config.accentColor.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: config.accentColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 15,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: config.accentColor
                                          .withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 10,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: config.accentColor
                                          .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Theme name and selection indicator
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      color: AppTheme.glassStrongSurface,
                      child: Row(
                        children: [
                          if (widget.isSelected)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: AppTheme.spacing12),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: config.accentColor,
                                size: 24,
                              )
                                  .animate()
                                  .scale(
                                    duration: 300.ms,
                                    curve: Curves.easeOutBack,
                                  )
                                  .fadeIn(duration: 200.ms),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getThemeName(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildColorDot(config.gradientStart),
                                    const SizedBox(width: 4),
                                    _buildColorDot(config.gradientMiddle),
                                    const SizedBox(width: 4),
                                    _buildColorDot(config.gradientEnd),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
    );
  }
}

