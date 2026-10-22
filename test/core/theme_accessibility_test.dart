/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.core
 * - File      : theme_accessibility_test.dart
 * - Date      : 2026. 10. 23.
 * - User      : NTAGANIRA H.
 * - Desc      : WCAG contrast audit for the light and dark POS palettes. Text
 *               role pairs must reach AA (4.5:1) and control outlines must
 *               reach the 3:1 non-text threshold, so prices, validation errors,
 *               and focus affordances remain legible on shop hardware.
 * </pre>
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/theme/app_theme.dart';

double _channel(int value) {
  final channel = value / 255;
  return channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color color) {
  return 0.2126 * _channel((color.r * 255).round()) +
      0.7152 * _channel((color.g * 255).round()) +
      0.0722 * _channel((color.b * 255).round());
}

double _contrast(Color foreground, Color background) {
  final lighter = math.max(_luminance(foreground), _luminance(background));
  final darker = math.min(_luminance(foreground), _luminance(background));
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('POS palettes meet WCAG AA', () {
    for (final entry in <String, ThemeData>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      final scheme = entry.value.colorScheme;

      final textPairs = <String, (Color, Color)>{
        'onSurface / surface': (scheme.onSurface, scheme.surface),
        'onSurfaceVariant / surface': (scheme.onSurfaceVariant, scheme.surface),
        'primary / surface': (scheme.primary, scheme.surface),
        'onPrimary / primary': (scheme.onPrimary, scheme.primary),
        'onSecondary / secondary': (scheme.onSecondary, scheme.secondary),
        'onPrimaryContainer / primaryContainer': (
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        ),
        'onSecondaryContainer / secondaryContainer': (
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
        ),
        'onError / error': (scheme.onError, scheme.error),
        'onErrorContainer / errorContainer': (
          scheme.onErrorContainer,
          scheme.errorContainer,
        ),
        'onInverseSurface / inverseSurface': (
          scheme.onInverseSurface,
          scheme.inverseSurface,
        ),
      };

      for (final pair in textPairs.entries) {
        test('${entry.key}: ${pair.key}', () {
          expect(
            _contrast(pair.value.$1, pair.value.$2),
            greaterThanOrEqualTo(4.5),
            reason: '${pair.key} must reach 4.5:1 in ${entry.key} mode',
          );
        });
      }

      test('${entry.key}: control outline reaches 3:1', () {
        expect(
          _contrast(scheme.outline, scheme.surface),
          greaterThanOrEqualTo(3),
        );
      });
    }
  });
}
