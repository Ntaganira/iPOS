/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.data.models
 * - File      : customer_option.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Lightweight customer account projection for the checkout
 *               selector. Equality is keyed by the stable UUID so dropdown
 *               state survives list refreshes without depending on object
 *               identity. Walk-in sales are represented by a null selection.
 * </pre>
 */

import 'package:flutter/foundation.dart';

/// Customer account displayed in the right-hand checkout panel.
@immutable
class CustomerOption {
  const CustomerOption({
    required this.id,
    required this.displayName,
    this.phone,
  });

  final String id;
  final String displayName;
  final String? phone;

  String get secondaryLabel {
    final normalized = phone?.trim();
    return normalized == null || normalized.isEmpty ? 'Account' : normalized;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CustomerOption && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
