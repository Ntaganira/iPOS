/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : users_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Local operator accounts for offline RBAC. PINs are never stored
 *               in clear text: only a per-user random salt, iteration count, and
 *               PBKDF2-HMAC-SHA256 digest are persisted. Accounts are local to
 *               the terminal; the back office distributes role definitions but
 *               never needs the PIN.
 * </pre>
 */

import 'package:drift/drift.dart';

import 'roles_table.dart';

/// Operator account with hashed PIN and role reference.
@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().withLength(min: 1, max: 120)();

  TextColumn get roleId =>
      text().references(Roles, #id, onDelete: KeyAction.restrict)();

  TextColumn get pinHash => text()();
  TextColumn get pinSalt => text()();
  IntColumn get pinIterations => integer().withDefault(const Constant(30000))();
  BoolColumn get mustChangePin =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
