/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.data.database.tables
 * - File      : customers_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline customer account directory backing the checkout account
 *               selector. Accounts carry a cached balance and the same sync
 *               envelope as other replicated master data. Walk-in sales remain
 *               valid because invoice.customer_id is nullable.
 * </pre>
 */

import 'package:drift/drift.dart';

/// Customer/trade-account master for counter checkout.
@DataClassName('CustomerRow')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get taxId => text().nullable()();

  /// Cached receivable balance in minor units. The back office remains the
  /// accounting source of truth; this value is for offline counter context.
  IntColumn get balanceCents => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
