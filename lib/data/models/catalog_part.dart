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
 *               without importing the database layer. Prices remain integer
 *               minor units through the entire UI and checkout path.
 * </pre>
 */

import 'package:flutter/foundation.dart';

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
  });

  final String id;
  final String sku;
  final String? oemNumber;
  final String partName;
  final String? brand;
  final int retailPriceCents;
  final int? tradePriceCents;
  final DateTime updatedAt;

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
}
