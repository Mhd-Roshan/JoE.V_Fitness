import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Central controller for blocking / allowing screenshots (Android FLAG_SECURE).
///
/// Screenshots are blocked when EITHER:
///  1. The user is exploring the app without having paid the ₹99 Entry Pass
///     (global "explore lock", set by [AuthWrapper]), OR
///  2. At least one sensitive screen (e.g. trainer selection) is open
///     (tracked with a reference count via [acquire] / [release]).
///
/// Using a single service prevents one screen from re-enabling screenshots
/// on dispose while the app should still be locked.
class ScreenshotSecurityService {
  ScreenshotSecurityService._();
  static final ScreenshotSecurityService instance =
      ScreenshotSecurityService._();

  static const MethodChannel _channel = MethodChannel(
    'com.joev.fitness/screenshot',
  );

  bool _exploreLock = false;
  int _screenLocks = 0;
  bool? _appliedSecure; // last state sent to native (null = unknown)

  bool get isSecure => _exploreLock || _screenLocks > 0;

  /// Block screenshots for the whole app while the user is in unpaid explore mode.
  void setExploreLock(bool locked) {
    if (_exploreLock == locked) return;
    _exploreLock = locked;
    _apply();
  }

  /// Call from a sensitive screen's initState.
  void acquire() {
    _screenLocks++;
    _apply();
  }

  /// Call from a sensitive screen's dispose.
  void release() {
    if (_screenLocks > 0) _screenLocks--;
    _apply();
  }

  Future<void> _apply() async {
    final bool secure = isSecure;
    if (_appliedSecure == secure) return;
    _appliedSecure = secure;
    try {
      await _channel.invokeMethod(
        secure ? 'disableScreenshots' : 'enableScreenshots',
      );
    } catch (e) {
      _appliedSecure = null; // allow retry next time
      debugPrint('ScreenshotSecurityService error: $e');
    }
  }
}
