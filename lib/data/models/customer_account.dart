/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : customer_account.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Customer directory projection for administration and checkout.
 *               The cached receivable balance is for offline counter context;
 *               the back office remains the accounting source of truth.
 * </pre>
 */

import 'package:flutter/foundation.dart';

/// Editable customer/trade account.
@immutable
class CustomerAccount {
  const CustomerAccount({
    required this.id,
    required this.displayName,
    required this.balanceCents,
    required this.updatedAt,
    this.phone,
    this.taxId,
  });

  final String id;
  final String displayName;
  final String? phone;
  final String? taxId;
  final int balanceCents;
  final DateTime updatedAt;
}

/// Validated customer input.
@immutable
class CustomerDraft {
  const CustomerDraft({
    required this.displayName,
    this.phone,
    this.taxId,
    this.balanceCents = 0,
  });

  final String displayName;
  final String? phone;
  final String? taxId;
  final int balanceCents;
}
