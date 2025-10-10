import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BackgroundStyle {
  none,              // Just solid gradient, no animation
  clouds,            // Gentle floating clouds (Recommended)
  meshGradient,      // Flowing morphing gradients
}

class AnimatedBackground extends StatefulWidget {
  final BackgroundStyle style;
  final ThemeConfig themeConfig;
  final Widget child;

  const AnimatedBackground({
    super.key,
    required this.style,
    required this.themeConfig,
    required this.child,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22), // Slower, more elegant animation
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated background layer
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _getPainter(),
                );
              },
            ),
          ),
        ),
        // Dark overlay for better text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),  // Darker at top
                  Colors.black.withOpacity(0.25),  // Lighter in middle
                  Colors.black.withOpacity(0.30),  // Slightly darker at bottom
                ],
              ),
            ),
          ),
        ),
        // Content layer
        widget.child,
      ],
    );
  }

  CustomPainter _getPainter() {
    switch (widget.style) {
      case BackgroundStyle.none:
        return StaticGradientPainter(themeConfig: widget.themeConfig);
      case BackgroundStyle.clouds:
        return CloudsPainter(
          animation: _controller,
          themeConfig: widget.themeConfig,
        );
      case BackgroundStyle.meshGradient:
        return MeshGradientPainter(
          animation: _controller,
          themeConfig: widget.themeConfig,
        );
    }
  }
}

// Mesh Gradient Painter - Flowing morphing gradient mesh
class MeshGradientPainter extends CustomPainter {
  final Animation<double> animation;
  final ThemeConfig themeConfig;

  MeshGradientPainter({
    required this.animation,
    required this.themeConfig,
  }) : super(repaint: animation);

  // Helper to create muted background colors
  Color _muteColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation((hsl.saturation * 0.4).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.5 + 0.15).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    
    // Draw base gradient first
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _muteColor(themeConfig.gradientStart),
        _muteColor(themeConfig.gradientMiddle),
        _muteColor(themeConfig.gradientEnd),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));
    
    // Create mesh points that move over time
    final points = [
      Offset(
        size.width * (0.2 + 0.1 * sin(progress * 2 * pi)),
        size.height * (0.2 + 0.1 * cos(progress * 2 * pi)),
      ),
      Offset(
        size.width * (0.8 + 0.1 * sin(progress * 2 * pi + pi / 3)),
        size.height * (0.3 + 0.1 * cos(progress * 2 * pi + pi / 3)),
      ),
      Offset(
        size.width * (0.5 + 0.15 * sin(progress * 2 * pi + 2 * pi / 3)),
        size.height * (0.7 + 0.15 * cos(progress * 2 * pi + 2 * pi / 3)),
      ),
      Offset(
        size.width * (0.1 + 0.1 * sin(progress * 2 * pi + pi)),
        size.height * (0.8 + 0.1 * cos(progress * 2 * pi + pi)),
      ),
    ];

    final colors = [
      _muteColor(themeConfig.gradientStart),
      _muteColor(themeConfig.gradientMiddle),
      _muteColor(themeConfig.gradientEnd),
      _muteColor(themeConfig.accentColor),
    ];

    // Draw radial gradients at each point with reduced opacity
    for (int i = 0; i < points.length; i++) {
      final gradient = RadialGradient(
        center: Alignment.center,
        radius: 1.5,
        colors: [
          colors[i].withOpacity(0.3),  // Reduced from 0.6
          colors[i].withOpacity(0.0),
        ],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCenter(
            center: points[i],
            width: size.width,
            height: size.height,
          ),
        )
        ..blendMode = BlendMode.screen;

      canvas.drawCircle(points[i], size.width * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(MeshGradientPainter oldDelegate) => false;
}


// Static Gradient Painter - No animation, just gradient
class StaticGradientPainter extends CustomPainter {
  final ThemeConfig themeConfig;

  StaticGradientPainter({required this.themeConfig});

  // Helper to create muted background colors
  Color _muteColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation((hsl.saturation * 0.4).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.5 + 0.15).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _muteColor(themeConfig.gradientStart),
        _muteColor(themeConfig.gradientMiddle),
        _muteColor(themeConfig.gradientEnd),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(StaticGradientPainter oldDelegate) => false;
}


// Clouds Painter - Modern gentle floating clouds
// Enhanced with theme color integration and improved depth
class CloudsPainter extends CustomPainter {
  final Animation<double> animation;
  final ThemeConfig themeConfig;
  static final List<_Cloud> _clouds = [];
  static bool _initialized = false;

  CloudsPainter({
    required this.animation,
    required this.themeConfig,
  }) : super(repaint: animation) {
    if (!_initialized) {
      _initClouds();
      _initialized = true;
    }
  }

  static void _initClouds() {
    _clouds.clear();
    
    // Create 9 clouds with varied organic shapes for modern atmospheric effect
    // Far background layer - very subtle, large, and blurry
    _clouds.add(_Cloud(
      x: 0.10,
      y: 0.08,
      size: 0.55,
      speed: 0.018,
      opacity: 0.10,
      layer: 0,
      verticalAmplitude: 0.04,
      circleCount: 6,
      colorTintStrength: 0.15,
    ));
    
    _clouds.add(_Cloud(
      x: 0.65,
      y: 0.15,
      size: 0.50,
      speed: 0.020,
      opacity: 0.11,
      layer: 1,
      verticalAmplitude: 0.045,
      circleCount: 5,
      colorTintStrength: 0.18,
    ));
    
    // Mid background layers - balanced size and visibility
    _clouds.add(_Cloud(
      x: 0.30,
      y: 0.28,
      size: 0.45,
      speed: 0.024,
      opacity: 0.13,
      layer: 2,
      verticalAmplitude: 0.055,
      circleCount: 7,
      colorTintStrength: 0.22,
    ));
    
    _clouds.add(_Cloud(
      x: 0.85,
      y: 0.35,
      size: 0.42,
      speed: 0.022,
      opacity: 0.12,
      layer: 3,
      verticalAmplitude: 0.05,
      circleCount: 5,
      colorTintStrength: 0.20,
    ));
    
    _clouds.add(_Cloud(
      x: 0.15,
      y: 0.48,
      size: 0.48,
      speed: 0.026,
      opacity: 0.14,
      layer: 4,
      verticalAmplitude: 0.06,
      circleCount: 6,
      colorTintStrength: 0.25,
    ));
    
    // Foreground layers - slightly more prominent with better definition
    _clouds.add(_Cloud(
      x: 0.55,
      y: 0.58,
      size: 0.40,
      speed: 0.028,
      opacity: 0.15,
      layer: 5,
      verticalAmplitude: 0.065,
      circleCount: 6,
      colorTintStrength: 0.28,
    ));
    
    _clouds.add(_Cloud(
      x: 0.75,
      y: 0.68,
      size: 0.38,
      speed: 0.030,
      opacity: 0.13,
      layer: 6,
      verticalAmplitude: 0.07,
      circleCount: 5,
      colorTintStrength: 0.30,
    ));
    
    _clouds.add(_Cloud(
      x: 0.05,
      y: 0.75,
      size: 0.35,
      speed: 0.032,
      opacity: 0.12,
      layer: 7,
      verticalAmplitude: 0.075,
      circleCount: 4,
      colorTintStrength: 0.32,
    ));
    
    _clouds.add(_Cloud(
      x: 0.42,
      y: 0.82,
      size: 0.33,
      speed: 0.034,
      opacity: 0.11,
      layer: 8,
      verticalAmplitude: 0.08,
      circleCount: 5,
      colorTintStrength: 0.35,
    ));
  }

  // Helper to create muted background colors
  Color _muteColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.4).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.5 + 0.15).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    
    // Draw static gradient background with professionally muted colors
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _muteColor(themeConfig.gradientStart),
        _muteColor(themeConfig.gradientMiddle),
        _muteColor(themeConfig.gradientEnd),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final bgPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Save canvas state for clipping
    canvas.save();
    canvas.clipRect(rect);

    // Draw clouds in layers for depth
    for (final cloud in _clouds) {
      _drawCloud(canvas, size, cloud, progress);
    }

    canvas.restore();
  }

  void _drawCloud(Canvas canvas, Size size, _Cloud cloud, double progress) {
    // Smooth horizontal movement with natural flow
    final normalizedProgress = progress * cloud.speed * 8;
    final x = ((cloud.x + normalizedProgress) % 1.3) - 0.15;
    
    // Refined vertical floating with multiple harmonics for organic movement
    final verticalOffset = sin(progress * 2 * pi * 0.6 + cloud.layer * pi / 4) * 
                           cloud.verticalAmplitude * 0.7 +
                           sin(progress * 2 * pi * 0.35 + cloud.layer * 0.8) * 
                           cloud.verticalAmplitude * 0.3;
    final y = cloud.y + verticalOffset;
    
    // Calculate center position
    final center = Offset(x * size.width, y * size.height);
    final baseRadius = cloud.size * size.width * 0.5;
    
    // Subtle breathing effect - much more gentle
    final pulse = 1.0 + sin(progress * 2 * pi * 0.4 + cloud.layer * 0.6) * 0.03 +
                        sin(progress * 2 * pi * 0.25 + cloud.layer) * 0.02;
    final radius = baseRadius * pulse;
    
    // Generate dynamic organic cloud shape based on circle count
    final cloudCircles = _generateCloudShape(cloud.circleCount);
    
    // Get theme-tinted color for this cloud
    final tintColor = _getCloudTint(cloud);
    
    // Draw cloud with theme color gradients and improved depth
    for (int i = 0; i < cloudCircles.length; i++) {
      final circle = cloudCircles[i];
      final circleCenter = Offset(
        center.dx + circle.offsetX * radius,
        center.dy + circle.offsetY * radius,
      );
      final circleRadius = radius * circle.scale;
      
      // Layer-based opacity with subtle variation
      final layerOpacity = cloud.opacity * (1.0 + cloud.layer * 0.015);
      
      // Progressive blur: far layers are much blurrier for depth
      final blurAmount = 40.0 - (cloud.layer * 3.5);
      
      // Create radial gradient from white center to theme-tinted edges
      final distanceFromCenter = (circle.offsetX.abs() + circle.offsetY.abs()) / 2;
      final colorMix = distanceFromCenter.clamp(0.0, 1.0);
      
      // Blend white with theme tint based on position in cloud
      final cloudColor = Color.lerp(
        Colors.white,
        tintColor,
        colorMix * cloud.colorTintStrength,
      )!;
      
      final paint = Paint()
        ..color = cloudColor.withOpacity(layerOpacity * pulse * (1.0 - colorMix * 0.3))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, 
          blurAmount.clamp(20.0, 40.0),
        );

      canvas.drawCircle(circleCenter, circleRadius, paint);
    }
  }
  
  // Generate organic cloud shape with variable number of circles
  List<_CloudCircle> _generateCloudShape(int circleCount) {
    final circles = <_CloudCircle>[];
    
    // Always include center circle (largest)
    circles.add(_CloudCircle(0.0, -0.05, 1.0));
    
    // Add surrounding circles based on count
    if (circleCount >= 4) {
      circles.add(_CloudCircle(-0.45, 0.0, 0.75));  // Left
      circles.add(_CloudCircle(0.45, 0.05, 0.70));  // Right
      circles.add(_CloudCircle(-0.18, -0.12, 0.85)); // Top left
    }
    
    if (circleCount >= 5) {
      circles.add(_CloudCircle(0.28, 0.08, 0.78));  // Right center
    }
    
    if (circleCount >= 6) {
      circles.add(_CloudCircle(0.15, -0.18, 0.72)); // Top right
    }
    
    if (circleCount >= 7) {
      circles.add(_CloudCircle(-0.32, 0.12, 0.68)); // Bottom left
    }
    
    return circles;
  }
  
  // Get theme-appropriate tint color for clouds
  Color _getCloudTint(_Cloud cloud) {
    // Blend accent color with primary color based on layer
    final layerMix = (cloud.layer / 8).clamp(0.0, 1.0);
    return Color.lerp(
      themeConfig.accentLight,
      themeConfig.primaryColor,
      layerMix,
    )!;
  }

  @override
  bool shouldRepaint(CloudsPainter oldDelegate) => false;
}

class _Cloud {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final int layer;
  final double verticalAmplitude;
  final int circleCount;
  final double colorTintStrength;

  _Cloud({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.layer,
    required this.verticalAmplitude,
    required this.circleCount,
    required this.colorTintStrength,
  });
}

class _CloudCircle {
  final double offsetX;
  final double offsetY;
  final double scale;

  _CloudCircle(this.offsetX, this.offsetY, this.scale);
}

