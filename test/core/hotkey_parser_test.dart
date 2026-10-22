/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.core
 * - File      : hotkey_parser_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Verifies persisted hotkey labels map to safe shortcut
 *               activators and malformed labels fall back to null.
 * </pre>
 */

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/input/hotkey_parser.dart';

void main() {
  test('parses function keys case-insensitively', () {
    final f2 = parseHotkey(' f2 ') as SingleActivator?;
    final f12 = parseHotkey('F12') as SingleActivator?;
    expect(f2?.trigger, LogicalKeyboardKey.f2);
    expect(f12?.trigger, LogicalKeyboardKey.f12);
    expect(f2?.control, isFalse);
  });

  test('parses letters and digits', () {
    final letter = parseHotkey('s') as SingleActivator?;
    final digit = parseHotkey('7') as SingleActivator?;
    expect(letter?.trigger, LogicalKeyboardKey.keyS);
    expect(digit?.trigger, LogicalKeyboardKey.digit7);
  });

  test('rejects unsupported or malformed labels', () {
    expect(parseHotkey(''), isNull);
    expect(parseHotkey('F25'), isNull);
    expect(parseHotkey('FNaN'), isNull);
    expect(parseHotkey('Ctrl+S'), isNull);
    expect(parseHotkey('—'), isNull);
  });
}
