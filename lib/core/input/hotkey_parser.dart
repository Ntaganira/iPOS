/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.input
 * - File      : hotkey_parser.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Converts persisted hotkey labels such as `F2`, `F12`, or a
 *               single letter into Flutter shortcut activators. Invalid or
 *               unsupported labels return null so the terminal keeps working
 *               with its built-in default instead of crashing.
 * </pre>
 */

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Parses a single-key hotkey label.
///
/// Supported forms are `F1`..`F24`, a single letter, or a single digit.
ShortcutActivator? parseHotkey(String label) {
  final value = label.trim().toUpperCase();
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('F')) {
    final number = int.tryParse(value.substring(1));
    final key = number == null ? null : _functionKeys[number];
    return key == null ? null : SingleActivator(key);
  }
  if (value.length == 1) {
    final key = _letterKeys[value] ?? _digitKeys[value];
    return key == null ? null : SingleActivator(key);
  }
  return null;
}

const Map<int, LogicalKeyboardKey> _functionKeys = <int, LogicalKeyboardKey>{
  1: LogicalKeyboardKey.f1,
  2: LogicalKeyboardKey.f2,
  3: LogicalKeyboardKey.f3,
  4: LogicalKeyboardKey.f4,
  5: LogicalKeyboardKey.f5,
  6: LogicalKeyboardKey.f6,
  7: LogicalKeyboardKey.f7,
  8: LogicalKeyboardKey.f8,
  9: LogicalKeyboardKey.f9,
  10: LogicalKeyboardKey.f10,
  11: LogicalKeyboardKey.f11,
  12: LogicalKeyboardKey.f12,
  13: LogicalKeyboardKey.f13,
  14: LogicalKeyboardKey.f14,
  15: LogicalKeyboardKey.f15,
  16: LogicalKeyboardKey.f16,
  17: LogicalKeyboardKey.f17,
  18: LogicalKeyboardKey.f18,
  19: LogicalKeyboardKey.f19,
  20: LogicalKeyboardKey.f20,
  21: LogicalKeyboardKey.f21,
  22: LogicalKeyboardKey.f22,
  23: LogicalKeyboardKey.f23,
  24: LogicalKeyboardKey.f24,
};

const Map<String, LogicalKeyboardKey> _letterKeys =
    <String, LogicalKeyboardKey>{
      'A': LogicalKeyboardKey.keyA,
      'B': LogicalKeyboardKey.keyB,
      'C': LogicalKeyboardKey.keyC,
      'D': LogicalKeyboardKey.keyD,
      'E': LogicalKeyboardKey.keyE,
      'F': LogicalKeyboardKey.keyF,
      'G': LogicalKeyboardKey.keyG,
      'H': LogicalKeyboardKey.keyH,
      'I': LogicalKeyboardKey.keyI,
      'J': LogicalKeyboardKey.keyJ,
      'K': LogicalKeyboardKey.keyK,
      'L': LogicalKeyboardKey.keyL,
      'M': LogicalKeyboardKey.keyM,
      'N': LogicalKeyboardKey.keyN,
      'O': LogicalKeyboardKey.keyO,
      'P': LogicalKeyboardKey.keyP,
      'Q': LogicalKeyboardKey.keyQ,
      'R': LogicalKeyboardKey.keyR,
      'S': LogicalKeyboardKey.keyS,
      'T': LogicalKeyboardKey.keyT,
      'U': LogicalKeyboardKey.keyU,
      'V': LogicalKeyboardKey.keyV,
      'W': LogicalKeyboardKey.keyW,
      'X': LogicalKeyboardKey.keyX,
      'Y': LogicalKeyboardKey.keyY,
      'Z': LogicalKeyboardKey.keyZ,
    };

const Map<String, LogicalKeyboardKey> _digitKeys = <String, LogicalKeyboardKey>{
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
};
