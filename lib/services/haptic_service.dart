import 'package:vibration/vibration.dart';

class HapticService {
  static bool _isEnabled = true;

  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  static Future<void> light() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 10);
    }
  }

  static Future<void> medium() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 20);
    }
  }

  static Future<void> heavy() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 50);
    }
  }

  static Future<void> success() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 10);
      await Future.delayed(const Duration(milliseconds: 50));
      await Vibration.vibrate(duration: 10);
    }
  }

  static Future<void> error() async {
    if (!_isEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 30);
      await Future.delayed(const Duration(milliseconds: 50));
      await Vibration.vibrate(duration: 30);
      await Future.delayed(const Duration(milliseconds: 50));
      await Vibration.vibrate(duration: 30);
    }
  }
}

