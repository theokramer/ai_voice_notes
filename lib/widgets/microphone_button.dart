import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  late AnimationController _lockController;
  late AnimationController _stopButtonController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _lockAnimation;
  late Animation<double> _stopButtonAnimation;
  double _currentAmplitude = 0.3;
  DateTime? _lastAmplitudeUpdate;
  
  // Drag-to-lock state
  double _dragOffset = 0.0;
  double _dragStartY = 0.0;
  bool _isLocked = false;
  bool _isDragging = false;
  static const double _lockThreshold = 150.0; // Drag 150px in local coords to lock
  static const double _dragStartThreshold = 30.0; // Min 30px moved to start counting as drag (prevents accidents)

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

    // Lock animation
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _lockAnimation = CurvedAnimation(
      parent: _lockController,
      curve: Curves.easeOut,
    );

    // Stop button animation
    _stopButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _stopButtonAnimation = CurvedAnimation(
      parent: _stopButtonController,
      curve: Curves.easeOutBack,
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
    _lockController.dispose();
    _stopButtonController.dispose();
    super.dispose();
  }

  void _handlePressStart() {
    setState(() {
      _isRecording = true;
      _dragOffset = 0.0;
      // Don't set _isDragging here - it will be set when actual dragging starts
    });
    _pressController.forward();
    _recordingController.repeat();
    _breathingController.stop();
    _glowController.stop();
    widget.onRecordingStart();
  }

  void _handlePressEnd() {
    // Don't stop if locked - user needs to tap stop button
    if (_isLocked) {
      setState(() {
        _isDragging = false;
      });
      return;
    }
    
    setState(() {
      _isRecording = false;
      _isDragging = false;
      _dragOffset = 0.0;
      _dragStartY = 0.0;
    });
    _recordingController.stop();
    _recordingController.reset();
    _pressController.reverse();
    _breathingController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    _lockController.reverse();
    
    // Play success animation
    _successController.forward().then((_) {
      _successController.reset();
    });
    
    widget.onRecordingStop();
  }

  void _handleStopButtonTap() {
    debugPrint('🛑 Stop button tapped!');
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isDragging = false;
      _dragOffset = 0.0;
      _dragStartY = 0.0;
    });
    _recordingController.stop();
    _recordingController.reset();
    _pressController.reverse();
    _breathingController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    _lockController.reverse();
    _stopButtonController.reverse();
    
    // Play success animation
    _successController.forward().then((_) {
      _successController.reset();
    });
    
    widget.onRecordingStop();
  }

  void _handleDragUpdate(double offset) {
    if (_isLocked) return;
    
    // Only track positive (downward) movement to prevent accidental triggers
    // Ignore any upward movement by clamping negative values to 0
    if (offset < 0) {
      setState(() {
        _dragOffset = 0.0;
      });
      _lockController.value = 0.0;
      return;
    }
    
    // Track vertical movement in widget coordinates (positive = increased Y)
    // Clamp to reasonable max value
    final clampedOffset = offset.clamp(0.0, 200.0);
    
    setState(() {
      _dragOffset = clampedOffset;
    });
    
    // Update lock animation based on progress toward threshold
    // threshold is +150, so progress goes from 0.0 (at 0) to 1.0 (at +150)
    final progress = (_dragOffset / _lockThreshold).clamp(0.0, 1.0);
    _lockController.value = progress;
    
    if (progress > 0.2) {
      debugPrint('📊 Drag progress: ${(progress * 100).toInt()}% (offset: $_dragOffset, clamped from: $offset)');
    }
  }

  void _handleDragEnd() {
    debugPrint('🔒 Drag ended: offset=$_dragOffset, threshold=$_lockThreshold, isDragging=$_isDragging');
    
    if (_dragOffset >= _lockThreshold) {
      // Lock the recording
      debugPrint('✅ Locking recording!');
      setState(() {
        _isLocked = true;
        _isDragging = false;
      });
      _stopButtonController.forward();
      
      // Haptic feedback
      // Note: You might want to add HapticService.heavyImpact() here if available
    } else {
      // Release without locking - stop recording
      debugPrint('❌ Not locked, stopping recording (offset: $_dragOffset)');
      _handlePressEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        
        return RawGestureDetector(
          gestures: {
            _AllowMultipleGestureRecognizer: GestureRecognizerFactoryWithHandlers<_AllowMultipleGestureRecognizer>(
              () => _AllowMultipleGestureRecognizer(),
              (_AllowMultipleGestureRecognizer instance) {
                instance
                  ..onDown = (details) {
                    // Start recording immediately on touch down
                    if (!_isRecording && !_isLocked) {
                      setState(() {
                        _dragStartY = details.localPosition.dy;
                        _isDragging = false;
                        _dragOffset = 0.0;
                      });
                      _handlePressStart();
                    }
                  }
                  ..onUpdate = (details) {
                    // Track vertical drag
                    if (_isRecording && !_isLocked) {
                      // Calculate offset from start position in local widget coordinates
                      // Positive offset = Y increases in widget space
                      final offset = details.localPosition.dy - _dragStartY;
                      final moved = offset.abs();
                      
                      if (!_isDragging) {
                        // Check if moved enough vertically to count as dragging
                        if (moved > _dragStartThreshold) {
                          setState(() {
                            _isDragging = true;
                          });
                          debugPrint('🎯 Started dragging! Initial offset: $offset');
                        }
                      }
                      
                      if (_isDragging) {
                        // Update drag offset and animation
                        _handleDragUpdate(offset);
                      }
                    }
                  }
                  ..onEnd = (details) {
                    // Handle release
                    if (_isRecording && !_isLocked) {
                      if (_isDragging) {
                        // Was dragging - check if should lock
                        _handleDragEnd();
                      } else {
                        // Quick tap - stop recording
                        _handlePressEnd();
                      }
                    }
                  }
                  ..onCancel = () {
                    if (_isRecording && !_isLocked) {
                      _handlePressEnd();
                    }
                  };
              },
            ),
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _pressController,
              _recordingController,
              _successController,
              _pulseController,
              _breathingController,
              _glowController,
              _lockController,
              _stopButtonController,
            ]),
            builder: (context, child) {
              final buttonSize = _isRecording ? 90.0 : 95.0;
              final waveformOpacity = _currentAmplitude.clamp(0.4, 0.9);
              
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: SizedBox(
                  width: 120,
                  height: 250, // Increased height to accommodate stop button and indicators
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Stop button (when locked)
                      if (_isLocked)
                        Positioned(
                          top: 20,
                          child: ScaleTransition(
                            scale: _stopButtonAnimation,
                            child: FadeTransition(
                              opacity: _stopButtonAnimation,
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: (event) {
                                  // Consume the event so parent doesn't receive it
                                  _handleStopButtonTap();
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withOpacity(0.9),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.4),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.stop_rounded,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      // Lock threshold indicator (when recording, not locked)
                      if (_isRecording && !_isLocked)
                        Positioned(
                          top: 40,
                          child: AnimatedBuilder(
                            animation: _lockAnimation,
                            builder: (context, child) {
                              // Start with low opacity, increase as dragging up
                              final opacity = 0.3 + (_lockAnimation.value * 0.7);
                              return Opacity(
                                opacity: opacity,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 28,
                                      color: themeConfig.accentLight.withOpacity(
                                        0.5 + (_lockAnimation.value * 0.5)
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 40,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: themeConfig.accentLight.withOpacity(
                                          0.3 + (_lockAnimation.value * 0.7)
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      
                      // Main button area (centered)
                      Positioned(
                        top: 130,
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
                                                      : (_isLocked ? Icons.mic : Icons.mic_rounded),
                                                  key: ValueKey(_successController.isAnimating ? 'check' : _isLocked ? 'locked' : 'mic'),
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
                      ),
                      
                      // Slide-up hint (when recording, not locked)
                      if (_isRecording && !_isLocked)
                        Positioned(
                          bottom: 10,
                          child: AnimatedBuilder(
                            animation: _lockAnimation,
                            builder: (context, child) {
                              // Start visible, fade out as approaching lock
                              final opacity = (1.0 - _lockAnimation.value).clamp(0.0, 1.0);
                              return Opacity(
                                opacity: opacity,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 24,
                                      color: themeConfig.accentLight.withOpacity(0.7),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Slide to lock',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary.withOpacity(0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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

// Custom gesture recognizer that allows both tap and drag gestures
class _AllowMultipleGestureRecognizer extends OneSequenceGestureRecognizer {
  Function(PointerDownEvent)? onDown;
  Function(PointerMoveEvent)? onUpdate;
  Function(PointerUpEvent)? onEnd;
  VoidCallback? onCancel;

  @override
  void addPointer(PointerDownEvent event) {
    onDown?.call(event);
    startTrackingPointer(event.pointer);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onUpdate?.call(event);
    } else if (event is PointerUpEvent) {
      onEnd?.call(event);
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      onCancel?.call();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'allow_multiple_gesture';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
