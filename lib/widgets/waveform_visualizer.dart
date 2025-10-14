import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaveformVisualizer extends StatefulWidget {
  final bool isRecording;
  final double size;
  final Color color;
  final double amplitude; // 0.0 to 1.0 representing audio level

  const WaveformVisualizer({
    super.key,
    required this.isRecording,
    this.size = 200,
    required this.color,
    this.amplitude = 0.5,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _waveformData = List.generate(32, (index) => 0.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat();

    _controller.addListener(() {
      if (widget.isRecording) {
        _updateWaveform();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateWaveform() {
    if (!mounted) return;
    
    setState(() {
      // Simulate audio amplitude with some randomness for demo
      // In production, this would be fed from actual audio data
      final random = Random();
      for (int i = 0; i < _waveformData.length; i++) {
        // Smooth transition
        final target = widget.amplitude * (0.3 + random.nextDouble() * 0.7);
        _waveformData[i] = _waveformData[i] * 0.7 + target * 0.3;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.isRecording
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: CircularWaveformPainter(
                    waveformData: _waveformData,
                    color: widget.color,
                    progress: _controller.value,
                  ),
                );
              },
            )
          : const SizedBox(),
    );
  }
}

class CircularWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color color;
  final double progress;

  CircularWaveformPainter({
    required this.waveformData,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.35;
    
    // Draw multiple concentric waveform rings
    _drawWaveformRing(canvas, center, baseRadius, 1.0, color.withOpacity(0.6));
    _drawWaveformRing(canvas, center, baseRadius * 1.3, 0.7, color.withOpacity(0.4));
    _drawWaveformRing(canvas, center, baseRadius * 1.6, 0.5, color.withOpacity(0.2));

    // Draw particle bursts on peaks
    _drawParticles(canvas, center, baseRadius);
  }

  void _drawWaveformRing(Canvas canvas, Offset center, double radius, double amplitudeMultiplier, Color ringColor) {
    final path = Path();
    final numBars = waveformData.length;
    
    for (int i = 0; i < numBars; i++) {
      final angle = (i / numBars) * 2 * pi + progress * 2 * pi;
      final nextAngle = ((i + 1) / numBars) * 2 * pi + progress * 2 * pi;
      
      // Calculate bar height based on waveform data
      final barHeight = waveformData[i] * radius * 0.4 * amplitudeMultiplier;
      
      final innerRadius = radius - barHeight / 2;
      final outerRadius = radius + barHeight / 2;
      
      // Create bar shape
      final p1 = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
      final p3 = Offset(
        center.dx + outerRadius * cos(nextAngle),
        center.dy + outerRadius * sin(nextAngle),
      );
      final p4 = Offset(
        center.dx + innerRadius * cos(nextAngle),
        center.dy + innerRadius * sin(nextAngle),
      );
      
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      }
      
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
      path.lineTo(p1.dx, p1.dy);
    }
    
    final paint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawPath(path, paint);
  }

  void _drawParticles(Canvas canvas, Offset center, double baseRadius) {
    final numBars = waveformData.length;
    
    for (int i = 0; i < numBars; i += 4) {
      if (waveformData[i] > 0.7) { // Only show particles on peaks
        final angle = (i / numBars) * 2 * pi + progress * 2 * pi;
        final distance = baseRadius + waveformData[i] * baseRadius * 0.6;
        
        final particlePos = Offset(
          center.dx + distance * cos(angle),
          center.dy + distance * sin(angle),
        );
        
        final particlePaint = Paint()
          ..color = color.withOpacity(waveformData[i] * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        
        canvas.drawCircle(particlePos, 3, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(CircularWaveformPainter oldDelegate) => true;
}

// Linear waveform for detailed display
class LinearWaveform extends StatefulWidget {
  final bool isActive;
  final double height;
  final Color color;
  final List<double>? amplitudes;
  final double currentAmplitude; // Real-time amplitude for voice visualization

  const LinearWaveform({
    super.key,
    required this.isActive,
    this.height = 60,
    required this.color,
    this.amplitudes,
    this.currentAmplitude = 0.5,
  });

  @override
  State<LinearWaveform> createState() => _LinearWaveformState();
}

class _LinearWaveformState extends State<LinearWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _bars = List.generate(80, (index) => 0.1); // Increased for smoother visualization

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50), // Faster updates for real-time feel
    )..repeat();

    _controller.addListener(() {
      if (widget.isActive) {
        _updateBars();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateBars() {
    if (!mounted) return;
    
    setState(() {
      final random = Random();
      for (int i = 0; i < _bars.length; i++) {
        if (widget.amplitudes != null && i < widget.amplitudes!.length) {
          _bars[i] = widget.amplitudes![i];
        } else {
          // Use real amplitude data with smooth interpolation
          final baseAmplitude = widget.currentAmplitude;
          final variation = (random.nextDouble() - 0.5) * 0.3; // Add natural variation
          final targetAmplitude = (baseAmplitude + variation).clamp(0.0, 1.0);
          
          // Smooth interpolation to prevent jitter
          _bars[i] = _bars[i] * 0.7 + targetAmplitude * 0.3;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: widget.isActive
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: LinearWaveformPainter(
                    bars: _bars,
                    color: widget.color,
                  ),
                );
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
    );
  }
}

class LinearWaveformPainter extends CustomPainter {
  final List<double> bars;
  final Color color;

  LinearWaveformPainter({
    required this.bars,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / bars.length;
    final centerY = size.height / 2;
    
    // Create gradient for premium look
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.8),
        color.withOpacity(0.4),
        color.withOpacity(0.2),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    for (int i = 0; i < bars.length; i++) {
      final barHeight = bars[i] * size.height * 0.8;
      final x = i * barWidth + barWidth / 2;
      
      // Create gradient paint
      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = barWidth * 0.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5); // Subtle glow
      
      // Draw main bar
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
      
      // Add highlight for higher amplitudes
      if (bars[i] > 0.6) {
        final highlightPaint = Paint()
          ..color = color.withOpacity(0.9)
          ..strokeWidth = barWidth * 0.4
          ..strokeCap = StrokeCap.round;
        
        canvas.drawLine(
          Offset(x, centerY - barHeight / 3),
          Offset(x, centerY + barHeight / 3),
          highlightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(LinearWaveformPainter oldDelegate) => true;
}

// Apple Voice Memos-style scrolling waveform
class VoiceMemoWaveform extends StatefulWidget {
  final bool isActive;
  final double height;
  final Color color;
  final double currentAmplitude;
  final List<double> amplitudeHistory;

  const VoiceMemoWaveform({
    super.key,
    required this.isActive,
    this.height = 100,
    required this.color,
    required this.currentAmplitude,
    required this.amplitudeHistory,
  });

  @override
  State<VoiceMemoWaveform> createState() => _VoiceMemoWaveformState();
}

class _VoiceMemoWaveformState extends State<VoiceMemoWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50), // Fast updates for smooth scrolling
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: widget.isActive
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: VoiceMemoWaveformPainter(
                    amplitudeHistory: widget.amplitudeHistory,
                    currentAmplitude: widget.currentAmplitude,
                    color: widget.color,
                    progress: _controller.value,
                  ),
                );
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
    );
  }
}

class VoiceMemoWaveformPainter extends CustomPainter {
  final List<double> amplitudeHistory;
  final double currentAmplitude;
  final Color color;
  final double progress;

  VoiceMemoWaveformPainter({
    required this.amplitudeHistory,
    required this.currentAmplitude,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barWidth = size.width / 120; // 120 bars for smooth scrolling
    final maxBarHeight = size.height * 0.8;
    
    // Create gradient for Apple-style look
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.9),
        color.withOpacity(0.6),
        color.withOpacity(0.3),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    // Draw bars from right to left (newest on right)
    for (int i = 0; i < 120; i++) {
      double amplitude;
      
      if (i < amplitudeHistory.length) {
        // Use historical data with smoothing
        final historyIndex = amplitudeHistory.length - 1 - i;
        amplitude = amplitudeHistory[historyIndex];
        
        // Apply smoothing to reduce noise
        if (historyIndex > 0 && historyIndex < amplitudeHistory.length - 1) {
          amplitude = (amplitudeHistory[historyIndex - 1] + 
                      amplitudeHistory[historyIndex] + 
                      amplitudeHistory[historyIndex + 1]) / 3;
        }
      } else if (i == amplitudeHistory.length) {
        // Current amplitude
        amplitude = currentAmplitude;
      } else {
        // Empty space for future bars
        amplitude = 0.0;
      }
      
      // Apply minimum threshold to reduce visual noise
      if (amplitude < 0.1) amplitude = 0.0;
      
      final barHeight = amplitude * maxBarHeight;
      final x = size.width - (i * barWidth) - barWidth / 2;
      
      if (x < 0) break; // Don't draw outside canvas
      
      // Create gradient paint
      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = barWidth * 0.8
        ..strokeCap = StrokeCap.round;
      
      // Draw main bar
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
      
      // Add highlight for higher amplitudes (Apple-style)
      if (amplitude > 0.6) {
        final highlightPaint = Paint()
          ..color = color.withOpacity(0.9)
          ..strokeWidth = barWidth * 0.4
          ..strokeCap = StrokeCap.round;
        
        canvas.drawLine(
          Offset(x, centerY - barHeight / 3),
          Offset(x, centerY + barHeight / 3),
          highlightPaint,
        );
      }
    }
    
    // Draw center line (subtle)
    final centerLinePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 1;
    
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(VoiceMemoWaveformPainter oldDelegate) => true;
}

// Pulsing ring animation for the microphone button
class PulsingRing extends StatefulWidget {
  final double size;
  final Color color;
  final bool isActive;

  const PulsingRing({
    super.key,
    required this.size,
    required this.color,
    required this.isActive,
  });

  @override
  State<PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(PulsingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size * _scaleAnimation.value,
          height: widget.size * _scaleAnimation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withOpacity(_opacityAnimation.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

