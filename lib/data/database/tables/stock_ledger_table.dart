/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : stock_ledger_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Append-only inventory movement ledger. There is deliberately no
 *               is_deleted flag: corrections are new compensating rows, never
 *               destructive edits. Every counter sale writes a negative
 *               qty_delta atomically with its invoice; stock receiving and
 *               stock counts will append positive/adjustment rows through the
 *               same sync envelope.
 * </pre>
 */

import 'package:drift/drift.dart';

import 'products_table.dart';

/// Immutable stock movement. On-hand quantity is derived by summing deltas.
@DataClassName('StockLedgerRow')
class StockLedger extends Table {
  TextColumn get id => text()();

  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();

  /// Physical bin/shelf. Counter sales use `FRONT`; stock receipts carry
  /// their actual bin assignment.
  TextColumn get binLocation => text().withLength(min: 1, max: 64)();

  /// Signed movement in product base units: positive for receipts/returns,
  /// negative for sales.
  IntColumn get qtyDelta => integer()();

  /// Business document that caused this movement (`sale`, `receipt`,
  /// `adjustment`, `import`).
  TextColumn get referenceType => text().withDefault(const Constant('sale'))();

  /// Invoice, receipt, count, or import id, when one exists.
  TextColumn get referenceId => text().nullable()();

  /// UTC mutation time for delta-based synchronization.
  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
