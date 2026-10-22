/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database
 * - File      : app_database.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Drift database root. Owns schema version 3, table registration,
 *               foreign-key enforcement, additive migrations, and the idempotent
 *               performance indexes used by the YMM catalog, exact OEM/SKU
 *               lookup, sync outbox, and audit paths. The generated file
 *               (app_database.g.dart) is produced by build_runner and
 *               intentionally excluded from linting.
 * </pre>
 */

import 'package:drift/drift.dart';

import 'tables/app_notifications_table.dart';
import 'tables/app_settings_table.dart';
import 'tables/audit_events_table.dart';
import 'tables/customers_table.dart';
import 'tables/invoice_lines_table.dart';
import 'tables/invoices_table.dart';
import 'tables/product_compatibility_table.dart';
import 'tables/products_table.dart';
import 'tables/roles_table.dart';
import 'tables/shift_closures_table.dart';
import 'tables/stock_ledger_table.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/uom_conversions_table.dart';
import 'tables/users_table.dart';
import 'tables/vehicles_table.dart';

part 'app_database.g.dart';

/// Offline ledger schema shared by the register, inventory, and account
/// modules.
///
/// Migration policy:
/// - Version 1 creates the original counter schema.
/// - Version 2 adds core/deposit separation, selling-unit conversions, the
///   settings registry, shift closures, sync outbox, and tamper-evident audit
///   events.
/// - Version 3 adds local RBAC (roles/users), the notification inbox, and
///   audit actor/action/before/after columns. All changes are additive so
///   existing invoices remain intact.
/// - Every open reapplies indexes with `IF NOT EXISTS`, so a partially
///   completed upgrade cannot leave a hot path unindexed.
/// - Never rely on destructive recreation: invoices and stock movements are
///   accounting records. Exported schema snapshots and upgrade tests live in
///   `drift_schemas/` and `test/data/schema_migration_test.dart`.
@DriftDatabase(
  tables: [
    Products,
    Vehicles,
    ProductCompatibility,
    StockLedger,
    Customers,
    Invoices,
    InvoiceLines,
    UomConversions,
    SyncOutbox,
    AppSettings,
    ShiftClosures,
    AuditEvents,
    Roles,
    Users,
    AppNotifications,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.addColumn(products, products.coreFeeCents);
        await migrator.addColumn(products, products.baseUnit);

        await migrator.addColumn(invoices, invoices.coreFeeTotalCents);

        await migrator.addColumn(invoiceLines, invoiceLines.uomFactor);
        await migrator.addColumn(invoiceLines, invoiceLines.uomLabel);
        await migrator.addColumn(invoiceLines, invoiceLines.coreFeeCents);

        await migrator.addColumn(stockLedger, stockLedger.referenceType);
        await migrator.addColumn(stockLedger, stockLedger.referenceId);

        await migrator.createTable(uomConversions);
        await migrator.createTable(syncOutbox);
        await migrator.createTable(appSettings);
        await migrator.createTable(shiftClosures);
        await migrator.createTable(auditEvents);
      }
      if (from < 3) {
        // A v1 upgrade already created `audit_events` from the current table
        // definition above, so actor columns exist there. Only a v2 database
        // needs them added.
        if (from >= 2) {
          await migrator.addColumn(auditEvents, auditEvents.action);
          await migrator.addColumn(auditEvents, auditEvents.actorUserId);
          await migrator.addColumn(auditEvents, auditEvents.actorName);
          await migrator.addColumn(auditEvents, auditEvents.beforeJson);
          await migrator.addColumn(auditEvents, auditEvents.afterJson);
        }
        await migrator.createTable(roles);
        await migrator.createTable(users);
        await migrator.createTable(appNotifications);
      }
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

      // Unit conversions are looked up by product and selling unit.
      'CREATE INDEX IF NOT EXISTS idx_uom_product_active '
          'ON uom_conversions(product_id) WHERE is_deleted = 0',

      // Sync worker claims due work without scanning acknowledged history.
      'CREATE INDEX IF NOT EXISTS idx_outbox_pending '
          'ON sync_outbox(is_acknowledged, next_attempt_at, occurred_at) '
          'WHERE is_acknowledged = 0',

      // Audit views are chronological and append-only.
      'CREATE INDEX IF NOT EXISTS idx_audit_events_time '
          'ON audit_events(occurred_at)',
      'CREATE INDEX IF NOT EXISTS idx_shift_closures_time '
          'ON shift_closures(closed_at)',

      // RBAC lookups and notification bell reads.
      'CREATE INDEX IF NOT EXISTS idx_users_role_active '
          'ON users(role_id, is_active) WHERE is_deleted = 0',
      'CREATE INDEX IF NOT EXISTS idx_notifications_unread '
          'ON app_notifications(is_read, created_at) WHERE is_read = 0',
      'CREATE INDEX IF NOT EXISTS idx_audit_actor_time '
          'ON audit_events(actor_user_id, occurred_at)',
    ];

    for (final statement in statements) {
      await customStatement(statement);
    }
  }
}
