import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final bool showAnimation;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.showAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withOpacity(0.2),
                AppTheme.primary.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 60,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing32),
        
        // Title with gradient
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              AppTheme.textPrimary,
              AppTheme.textSecondary,
            ],
          ).createShader(bounds),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        
        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing48),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textTertiary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Optional action button
        if (action != null) ...[
          const SizedBox(height: AppTheme.spacing32),
          action!,
        ],
      ],
    );

    if (showAnimation) {
      content = content
          .animate()
          .fadeIn(
            duration: 600.ms,
            curve: Curves.easeOut,
          )
          .slideY(
            begin: 0.2,
            end: 0,
            duration: 600.ms,
            curve: Curves.easeOutCubic,
          );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing48),
        child: content,
      ),
    );
  }
}

// Animated empty state with floating icon
class AnimatedEmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const AnimatedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  State<AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends State<AnimatedEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating animated icon
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: child,
                );
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primary.withOpacity(0.3),
                      AppTheme.primary.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 60,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing32),
            
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing12),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing48),
              child: Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                      height: 1.6,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            
            if (widget.action != null) ...[
              const SizedBox(height: AppTheme.spacing32),
              widget.action!,
            ],
          ],
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.2, end: 0, duration: 600.ms),
      ),
    );
  }
}

