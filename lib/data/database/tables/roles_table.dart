/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : roles_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Local role definitions for offline RBAC. Permissions are stored
 *               as a canonical JSON array of stable keys, so authorization does
 *               not depend on UI labels or translation strings. System roles
 *               cannot be deleted, keeping at least one administrator path
 *               available if sync is offline for an extended period.
 * </pre>
 */

import 'package:drift/drift.dart';

/// Named permission set assigned to local users.
@DataClassName('RoleRow')
class Roles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get permissionsJson => text()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
