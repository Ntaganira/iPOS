/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database
 * - File      : app_database.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Drift database root. Owns schema version 1, table registration,
 *               foreign-key enforcement, and the idempotent performance indexes
 *               used by the YMM catalog and exact OEM/SKU lookup paths. The
 *               generated file (app_database.g.dart) is produced by build_runner
 *               and intentionally excluded from linting.
 * </pre>
 */

import 'package:drift/drift.dart';

import 'tables/customers_table.dart';
import 'tables/invoice_lines_table.dart';
import 'tables/invoices_table.dart';
import 'tables/product_compatibility_table.dart';
import 'tables/products_table.dart';
import 'tables/stock_ledger_table.dart';
import 'tables/vehicles_table.dart';

part 'app_database.g.dart';

/// Offline ledger schema shared by the register, inventory, and account
/// modules.
///
/// Migration policy:
/// - Version 1 creates all tables, then applies indexes every open with
///   `IF NOT EXISTS`, so a partially completed upgrade cannot leave a hot path
///   unindexed.
/// - Future versions must add explicit `onUpgrade` steps and exported schema
///   tests. Never rely on destructive recreation: invoices and stock movements
///   are accounting records.
@DriftDatabase(
  tables: [
    Products,
    Vehicles,
    ProductCompatibility,
    StockLedger,
    Customers,
    Invoices,
    InvoiceLines,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite disables foreign keys per connection by default. The encrypted
      // factory also sets this, but keeping it here protects every executor
      // path, including tests and future read-pool connections.
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureIndexes();
    },
  );

  /// Hot-path indexes. Partial indexes on `is_deleted = 0` keep the register
  /// scans small while preserving tombstones for sync reconciliation.
  Future<void> _ensureIndexes() async {
    const statements = <String>[
      // Exact part lookup and catalog prefix scans.
      'CREATE INDEX IF NOT EXISTS idx_products_sku_active '
          'ON products(sku) WHERE is_deleted = 0',
      'CREATE INDEX IF NOT EXISTS idx_products_oem_active '
          'ON products(oem_number) WHERE is_deleted = 0',
      'CREATE INDEX IF NOT EXISTS idx_products_sync_pending '
          'ON products(is_synced) WHERE is_synced = 0',

      // Fitment traversal in both directions.
      'CREATE INDEX IF NOT EXISTS idx_compat_vehicle_active '
          'ON product_compatibility(vehicle_id, product_id) '
          'WHERE is_deleted = 0',
      'CREATE INDEX IF NOT EXISTS idx_compat_product_active '
          'ON product_compatibility(product_id) WHERE is_deleted = 0',

      // Cascading YMM filter lists.
      'CREATE INDEX IF NOT EXISTS idx_vehicles_ymm_active '
          'ON vehicles(make, model, year) WHERE is_deleted = 0',

      // Inventory history and pending-sync scans.
      'CREATE INDEX IF NOT EXISTS idx_stock_product_time '
          'ON stock_ledger(product_id, updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_stock_sync_pending '
          'ON stock_ledger(is_synced) WHERE is_synced = 0',

      // Register reporting and invoice drill-down.
      'CREATE INDEX IF NOT EXISTS idx_invoices_issued_at '
          'ON invoices(issued_at)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_customer '
          'ON invoices(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_sync_pending '
          'ON invoices(is_synced) WHERE is_synced = 0',
      'CREATE INDEX IF NOT EXISTS idx_invoice_lines_invoice '
          'ON invoice_lines(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoice_lines_sync_pending '
          'ON invoice_lines(is_synced) WHERE is_synced = 0',
    ];

    for (final statement in statements) {
      await customStatement(statement);
    }
  }
}
