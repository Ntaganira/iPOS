/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : app_notifications_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Local operator notification inbox. Notifications are generated
 *               from business events (low stock, sync failures, shift close,
 *               backup/export, security) and can be read or dismissed offline.
 *               `dedupe_key` prevents repeated low-stock or sync alerts from
 *               flooding the bell while the condition persists.
 * </pre>
 */

import 'package:drift/drift.dart';

/// In-app notification entry.
@DataClassName('AppNotificationRow')
class AppNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text().withLength(min: 1, max: 48)();
  TextColumn get severity => text().withDefault(const Constant('info'))();
  TextColumn get title => text()();
  TextColumn get message => text()();
  TextColumn get entityType => text().nullable()();
  TextColumn get entityId => text().nullable()();
  TextColumn get dedupeKey => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get readAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
