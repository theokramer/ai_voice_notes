import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

class MicrophoneButton extends StatefulWidget {
  final VoidCallback onRecordingStart;
  final VoidCallback onRecordingStop;
  final VoidCallback? onRecordingLock;
  final VoidCallback? onRecordingUnlock;

  const MicrophoneButton({
    super.key,
    required this.onRecordingStart,
    required this.onRecordingStop,
    this.onRecordingLock,
    this.onRecordingUnlock,
  });

  @override
  State<MicrophoneButton> createState() => MicrophoneButtonState();
}

class MicrophoneButtonState extends State<MicrophoneButton>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  late AnimationController _pressController;
  late AnimationController _recordingController;
  late AnimationController _successController;
  late AnimationController _pulseController;
  late AnimationController _breathingController;
  late AnimationController _glowController;
  late AnimationController _lockController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _lockAnimation;
  double _currentAmplitude = 0.3;
  DateTime? _lastAmplitudeUpdate;
  
  // Drag-to-lock state
  double _dragOffset = 0.0;
  double _dragStartGlobalY = 0.0;
  bool _isLocked = false;
  bool _isDragging = false;
  bool _isStoppingRecording = false; // Guard to prevent duplicate recordings during stop
  static const double _lockThreshold = 35.0; // Drag 35px upward to lock after drag is recognized
  static const double _dragStartThreshold = 0.5; // Immediately recognize any upward movement as drag

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

  /// Reset the microphone button's internal state
  /// Called when recording is stopped from external source (overlay buttons)
  void resetRecordingState() {
    debugPrint('🔄 Resetting microphone button state');
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isDragging = false;
      _dragOffset = 0.0;
      _dragStartGlobalY = 0.0;
      _isStoppingRecording = false;
    });
    _recordingController.stop();
    _recordingController.reset();
    _pressController.reverse();
    _breathingController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    _lockController.reverse();
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
      _dragStartGlobalY = 0.0;
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

  Future<void> _handleStopButtonTap() async {
    debugPrint('🛑 Stop button tapped!');
    
    // Set guard flag immediately to prevent new recordings
    if (_isStoppingRecording) {
      debugPrint('⚠️ Stop already in progress, ignoring tap');
      return;
    }
    
    setState(() {
      _isStoppingRecording = true;
    });
    
    // Prevent any new gestures from being processed during this operation
    final wasRecording = _isRecording;
    final wasLocked = _isLocked;
    
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isDragging = false;
      _dragOffset = 0.0;
      _dragStartGlobalY = 0.0;
    });
    
    // Notify parent about unlock state change
    if (wasLocked) {
      widget.onRecordingUnlock?.call();
    }
    
    if (!wasRecording || !wasLocked) {
      debugPrint('⚠️ Stop button tapped but not in valid state (recording: $wasRecording, locked: $wasLocked)');
      setState(() {
        _isStoppingRecording = false;
      });
      return;
    }
    
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
    
    // Call stop recording callback
    widget.onRecordingStop();
    
    // Add delay to prevent immediate re-recording and allow state to fully reset
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Reset guard flag
    if (mounted) {
      setState(() {
        _isStoppingRecording = false;
      });
    }
  }

  void _handleDragUpdate(double offset) {
    if (_isLocked) return;
    
    // Only track negative (upward) movement - upward is negative in widget coordinates
    // Ignore any downward movement by resetting to 0
    if (offset > 0) {
      setState(() {
        _dragOffset = 0.0;
      });
      _lockController.value = 0.0;
      return;
    }
    
    // Track upward movement (negative offset in widget coordinates)
    // Clamp to reasonable min value (allow up to -50px for visual feedback, slightly beyond lock threshold)
    final clampedOffset = offset.clamp(-50.0, 0.0);
    
    setState(() {
      _dragOffset = clampedOffset;
    });
    
    // Update lock animation based on progress toward threshold
    // Use absolute value: progress goes from 0.0 (at 0) to 1.0 (at -100px upward)
    final progress = (_dragOffset.abs() / _lockThreshold).clamp(0.0, 1.0);
    _lockController.value = progress;
    
    if (progress > 0.2) {
      debugPrint('📊 Drag progress: ${(progress * 100).toInt()}% (offset: $_dragOffset, abs: ${_dragOffset.abs()})');
    }
  }

  void _handleDragEnd() {
    debugPrint('🔒 Drag ended: offset=$_dragOffset, abs=${_dragOffset.abs()}, threshold=$_lockThreshold, isDragging=$_isDragging');
    
    // Check if dragged far enough upward (using absolute value since offset is negative)
    if (_dragOffset.abs() >= _lockThreshold) {
      // Lock the recording
      debugPrint('✅ Locking recording!');
      setState(() {
        _isLocked = true;
        _isDragging = false;
      });
      
      // Notify parent about lock state change
      widget.onRecordingLock?.call();
      
      // Haptic feedback
      // Note: You might want to add HapticService.heavyImpact() here if available
    } else {
      // Release without locking - stop recording
      debugPrint('❌ Not locked, stopping recording (offset: $_dragOffset, abs: ${_dragOffset.abs()})');
      _handlePressEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        
        return AnimatedBuilder(
          animation: Listenable.merge([
            _pressController,
            _recordingController,
            _successController,
            _pulseController,
            _breathingController,
            _glowController,
            _lockController,
          ]),
          builder: (context, child) {
            final buttonSize = _isRecording ? 90.0 : 95.0;
            
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: RawGestureDetector(
                gestures: {
                  _AllowMultipleGestureRecognizer: GestureRecognizerFactoryWithHandlers<_AllowMultipleGestureRecognizer>(
                    () => _AllowMultipleGestureRecognizer(),
                    (_AllowMultipleGestureRecognizer instance) {
                      instance
                        ..onDown = (details) {
                          // When locked, any tap on the mic button should stop recording
                          if (_isLocked) {
                            debugPrint('🛑 Mic button tapped while locked - stopping recording');
                            _handleStopButtonTap();
                            return;
                          }
                          
                          // Start recording immediately on touch down
                          // Prevent starting if we're in the middle of stopping a recording
                          if (!_isRecording && !_isLocked && !_isStoppingRecording) {
                            setState(() {
                              _dragStartGlobalY = details.position.dy;
                              _isDragging = false;
                              _dragOffset = 0.0;
                            });
                            _handlePressStart();
                          }
                        }
                        ..onUpdate = (details) {
                          // Track vertical drag
                          if (_isRecording && !_isLocked) {
                            // Calculate offset from start position using GLOBAL coordinates
                            // Negative offset = Y decreases in screen space (dragging upward)
                            final offset = details.position.dy - _dragStartGlobalY;
                            
                            // Always update drag offset to provide immediate visual feedback
                            _handleDragUpdate(offset);
                            
                            // Mark as dragging once moved upward beyond threshold
                            if (!_isDragging && offset < -_dragStartThreshold) {
                              setState(() {
                                _isDragging = true;
                              });
                              debugPrint('🎯 Started dragging upward! offset: $offset (abs: ${offset.abs()})');
                            }
                          }
                        }
                        ..onEnd = (details) {
                          // Handle release
                          if (_isRecording && !_isLocked) {
                            // Check if there was any upward movement (negative offset)
                            // or if dragging was explicitly recognized
                            if (_isDragging || _dragOffset < 0) {
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
                child: SizedBox(
                  width: 120,
                  height: 250, // Increased height to accommodate stop button and indicators
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      
                      // Lock threshold indicator (when recording, not locked)
                      if (_isRecording && !_isLocked)
                        Positioned(
                          top: 60, // Positioned closer to button for short drag gesture
                          child: AnimatedBuilder(
                            animation: _lockAnimation,
                            builder: (context, child) {
                              // Start more visible, increase as dragging up
                              final opacity = 0.6 + (_lockAnimation.value * 0.4);
                              final scale = 0.9 + (_lockAnimation.value * 0.2); // Scale up as approaching lock
                              return Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: opacity,
                                  child: Column(
                                    children: [
                                      // Lock icon with animated background
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: themeConfig.accentLight.withOpacity(
                                            0.15 + (_lockAnimation.value * 0.25)
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: themeConfig.accentLight.withOpacity(
                                              0.4 + (_lockAnimation.value * 0.6)
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          _lockAnimation.value > 0.8 ? Icons.lock : Icons.lock_outline,
                                          size: 24,
                                          color: themeConfig.accentLight,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Progress bar
                                      Container(
                                        width: 50,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: themeConfig.accentLight.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: _lockAnimation.value,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: themeConfig.accentLight,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Text hint
                                      Text(
                                        _lockAnimation.value > 0.8 ? 'Release to lock' : 'Slide up',
                                        style: TextStyle(
                                          color: themeConfig.accentLight.withOpacity(0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
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
              ),
            );
          },
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
