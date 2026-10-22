/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : cart_line.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Immutable active-cart line. The catalog projection is retained
 *               so invoice snapshots and stock movements can be written without
 *               re-reading mutable master data at payment time. Quantity is the
 *               only mutable dimension and is replaced via copyWith to keep
 *               controller notifications deterministic.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import 'catalog_part.dart';

/// A product and its pending quantity in the register cart.
@immutable
class CartLine {
  const CartLine({required this.part, required this.quantity});

  final CatalogPart part;
  final int quantity;

  /// Pre-tax line subtotal in minor units.
  int get lineSubtotalCents => part.retailPriceCents * quantity;

  /// Returns a new line with a validated positive quantity.
  CartLine copyWith({int? quantity}) {
    final next = quantity ?? this.quantity;
    return CartLine(part: part, quantity: next < 1 ? 1 : next);
  }
}
