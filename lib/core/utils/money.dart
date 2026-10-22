/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.utils
 * - File      : money.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Precision-safe money helpers. All persisted monetary values are
 *               integer minor units (for example, cents) so invoice arithmetic
 *               never depends on binary floating point. Formatting and VAT
 *               rounding are centralized here so the register, receipts, and
 *               future back-office exports agree to the last unit.
 * </pre>
 */

import 'package:intl/intl.dart';

/// Money formatting and integer tax arithmetic shared across the POS.
abstract final class Money {
  /// Rwandan franc presentation for the initial deployment. The symbol is kept
  /// here rather than scattered through widgets so a jurisdiction/currency
  /// profile can replace it without touching the checkout UI.
  static final NumberFormat _currency = NumberFormat.currency(
    symbol: 'RWF ',
    decimalDigits: 2,
  );

  /// Formats an integer minor-unit amount (cents) for display.
  ///
  /// Storage remains integral; only this presentation boundary converts to a
  /// floating-point value, and only for the formatter.
  static String formatCents(int cents) => _currency.format(cents / 100);

  /// Computes VAT from a pre-tax subtotal using basis points.
  ///
  /// Example: 1800 basis points == 18.00% VAT. The add-half-then-divide form
  /// rounds half up using integers, avoiding `double.round()` surprises on
  /// large offline invoice totals.
  static int taxCents({required int subtotalCents, required int rateBps}) {
    assert(subtotalCents >= 0, 'Subtotal must not be negative.');
    assert(rateBps >= 0, 'Tax rate must not be negative.');
    return (subtotalCents * rateBps + 5000) ~/ 10000;
  }

  /// Human-readable basis-point label, for example `18.0%`.
  static String percentLabel(int rateBps) =>
      '${(rateBps / 100).toStringAsFixed(1)}%';
}
