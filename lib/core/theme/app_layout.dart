/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.core.theme
 * - File      : app_layout.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Single source of truth for POS layout breakpoints, rail widths,
 *               panel widths, spacing, and radii. Keeping these constants out
 *               of widgets prevents drift between desktop, tablet, and drawer
 *               implementations and gives the responsive shell hard minimums.
 * </pre>
 */

import 'package:flutter/widgets.dart';

/// Responsive metrics for the three-column front-counter shell.
///
/// The layout policy is:
/// - >= 1100 logical pixels: persistent module rail (user may expand labels)
///   plus persistent center workspace plus persistent checkout panel.
/// - 1024..1099: compact persistent module rail, center workspace, persistent
///   checkout panel. Labels are available through the rail drawer.
/// - < 1024: compact module rail and full-width center workspace; checkout moves
///   to an end drawer so the catalog never gets squeezed into overflow.
abstract final class AppLayout {
  static const double sidebarExpandedWidth = 232;
  static const double sidebarCollapsedWidth = 64;
  static const double sidebarDrawerWidth = 248;

  static const double checkoutWidthWide = 380;
  static const double checkoutWidthCompact = 340;
  static const double checkoutDrawerMaxWidth = 380;

  /// Below this width the checkout panel becomes an end drawer.
  static const double inlineCheckoutBreakpoint = 1024;

  /// Below this width the module rail must remain icon-only to protect the
  /// catalog workspace. The label view remains available as a drawer.
  static const double expandedSidebarBreakpoint = 1100;

  /// Above this width the checkout panel can use its generous width.
  static const double wideCheckoutBreakpoint = 1360;

  static const double panelRadius = 14;
  static const double controlRadius = 10;
  static const double shellGap = 10;
  static const double panelPadding = 12;
  static const double sidebarItemHeight = 42;
  static const double catalogHeaderHeight = 34;
  static const double catalogRowHeight = 56;

  static const EdgeInsets shellPadding = EdgeInsets.all(10);
  static const EdgeInsets panelPaddingInsets = EdgeInsets.all(panelPadding);

  static const Duration layoutAnimation = Duration(milliseconds: 180);
  static const Duration contentAnimation = Duration(milliseconds: 140);
}
