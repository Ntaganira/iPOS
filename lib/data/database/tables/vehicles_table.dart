/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : vehicles_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Vehicle master used by the YMM (Year-Make-Model) register
 *               filters and by product compatibility joins. Sync metadata is
 *               included even though the minimum specification only listed the
 *               YMM fields, because vehicles are replicated master data and
 *               must participate in the same bidirectional reconciliation.
 * </pre>
 */

import 'package:drift/drift.dart';

/// Vehicle identity for fitment lookup. Engine code disambiguates trim and
/// engine variants that share a make/model/year triple.
@DataClassName('VehicleRow')
class Vehicles extends Table {
  TextColumn get id => text()();
  TextColumn get make => text().withLength(min: 1, max: 80)();
  TextColumn get model => text().withLength(min: 1, max: 120)();

  /// Four-digit model year, for example 2018.
  IntColumn get year => integer()();

  /// Engine family/designation such as `2TR-FE`; optional for generic fitment.
  TextColumn get engineCode => text().nullable()();

  /// UTC mutation time; mirrors the product sync contract.
  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
