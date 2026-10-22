/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : catalog_part.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Immutable read model returned by catalog and fitment queries.
 *               It is intentionally independent of Drift-generated row classes
 *               so the register UI can be tested, cached, and serialized
 *               without importing the database layer. Prices and core/deposit
 *               amounts remain integer minor units through the entire UI and
 *               checkout path. Selling-unit options are loaded with the part so
 *               a cashier can sell a single piece or a whole box without a
 *               second query at payment time.
 * </pre>
 */

import 'package:flutter/foundation.dart';

/// One selling unit derived from the UOM conversion matrix.
@immutable
class UomOption {
  const UomOption({required this.label, required this.factor});

  /// Label printed on the invoice (`EA`, `BOX`, `SET`, ...).
  final String label;

  /// Number of stock base units in one selling unit.
  final int factor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UomOption && other.label == label && other.factor == factor);

  @override
  int get hashCode => Object.hash(label, factor);
}

/// One sellable catalog row projected for the counter.
@immutable
class CatalogPart {
  const CatalogPart({
    required this.id,
    required this.sku,
    required this.partName,
    required this.retailPriceCents,
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
  final DateTime updatedAt;

  /// Conversion options excluding the implicit base unit.
  final List<UomOption> uomOptions;

  /// Every selectable selling unit, base unit first.
  List<UomOption> get sellingUnits => <UomOption>[
    UomOption(label: baseUnit, factor: 1),
    ...uomOptions.where((option) => option.label != baseUnit),
  ];

  UomOption get defaultSellingUnit => UomOption(label: baseUnit, factor: 1);

  /// Case-insensitive exact test used when a scanner or keyboard submission
  /// must resolve a single part without a second database round trip.
  bool matchesNumber(String term) {
    final normalized = term.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return sku.toLowerCase() == normalized ||
        (oemNumber?.toLowerCase() == normalized);
  }

  /// Secondary line for dense catalog cells.
  String get brandOrOem {
    final brandLabel = brand?.trim();
    if (brandLabel != null && brandLabel.isNotEmpty) {
      return brandLabel;
    }
    final oem = oemNumber?.trim();
    if (oem != null && oem.isNotEmpty) {
      return 'OEM $oem';
    }
    return 'No brand / OEM';
  }

  CatalogPart copyWith({List<UomOption>? uomOptions}) => CatalogPart(
    id: id,
    sku: sku,
    oemNumber: oemNumber,
    partName: partName,
    brand: brand,
    retailPriceCents: retailPriceCents,
    tradePriceCents: tradePriceCents,
    coreFeeCents: coreFeeCents,
    baseUnit: baseUnit,
    updatedAt: updatedAt,
    uomOptions: uomOptions ?? this.uomOptions,
  );
}
