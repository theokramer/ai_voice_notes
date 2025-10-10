import 'package:flutter/material.dart';

class AnimationUtils {
  /// Check if reduced motion is enabled
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get animation duration based on reduced motion setting
  static Duration getDuration(
    BuildContext context,
    Duration normalDuration, {
    Duration? reducedDuration,
  }) {
    if (shouldReduceMotion(context)) {
      return reducedDuration ?? Duration.zero;
    }
    return normalDuration;
  }

  /// Get curve based on reduced motion setting
  static Curve getCurve(BuildContext context, Curve normalCurve) {
    if (shouldReduceMotion(context)) {
      return Curves.linear;
    }
    return normalCurve;
  }

  /// Conditionally animate widget
  static Widget conditionalAnimate({
    required BuildContext context,
    required Widget child,
    required Widget Function(Widget) animateBuilder,
  }) {
    if (shouldReduceMotion(context)) {
      return child;
    }
    return animateBuilder(child);
  }
}

/// Extension on Duration for easier reduced motion handling
extension DurationX on Duration {
  Duration reduced(BuildContext context) {
    return AnimationUtils.shouldReduceMotion(context) 
        ? Duration.zero 
        : this;
  }
}

/// Extension on Curve for easier reduced motion handling
extension CurveX on Curve {
  Curve reduced(BuildContext context) {
    return AnimationUtils.shouldReduceMotion(context) 
        ? Curves.linear 
        : this;
  }
}

