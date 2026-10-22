/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : invoice_lines_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Immutable sale line snapshot. SKU, description, brand, unit
 *               price, tax rate, and totals are copied at checkout so later
 *               catalog edits, renames, or soft deletes can never rewrite
 *               historical receipts or accounting exports. Product id is
 *               nullable for traceability after a hard purge; the snapshot
 *               remains the legal record.
 * </pre>
 */

import 'package:drift/drift.dart';

import 'invoices_table.dart';
import 'products_table.dart';

/// One product/quantity line on a counter invoice.
@DataClassName('InvoiceLineRow')
class InvoiceLines extends Table {
  TextColumn get id => text()();

  TextColumn get invoiceId =>
      text().references(Invoices, #id, onDelete: KeyAction.cascade)();

  /// Optional live reference; all printable data is snapshotted below.
  TextColumn get productId => text().nullable().references(
    Products,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get skuSnapshot => text()();
  TextColumn get partNameSnapshot => text()();
  TextColumn get brandSnapshot => text().nullable()();

  /// Unit price at the instant of sale, in minor units.
  IntColumn get unitPriceCents => integer()();

  /// Positive quantity sold in [uomLabel] units.
  IntColumn get quantity => integer()();

  /// Multiplier converting one selling unit into stock base units. A single
  /// part sold out of a 12-piece box uses factor 1 when the base unit is `EA`;
  /// a whole-box sale uses 12.
  IntColumn get uomFactor => integer().withDefault(const Constant(1))();

  /// Selling-unit label snapshot (`EA`, `BOX`, ...).
  TextColumn get uomLabel => text().withDefault(const Constant('EA'))();

  /// Refundable core/deposit amount per selling unit, in minor units.
  IntColumn get coreFeeCents => integer().withDefault(const Constant(0))();

  /// Per-line discount in minor units; zero for the initial register.
  IntColumn get lineDiscountCents => integer().withDefault(const Constant(0))();

  /// Tax rate snapshot for this line, in basis points.
  IntColumn get taxRateBps => integer().withDefault(const Constant(1800))();

  /// Pre-tax line subtotal after line discount, in minor units. Core fees are
  /// stored separately and are not part of this merchandise total.
  IntColumn get lineTotalCents => integer()();

  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
