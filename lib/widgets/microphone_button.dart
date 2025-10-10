import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import 'waveform_visualizer.dart';

class MicrophoneButton extends StatefulWidget {
  final VoidCallback onRecordingStart;
  final VoidCallback onRecordingStop;

  const MicrophoneButton({
    super.key,
    required this.onRecordingStart,
    required this.onRecordingStop,
  });

  @override
  State<MicrophoneButton> createState() => _MicrophoneButtonState();
}

class _MicrophoneButtonState extends State<MicrophoneButton>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  late AnimationController _pressController;
  late AnimationController _recordingController;
  late AnimationController _successController;
  late AnimationController _pulseController;
  late AnimationController _breathingController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;
  double _currentAmplitude = 0.3;
  DateTime? _lastAmplitudeUpdate;

  @override
  void initState() {
    super.initState();
    
    // Press animation - spring effect
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutBack,
      ),
    );

    // Recording animation - subtle pulse
    _recordingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Pulse animation for audio reactivity
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    // Breathing animation for idle state
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );

    // Glow animation for idle state
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.5).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Success animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Update amplitude from waveform (smoother updates)
    _recordingController.addListener(() {
      if (_isRecording) {
        final now = DateTime.now();
        if (_lastAmplitudeUpdate == null ||
            now.difference(_lastAmplitudeUpdate!).inMilliseconds > 100) {
          setState(() {
            // Simulate audio amplitude (in production, get from actual audio input)
            final newAmplitude = 0.3 + Random().nextDouble() * 0.5;
            // Smooth transition
            _currentAmplitude = _currentAmplitude * 0.7 + newAmplitude * 0.3;
            _lastAmplitudeUpdate = now;
            
            // Trigger pulse on higher amplitude
            if (_currentAmplitude > 0.6 && !_pulseController.isAnimating) {
              _pulseController.forward().then((_) => _pulseController.reverse());
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _pressController.dispose();
    _recordingController.dispose();
    _successController.dispose();
    _pulseController.dispose();
    _breathingController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handlePressStart() {
    setState(() {
      _isRecording = true;
    });
    _pressController.forward();
    _recordingController.repeat();
    _breathingController.stop();
    _glowController.stop();
    widget.onRecordingStart();
  }

  void _handlePressEnd() {
    setState(() {
      _isRecording = false;
    });
    _recordingController.stop();
    _recordingController.reset();
    _pressController.reverse();
    _breathingController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    
    // Play success animation
    _successController.forward().then((_) {
      _successController.reset();
    });
    
    widget.onRecordingStop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        
        return GestureDetector(
          onTapDown: (_) => _handlePressStart(),
          onTapUp: (_) => _handlePressEnd(),
          onTapCancel: () => _handlePressEnd(),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _pressController,
              _recordingController,
              _successController,
              _pulseController,
              _breathingController,
              _glowController,
            ]),
            builder: (context, child) {
              final buttonSize = _isRecording ? 90.0 : 95.0;
              final waveformOpacity = _currentAmplitude.clamp(0.4, 0.9);
              
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient glow ring (idle state only) - uses theme color
                      if (!_isRecording)
                        AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: themeConfig.primaryColor.withOpacity(_glowAnimation.value * 0.25),
                                    blurRadius: 25,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      
                      // Waveform visualizer when recording
                      if (_isRecording)
                        Opacity(
                          opacity: waveformOpacity,
                          child: Transform.scale(
                            scale: _pulseAnimation.value,
                            child: WaveformVisualizer(
                              isRecording: _isRecording,
                              size: 115,
                              color: themeConfig.accentLight.withOpacity(0.6),
                              amplitude: _currentAmplitude,
                            ),
                          ),
                        ),
                      
                      // Outer pulse ring (recording state) - uses theme color
                      if (_isRecording)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 100 * _pulseAnimation.value,
                              height: 100 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: themeConfig.accentLight.withOpacity(0.3 * (1 - (_pulseAnimation.value - 1) * 5)),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      
                      // Main button with glass effect
                      AnimatedBuilder(
                        animation: _breathingAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isRecording ? 1.0 : _breathingAnimation.value,
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: _isRecording ? 0 : 15,
                                  sigmaY: _isRecording ? 0 : 15,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  width: buttonSize,
                                  height: buttonSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _isRecording
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              themeConfig.buttonColor,
                                              themeConfig.buttonColor.withOpacity(0.85),
                                            ],
                                          )
                                        : null,
                                    color: _isRecording ? null : AppTheme.glassStrongSurface,
                                    border: Border.all(
                                      color: _isRecording
                                          ? themeConfig.accentLight.withOpacity(0.5)
                                          : AppTheme.glassBorder.withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: _isRecording
                                        ? [
                                            BoxShadow(
                                              color: themeConfig.primaryColor.withOpacity(0.35 * _currentAmplitude),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                              offset: const Offset(0, 6),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 15,
                                              spreadRadius: 0,
                                              offset: const Offset(0, 5),
                                            ),
                                            BoxShadow(
                                              color: themeConfig.primaryColor.withOpacity(0.1),
                                              blurRadius: 10,
                                              spreadRadius: 0,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Center(
                                    child: Transform.scale(
                                      scale: _isRecording ? (1.0 + (_currentAmplitude - 0.5) * 0.08) : 1.0,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 250),
                                        switchInCurve: Curves.easeOutBack,
                                        switchOutCurve: Curves.easeInBack,
                                        child: Icon(
                                          _successController.isAnimating
                                              ? Icons.check_rounded
                                              : Icons.mic_rounded,
                                          key: ValueKey(_successController.isAnimating),
                                          size: 40,
                                          color: _isRecording || _successController.isAnimating
                                              ? Colors.white
                                              : AppTheme.textPrimary.withOpacity(0.9),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

}
