/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.data.database.tables
 * - File      : product_compatibility_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Join table modeling "this part fits this vehicle". Compatibility
 *               is many-to-many and independently replicated, so it carries its
 *               own UUID, sync timestamp, and soft-delete tombstone rather than
 *               being baked into product rows. The (vehicle_id, product_id)
 *               index makes YMM-filtered catalog scans and exact fitment
 *               lookups cheap on local SQLCipher storage.
 * </pre>
 */

import 'package:drift/drift.dart';

import 'products_table.dart';
import 'vehicles_table.dart';

/// Fitment edge between a product and a vehicle.
@DataClassName('ProductCompatibilityRow')
class ProductCompatibility extends Table {
  TextColumn get id => text()();

  TextColumn get productId => text().references(
    Products,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get vehicleId => text().references(
    Vehicles,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// UTC mutation time used by the sync reconciler.
  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Fitment can be retired without deleting the catalog or vehicle record.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
