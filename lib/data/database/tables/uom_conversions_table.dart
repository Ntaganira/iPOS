/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : uom_conversions_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Unit-of-measure conversion matrix. Stock is held in the
 *               product's base unit, while a sale may use a larger or smaller
 *               selling unit. The factor is an exact integer so split-pack
 *               deductions never introduce floating-point rounding.
 * </pre>
 */

import 'package:drift/drift.dart';

import 'products_table.dart';

/// One directed conversion edge, for example `BOX -> EA` with factor 12.
@DataClassName('UomConversionRow')
class UomConversions extends Table {
  TextColumn get id => text()();

  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();

  TextColumn get fromUnit => text().withLength(min: 1, max: 16)();
  TextColumn get toUnit => text().withLength(min: 1, max: 16)();

  /// Number of [toUnit] units contained in one [fromUnit].
  IntColumn get factor => integer()();

  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {productId, fromUnit, toUnit},
  ];
}
