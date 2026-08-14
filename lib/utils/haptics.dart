import 'package:flutter/services.dart';

class OobHaptics {
  OobHaptics._();

  static bool _enabled = true;

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }
}
