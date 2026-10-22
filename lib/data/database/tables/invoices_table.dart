/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : invoices_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline counter invoice header. Captures the immutable sale
 *               totals, tax basis points, payment method, and sync envelope.
 *               The invoice, its lines, and its stock-ledger movements are
 *               committed in one transaction so an interrupted checkout cannot
 *               leave partially paid inventory.
 * </pre>
 */

import 'package:drift/drift.dart';

import 'customers_table.dart';

/// Transactional sale header produced entirely on-device.
@DataClassName('InvoiceRow')
class Invoices extends Table {
  TextColumn get id => text()();

  /// Human-readable, unique per installation/day, for example
  /// `INV-20261022-00041`. Generated inside the checkout transaction.
  TextColumn get invoiceNumber => text().unique()();

  /// Nullable to support anonymous walk-in sales.
  TextColumn get customerId => text().nullable().references(
    Customers,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Pre-tax merchandise total in minor units.
  IntColumn get subtotalCents => integer()();

  /// Tax total in minor units, rounded once at invoice level.
  IntColumn get taxCents => integer()();

  /// Header-level discount in minor units; zero for the initial register.
  IntColumn get discountCents => integer().withDefault(const Constant(0))();

  /// Final amount due: subtotal - discount + tax.
  IntColumn get totalCents => integer()();

  /// VAT rate snapshot in basis points (1800 == 18.00%).
  IntColumn get taxRateBps => integer().withDefault(const Constant(1800))();

  /// Cash, card, or mobile-money token, matching payment triggers in the UI.
  TextColumn get paymentMethod => text().withLength(min: 1, max: 32)();

  /// completed | voided. Voiding is a compensating workflow, not a delete.
  TextColumn get status => text().withDefault(const Constant('completed'))();

  /// Business timestamp (UTC) and optimistic sync timestamp.
  DateTimeColumn get issuedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
