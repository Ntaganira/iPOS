/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : inventory_product.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Inventory-facing product projection with derived on-hand stock
 *               and selling-unit conversions. Kept separate from the register
 *               projection so stock counts, UOM edits, and soft-delete metadata
 *               never leak into the fast checkout path.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import 'catalog_part.dart';

/// Product row with stock and UOM context for inventory administration.
@immutable
class InventoryProduct {
  const InventoryProduct({
    required this.id,
    required this.sku,
    required this.partName,
    required this.retailPriceCents,
    required this.stockOnHand,
    required this.updatedAt,
    this.oemNumber,
    this.brand,
    this.tradePriceCents,
    this.coreFeeCents = 0,
    this.baseUnit = 'EA',
    this.uomOptions = const <UomOption>[],
  });

  final String id;
  final String sku;
  final String? oemNumber;
  final String partName;
  final String? brand;
  final int retailPriceCents;
  final int? tradePriceCents;
  final int coreFeeCents;
  final String baseUnit;
  final int stockOnHand;
  final DateTime updatedAt;
  final List<UomOption> uomOptions;

  bool get isLowStock => stockOnHand <= 3;
}

/// Validated input for creating or updating a product.
@immutable
class ProductDraft {
  const ProductDraft({
    required this.sku,
    required this.partName,
    required this.retailPriceCents,
    this.oemNumber,
    this.brand,
    this.tradePriceCents,
    this.coreFeeCents = 0,
    this.baseUnit = 'EA',
  });

  final String sku;
  final String partName;
  final String? oemNumber;
  final String? brand;
  final int retailPriceCents;
  final int? tradePriceCents;
  final int coreFeeCents;
  final String baseUnit;
}

/// One stock movement row for the inventory history view.
@immutable
class StockMovement {
  const StockMovement({
    required this.id,
    required this.qtyDelta,
    required this.binLocation,
    required this.referenceType,
    required this.occurredAt,
    this.referenceId,
  });

  final String id;
  final int qtyDelta;
  final String binLocation;
  final String referenceType;
  final String? referenceId;
  final DateTime occurredAt;
}
