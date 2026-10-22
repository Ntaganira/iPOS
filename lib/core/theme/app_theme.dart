/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.theme
 * - File      : app_theme.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Global Material 3 design system for the offline POS. Defines a
 *               native light palette and a high-contrast, low-strain dark
 *               palette for dim counters and retail environments, plus
 *               compact density, focus, input, and button styling shared by
 *               every module. All surfaces are driven through Theme.of so a
 *               runtime theme switch requires no screen rebuild logic.
 * </pre>
 */

import 'package:flutter/material.dart';

/// Centralized theme factory for the iPOS client.
///
/// The dark palette intentionally avoids pure black and pure white: it reduces
/// halation on glossy shop counters and keeps long shifts comfortable while
/// preserving WCAG-friendly contrast for prices, labels, and destructive
/// actions. Both themes share the same component metrics so switching modes
/// never changes layout dimensions.
abstract final class AppTheme {
  static const Color _brandTeal = Color(0xFF00796B);

  /// Native light mode used in bright showrooms and back-office desks.
  static ThemeData get light => _build(Brightness.light);

  /// High-contrast terminal mode for dark shops, night shifts, and tablets
  /// mounted at the counter.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _schemeFor(brightness);

    final baseText = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    ).textTheme;

    final textTheme = baseText.copyWith(
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 14, height: 1.35),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 13, height: 1.35),
      bodySmall: baseText.bodySmall?.copyWith(fontSize: 12, height: 1.3),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    final fieldFocusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.primary, width: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textTheme: textTheme,
      focusColor: scheme.primary.withValues(alpha: 0.12),
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 20),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: scheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldFocusedBorder,
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: fieldFocusedBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelMedium,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double?>(8),
        radius: const Radius.circular(8),
        crossAxisMargin: 2,
        thumbColor: WidgetStatePropertyAll<Color?>(
          scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.5 : 0.35),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 3,
      ),
    );
  }

  /// Builds the palette. Explicit surface-container roles are supplied because
  /// seeded schemes do not always produce enough separation for dense panels in
  /// dark mode, especially on low-brightness POS displays.
  static ColorScheme _schemeFor(Brightness brightness) {
    final seeded = ColorScheme.fromSeed(
      seedColor: _brandTeal,
      brightness: brightness,
    );

    if (brightness == Brightness.dark) {
      return seeded.copyWith(
        primary: const Color(0xFF5FE0C8),
        onPrimary: const Color(0xFF002019),
        primaryContainer: const Color(0xFF123F37),
        onPrimaryContainer: const Color(0xFFB6F4E7),
        secondary: const Color(0xFFFFC857),
        onSecondary: const Color(0xFF2B1F00),
        secondaryContainer: const Color(0xFF4A3A12),
        onSecondaryContainer: const Color(0xFFFFE8B0),
        surface: const Color(0xFF0B1014),
        onSurface: const Color(0xFFE9F0F6),
        onSurfaceVariant: const Color(0xFFB6C2CE),
        surfaceContainerLowest: const Color(0xFF070B0E),
        surfaceContainerLow: const Color(0xFF10171D),
        surfaceContainer: const Color(0xFF141C23),
        surfaceContainerHigh: const Color(0xFF1A242D),
        surfaceContainerHighest: const Color(0xFF202C36),
        outline: const Color(0xFF8492A0),
        outlineVariant: const Color(0xFF2A3742),
        surfaceTint: Colors.transparent,
        error: const Color(0xFFFF8A80),
        onError: const Color(0xFF3A0000),
        errorContainer: const Color(0xFF5C190F),
        onErrorContainer: const Color(0xFFFFDAD4),
        inverseSurface: const Color(0xFFE2E9EF),
        onInverseSurface: const Color(0xFF172026),
        inversePrimary: const Color(0xFF006B5B),
      );
    }

    return seeded.copyWith(
      primary: const Color(0xFF006B5B),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFA7F2E3),
      onPrimaryContainer: const Color(0xFF00201A),
      secondary: const Color(0xFF7A5900),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFDF9B),
      onSecondaryContainer: const Color(0xFF261A00),
      surface: const Color(0xFFF7F9FA),
      onSurface: const Color(0xFF111A20),
      onSurfaceVariant: const Color(0xFF46525C),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF0F3F5),
      surfaceContainerHigh: const Color(0xFFE8EDF0),
      surfaceContainerHighest: const Color(0xFFDFE5E9),
      outline: const Color(0xFF6E7B86),
      outlineVariant: const Color(0xFFD2DBE1),
      surfaceTint: Colors.transparent,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      inverseSurface: const Color(0xFF253038),
      onInverseSurface: const Color(0xFFF0F4F7),
      inversePrimary: const Color(0xFF5FE0C8),
    );
  }
}
