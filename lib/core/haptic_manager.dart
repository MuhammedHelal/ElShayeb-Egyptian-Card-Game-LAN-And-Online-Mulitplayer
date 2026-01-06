import 'dart:developer';

import 'package:vibration/vibration.dart';

/// Types of haptic feedback
enum HapticType {
  light,
  medium,
  heavy,
  success,
  error,
  selection,
}

/// Haptic feedback manager
class HapticManager {
  static final HapticManager _instance = HapticManager._internal();
  factory HapticManager() => _instance;
  HapticManager._internal();

  bool _isEnabled = true;
  bool _hasVibrator = false;
  bool _isInitialized = false;

  /// Initialize - check if device has vibrator
  Future<void> init() async {
    if (_isInitialized) return;

    _hasVibrator = await Vibration.hasVibrator();
    _isInitialized = true;
  }

  /// Enable/disable haptic feedback
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  bool get isEnabled => _isEnabled;

  /// Trigger haptic feedback
  Future<void> trigger(HapticType type) async {
    if (!_isEnabled || !_hasVibrator) return;

    try {
      switch (type) {
        case HapticType.light:
          await Vibration.vibrate(duration: 10, amplitude: 50);
          break;
        case HapticType.medium:
          await Vibration.vibrate(duration: 20, amplitude: 100);
          break;
        case HapticType.heavy:
          await Vibration.vibrate(duration: 50, amplitude: 200);
          break;
        case HapticType.success:
          await Vibration.vibrate(
              pattern: [0, 50, 50, 50], intensities: [0, 128, 0, 255]);
          break;
        case HapticType.error:
          await Vibration.vibrate(
              pattern: [0, 100, 50, 100], intensities: [0, 255, 0, 255]);
          break;
        case HapticType.selection:
          await Vibration.vibrate(duration: 5, amplitude: 30);
          break;
      }
    } catch (e) {
      log('Haptic error: $e');
    }
  }

  /// Quick vibration for card actions
  Future<void> cardTap() => trigger(HapticType.light);

  /// Vibration for successful match
  Future<void> matchFound() => trigger(HapticType.success);

  /// Vibration for drawing a card
  Future<void> cardDraw() => trigger(HapticType.medium);

  /// Vibration for finishing/winning
  Future<void> victory() => trigger(HapticType.success);

  /// Vibration for becoming Shayeb
  Future<void> defeat() => trigger(HapticType.error);
}
