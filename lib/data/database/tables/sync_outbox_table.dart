/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : sync_outbox_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Durable transactional outbox for back-office replication.
 *               Business writes and their outbox row commit atomically, so a
 *               crash can never persist a sale without also scheduling its
 *               upload. Failed uploads stay pending with retry backoff and are
 *               never silently discarded.
 * </pre>
 */

import 'package:drift/drift.dart';

/// Pending unit of replication consumed by the sync worker.
@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text().withLength(min: 1, max: 48)();
  TextColumn get entityId => text()();

  /// `upsert` or `delete`.
  TextColumn get operation => text().withLength(min: 1, max: 16)();

  /// Canonical JSON payload. Secrets and raw database keys are never included.
  TextColumn get payloadJson => text()();

  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  BoolColumn get isAcknowledged =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
