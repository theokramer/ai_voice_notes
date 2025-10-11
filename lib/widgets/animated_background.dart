import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BackgroundStyle {
  none,              // Just solid gradient, no animation
  clouds,            // Gentle floating clouds
  meshGradient,      // Flowing morphing gradients
  softBlobs,         // Soft colorful floating blobs (Recommended)
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
      duration: const Duration(seconds: 30), // Very slow, ultra-smooth animation
    )..repeat();
  }

  @override
  void didUpdateWidget(AnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger rebuild when theme changes
    if (oldWidget.themeConfig != widget.themeConfig) {
      setState(() {
        // Forces a rebuild with new theme
      });
    }
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
        // Animated background layer with smooth theme transitions
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  child: CustomPaint(
                    painter: _getPainter(),
                  ),
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
                  Colors.black.withValues(alpha: 0.35),  // Darker at top
                  Colors.black.withValues(alpha: 0.25),  // Lighter in middle
                  Colors.black.withValues(alpha: 0.30),  // Slightly darker at bottom
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
      case BackgroundStyle.softBlobs:
        return SoftBlobsPainter(
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
          colors[i].withValues(alpha: 0.3),  // Reduced from 0.6
          colors[i].withValues(alpha: 0.0),
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
  bool shouldRepaint(MeshGradientPainter oldDelegate) {
    // Repaint when theme changes
    return oldDelegate.themeConfig != themeConfig;
  }
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
  bool shouldRepaint(StaticGradientPainter oldDelegate) {
    // Repaint when theme changes
    return oldDelegate.themeConfig != themeConfig;
  }
}


// Clouds Painter - Modern gentle floating clouds
// Enhanced with theme color integration and improved depth
class CloudsPainter extends CustomPainter {
  final Animation<double> animation;
  final ThemeConfig themeConfig;
  late final List<_Cloud> _clouds;

  CloudsPainter({
    required this.animation,
    required this.themeConfig,
  }) : super(repaint: animation) {
    _clouds = _initClouds();
  }

  List<_Cloud> _initClouds() {
    final clouds = <_Cloud>[];
    
    // Modern gentle clouds - ultra-subtle and barely visible
    // Only 5 clouds for minimal visual presence
    clouds.add(_Cloud(
      x: 0.15,
      y: 0.20,
      size: 0.40,
      speed: 0.010,
      opacity: 0.06,
      layer: 0,
      verticalAmplitude: 0.025,
      circleCount: 5,
      colorTintStrength: 0.08,
    ));
    
    clouds.add(_Cloud(
      x: 0.70,
      y: 0.25,
      size: 0.38,
      speed: 0.012,
      opacity: 0.07,
      layer: 1,
      verticalAmplitude: 0.028,
      circleCount: 4,
      colorTintStrength: 0.10,
    ));
    
    clouds.add(_Cloud(
      x: 0.35,
      y: 0.50,
      size: 0.36,
      speed: 0.014,
      opacity: 0.08,
      layer: 2,
      verticalAmplitude: 0.030,
      circleCount: 5,
      colorTintStrength: 0.12,
    ));
    
    clouds.add(_Cloud(
      x: 0.80,
      y: 0.65,
      size: 0.34,
      speed: 0.016,
      opacity: 0.07,
      layer: 3,
      verticalAmplitude: 0.032,
      circleCount: 4,
      colorTintStrength: 0.10,
    ));
    
    clouds.add(_Cloud(
      x: 0.25,
      y: 0.78,
      size: 0.32,
      speed: 0.015,
      opacity: 0.06,
      layer: 4,
      verticalAmplitude: 0.030,
      circleCount: 4,
      colorTintStrength: 0.08,
    ));
    
    return clouds;
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
    // Ultra-gentle horizontal movement - very slow
    final normalizedProgress = progress * cloud.speed * 4;
    // Continuous movement without reset - clouds flow off screen and reappear seamlessly
    var x = cloud.x + normalizedProgress;
    // When cloud exits right side (> 1.3), wrap it to left side (-0.3)
    // This gives clouds space to fully exit/enter before repositioning
    if (x > 1.3) {
      x = -0.3 + ((x - 1.3) % 1.6);
    }
    
    // Minimal vertical floating for subtle effect
    final verticalOffset = sin(progress * 2 * pi * 0.4 + cloud.layer * pi / 5) * 
                           cloud.verticalAmplitude * 0.5;
    final y = cloud.y + verticalOffset;
    
    // Calculate center position
    final center = Offset(x * size.width, y * size.height);
    
    // Static size - no breathing for gentler appearance
    final radius = cloud.size * size.width * 0.5;
    
    // Generate dynamic organic cloud shape based on circle count
    final cloudCircles = _generateCloudShape(cloud.circleCount);
    
    // Get theme-tinted color for this cloud (very subtle)
    final tintColor = _getCloudTint(cloud);
    
    // Draw cloud with ultra-soft appearance
    for (int i = 0; i < cloudCircles.length; i++) {
      final circle = cloudCircles[i];
      final circleCenter = Offset(
        center.dx + circle.offsetX * radius,
        center.dy + circle.offsetY * radius,
      );
      final circleRadius = radius * circle.scale;
      
      // Consistent low opacity across all layers
      final layerOpacity = cloud.opacity;
      
      // High blur for all clouds - ultra-soft appearance
      final blurAmount = 50.0 + (cloud.layer * 2.0);
      
      // Very minimal color tint
      final distanceFromCenter = (circle.offsetX.abs() + circle.offsetY.abs()) / 2;
      final colorMix = distanceFromCenter.clamp(0.0, 1.0);
      
      // Mostly white with barely-there theme tint
      final cloudColor = Color.lerp(
        Colors.white,
        tintColor,
        colorMix * cloud.colorTintStrength * 0.5,
      )!;
      
      final paint = Paint()
        ..color = cloudColor.withValues(alpha: layerOpacity * (1.0 - colorMix * 0.2))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, 
          blurAmount.clamp(50.0, 60.0),
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
  bool shouldRepaint(CloudsPainter oldDelegate) {
    // Repaint when theme changes
    return oldDelegate.themeConfig != themeConfig;
  }
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

// Soft Blobs Painter - Optimized soft colorful floating blobs
class SoftBlobsPainter extends CustomPainter {
  final Animation<double> animation;
  final ThemeConfig themeConfig;
  late final List<_Blob> _blobs;

  SoftBlobsPainter({
    required this.animation,
    required this.themeConfig,
  }) : super(repaint: animation) {
    _blobs = _initBlobs();
  }

  List<_Blob> _initBlobs() {
    return [
      // Ultra-optimized: 4 large, visible blobs for maximum performance
      _Blob(x: 0.15, y: 0.20, size: 0.68, speed: 0.008, colorIndex: 0, opacity: 0.58),
      _Blob(x: 0.80, y: 0.18, size: 0.72, speed: 0.010, colorIndex: 1, opacity: 0.60),
      _Blob(x: 0.38, y: 0.55, size: 0.65, speed: 0.012, colorIndex: 2, opacity: 0.55),
      _Blob(x: 0.22, y: 0.80, size: 0.62, speed: 0.009, colorIndex: 3, opacity: 0.52),
    ];
  }

  Color _muteColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.45 + 0.12).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    
    // Draw darker base gradient for better blob contrast
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
    
    // Vibrant color palette for highly visible blobs
    final colors = [
      themeConfig.primaryColor,
      themeConfig.accentLight,
      themeConfig.accentColor,
      themeConfig.secondaryColor,
      themeConfig.accentLight,
    ];
    
    // Draw blobs with optimized rendering
    for (final blob in _blobs) {
      _drawBlob(canvas, size, blob, progress, colors[blob.colorIndex]);
    }
  }

  void _drawBlob(Canvas canvas, Size size, _Blob blob, double progress, Color color) {
    // Ultra-smooth minimal movement for best performance
    final moveProgress = progress * blob.speed * 5;
    final x = size.width * (blob.x + sin(moveProgress * 2 * pi) * 0.04);
    final y = size.height * (blob.y + cos(moveProgress * 2 * pi * 0.6) * 0.04);
    
    // Static size - no breathing for better performance
    final radius = size.width * blob.size;
    
    // Optimized: Simpler gradient with better visibility
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        color.withValues(alpha: blob.opacity),
        color.withValues(alpha: blob.opacity * 0.6),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    // Optimized: Reduced blur for better performance
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCenter(center: Offset(x, y), width: radius * 2, height: radius * 2),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    canvas.drawCircle(Offset(x, y), radius, paint);
  }

  @override
  bool shouldRepaint(SoftBlobsPainter oldDelegate) {
    // Repaint when theme changes
    return oldDelegate.themeConfig != themeConfig;
  }
}

class _Blob {
  final double x;
  final double y;
  final double size;
  final double speed;
  final int colorIndex;
  final double opacity;

  _Blob({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.colorIndex,
    required this.opacity,
  });
}

