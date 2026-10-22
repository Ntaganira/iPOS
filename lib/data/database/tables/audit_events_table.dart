/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : audit_events_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Append-only local audit trail. Every row records who acted,
 *               what action occurred, the before/after state when something was
 *               edited, and the SHA-256 hash of the previous row plus its own
 *               canonical payload. The result is a tamper-evident chain for
 *               checkout, inventory, customer, user, security, sync, and
 *               maintenance events without storing PINs or customer secrets.
 * </pre>
 */

import 'package:drift/drift.dart';

/// Tamper-evident operational event.
@DataClassName('AuditEventRow')
class AuditEvents extends Table {
  TextColumn get id => text()();
  TextColumn get eventType => text().withLength(min: 1, max: 64)();

  /// Stable machine token such as create, update, delete, login, export.
  TextColumn get action => text().withDefault(const Constant('system'))();

  /// Operator who performed the action. Null for automatic maintenance.
  TextColumn get actorUserId => text().nullable()();
  TextColumn get actorName => text().nullable()();

  TextColumn get entityType => text().nullable()();
  TextColumn get entityId => text().nullable()();
  TextColumn get message => text()();
  TextColumn get payloadJson => text().nullable()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  TextColumn get previousHash => text().nullable()();
  TextColumn get eventHash => text()();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
