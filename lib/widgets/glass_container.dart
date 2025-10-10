import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum GlassStrength {
  light,
  medium,
  strong,
}

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final GlassStrength strength;
  final bool showBorder;
  final bool showShadow;
  final Color? color;
  final Gradient? gradient;
  final bool animated;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = AppTheme.radiusLarge,
    this.strength = GlassStrength.medium,
    this.showBorder = true,
    this.showShadow = true,
    this.color,
    this.gradient,
    this.animated = false,
    this.onTap,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap?.call();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glassColor = _getGlassColor();
    final blurAmount = _getBlurAmount();

    Widget container = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      margin: widget.margin,
      child: widget.child,
    );

    // Wrap in glass effect layers
    container = Stack(
      children: [
        // Background blur layer
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
            child: Container(
              decoration: BoxDecoration(
                color: widget.color ?? glassColor,
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: widget.showBorder
                    ? Border.all(
                        color: AppTheme.glassBorder,
                        width: 1.5,
                      )
                    : null,
                boxShadow: widget.showShadow ? _getShadows() : null,
              ),
              child: container,
            ),
          ),
        ),
        // Shimmer overlay (for animated containers)
        if (widget.animated)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: _ShimmerOverlay(borderRadius: widget.borderRadius),
            ),
          ),
        // Light reflection on edge
        if (widget.showBorder)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(widget.borderRadius),
                topRight: Radius.circular(widget.borderRadius),
              ),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0),
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    // Add scale animation if tappable
    if (widget.onTap != null) {
      container = GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: container,
        ),
      );
    }

    return container;
  }

  Color _getGlassColor() {
    switch (widget.strength) {
      case GlassStrength.light:
        return AppTheme.glassSurface;
      case GlassStrength.medium:
        return AppTheme.glassStrongSurface;
      case GlassStrength.strong:
        return const Color(0x50FFFFFF);
    }
  }

  double _getBlurAmount() {
    switch (widget.strength) {
      case GlassStrength.light:
        return 5;
      case GlassStrength.medium:
        return 10;
      case GlassStrength.strong:
        return 15;
    }
  }

  List<BoxShadow> _getShadows() {
    switch (widget.strength) {
      case GlassStrength.light:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
      case GlassStrength.medium:
        return AppTheme.cardShadow;
      case GlassStrength.strong:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ];
    }
  }
}

// Shimmer overlay for animated glass containers
class _ShimmerOverlay extends StatefulWidget {
  final double borderRadius;

  const _ShimmerOverlay({required this.borderRadius});

  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ShimmerPainter(
            progress: _controller.value,
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  _ShimmerPainter({
    required this.progress,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // Create diagonal gradient that moves across
    final gradientStart = Offset(-size.width, 0);
    final gradientEnd = Offset(size.width * 2, size.height);
    
    final currentStart = Offset.lerp(gradientStart, gradientEnd, progress)!;
    final currentEnd = Offset(
      currentStart.dx + size.width * 0.5,
      currentStart.dy + size.height * 0.5,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromPoints(currentStart, currentEnd));

    canvas.clipRRect(rrect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) => false;
}

// Animated glass card with 3D hover effect
class GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = AppTheme.radiusLarge,
    this.padding,
    this.margin,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _elevationAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.translate(
              offset: Offset(0, -_elevationAnimation.value),
              child: GlassContainer(
                padding: widget.padding,
                margin: widget.margin,
                borderRadius: widget.borderRadius,
                showShadow: true,
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

