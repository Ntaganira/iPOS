/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : cart_line.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Immutable active-cart line. The catalog projection is retained
 *               so invoice snapshots and stock movements can be written without
 *               re-reading mutable master data at payment time. Quantity is
 *               expressed in the selected selling unit; the UOM factor converts
 *               it to base stock units at commit time. Core/deposit amounts are
 *               calculated separately from merchandise and VAT.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import 'catalog_part.dart';

/// A product, selected selling unit, and pending quantity in the cart.
@immutable
class CartLine {
  const CartLine({required this.part, required this.quantity, UomOption? uom})
    : _uom = uom;

  final CatalogPart part;
  final int quantity;
  final UomOption? _uom;

  UomOption get uom => _uom ?? part.defaultSellingUnit;

  /// Pre-tax merchandise subtotal in minor units.
  int get lineSubtotalCents => part.retailPriceCents * quantity;

  /// Refundable core/deposit total for this line.
  int get coreFeeCents => part.coreFeeCents * quantity;

  /// Base units deducted from stock.
  int get stockQuantity => quantity * uom.factor;

  /// Returns a new line with a validated positive quantity and optional UOM.
  CartLine copyWith({int? quantity, UomOption? uom}) {
    final next = quantity ?? this.quantity;
    return CartLine(
      part: part,
      quantity: next < 1 ? 1 : next,
      uom: uom ?? this.uom,
    );
  }
}
