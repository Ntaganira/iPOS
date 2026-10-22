/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : shift_closures_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Immutable shift-close summary. Closing a shift freezes the
 *               day's invoice count and payment totals, then schedules WAL
 *               checkpointing and VACUUM maintenance outside the write
 *               transaction.
 * </pre>
 */

import 'package:drift/drift.dart';

/// One completed operator shift.
@DataClassName('ShiftClosureRow')
class ShiftClosures extends Table {
  TextColumn get id => text()();
  DateTimeColumn get closedAt => dateTime()();
  IntColumn get invoiceCount => integer()();
  IntColumn get grossCents => integer()();
  IntColumn get taxCents => integer()();
  IntColumn get coreFeeCents => integer()();
  TextColumn get paymentSummaryJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}
