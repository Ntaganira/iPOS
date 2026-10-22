/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : auth_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline RBAC persistence and authentication. Seeds immutable
 *               system roles and a first-run administrator, verifies salted
 *               PBKDF2 PINs, prevents removal of the last administrator, and
 *               audits login, logout, user, role, and PIN events with actor
 *               context but never the PIN itself.
 * </pre>
 */

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/security/permissions.dart';
import '../../core/security/pin_hasher.dart';
import '../database/app_database.dart';
import '../models/app_user.dart';
import 'audit_repository.dart';

/// First-run administrator credentials. The UI forces a PIN change immediately.
class BootstrapResult {
  const BootstrapResult({
    required this.createdAdministrator,
    required this.defaultPin,
  });

  final bool createdAdministrator;
  final String? defaultPin;
}

/// Authentication and user administration gateway.
class AuthRepository {
  AuthRepository(this._database, {AuditActor? Function()? actorProvider})
    : _audit = AuditRepository(_database, actorProvider: actorProvider),
      _uuid = Uuid();

  static const String defaultAdminId = 'user-admin';
  static const String defaultAdminPin = '1234';

  final AppDatabase _database;
  final AuditRepository _audit;
  final Uuid _uuid;

  /// Creates the system roles and, when no user exists, the first admin.
  Future<BootstrapResult> ensureBootstrap() async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _upsertRole(
        id: SystemRoles.adminId,
        name: 'Administrator',
        permissions: SystemRoles.adminPermissions,
        now: now,
      );
      await _upsertRole(
        id: SystemRoles.managerId,
        name: 'Manager',
        permissions: SystemRoles.managerPermissions,
        now: now,
      );
      await _upsertRole(
        id: SystemRoles.cashierId,
        name: 'Cashier',
        permissions: SystemRoles.cashierPermissions,
        now: now,
      );
    });

    final existing = await _database
        .customSelect(
          'SELECT COUNT(*) AS user_count FROM users WHERE is_deleted = 0',
        )
        .getSingle();
    if (existing.read<int>('user_count') > 0) {
      return const BootstrapResult(
        createdAdministrator: false,
        defaultPin: null,
      );
    }

    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(defaultAdminPin, salt, PinHasher.iterations);
    await _database
        .into(_database.users)
        .insert(
          UsersCompanion.insert(
            id: defaultAdminId,
            displayName: 'Administrator',
            roleId: SystemRoles.adminId,
            pinHash: hash,
            pinSalt: salt,
            pinIterations: const Value(PinHasher.iterations),
            mustChangePin: const Value(true),
            updatedAt: now,
          ),
        );
    await _audit.append(
      eventType: 'auth.bootstrap',
      action: 'create',
      actor: AuditActor.system,
      entityType: 'user',
      entityId: defaultAdminId,
      message: 'First-run administrator created.',
      after: <String, Object?>{
        'id': defaultAdminId,
        'role': 'Administrator',
        'must_change_pin': true,
      },
    );
    return const BootstrapResult(
      createdAdministrator: true,
      defaultPin: defaultAdminPin,
    );
  }

  Future<List<AppUser>> listActiveUsers() async {
    final rows = await _userQuery(
      where: 'u.is_active = 1 AND u.is_deleted = 0',
    );
    return rows.map(_mapUser).toList(growable: false);
  }

  Future<List<AppUser>> listAllUsers() async {
    final rows = await _userQuery(where: 'u.is_deleted = 0');
    return rows.map(_mapUser).toList(growable: false);
  }

  Future<List<RoleOption>> listRoles() async {
    final rows = await _database.customSelect('''
            SELECT id, name, permissions_json, is_system
            FROM roles
            WHERE is_deleted = 0
            ORDER BY is_system DESC, name COLLATE NOCASE
          ''').get();
    return rows
        .map(
          (row) => RoleOption(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            permissions: _decodePermissions(
              row.read<String>('permissions_json'),
            ),
            isSystem: row.read<int>('is_system') != 0,
          ),
        )
        .toList(growable: false);
  }

  /// Verifies the PIN and records both successful and failed attempts.
  Future<AppUser?> authenticate({
    required String userId,
    required String pin,
  }) async {
    final rows = await _userQuery(
      where: 'u.id = ?',
      variables: [Variable.withString(userId)],
    );
    if (rows.isEmpty) {
      await _audit.append(
        eventType: 'auth.login_failed',
        action: 'login.failed',
        actor: const AuditActor(userId: 'unknown', name: 'Unknown'),
        entityType: 'user',
        entityId: userId,
        message: 'Sign-in attempted for an unknown account.',
        payload: const <String, Object?>{'reason': 'unknown_account'},
      );
      return null;
    }

    final row = rows.single;
    final user = _mapUser(row);
    final active = row.read<int>('is_active') != 0;
    final hash = row.read<String>('pin_hash');
    final salt = row.read<String>('pin_salt');
    final rounds = row.read<int>('pin_iterations');

    if (!active ||
        !PinHasher.verify(
          pin: pin,
          saltHex: salt,
          rounds: rounds,
          expectedHash: hash,
        )) {
      await _audit.append(
        eventType: 'auth.login_failed',
        action: 'login.failed',
        actor: AuditActor(userId: user.id, name: user.displayName),
        entityType: 'user',
        entityId: user.id,
        message: 'Failed sign-in for ${user.displayName}.',
        payload: <String, Object?>{'reason': 'invalid_credentials'},
      );
      return null;
    }

    await _database.customStatement(
      'UPDATE users SET last_login_at = ? WHERE id = ?',
      [DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000, user.id],
    );
    await _audit.append(
      eventType: 'auth.login',
      action: 'login',
      actor: AuditActor(userId: user.id, name: user.displayName),
      entityType: 'user',
      entityId: user.id,
      message: '${user.displayName} signed in.',
      payload: <String, Object?>{'role': user.roleName},
    );
    return user;
  }

  Future<void> recordLogout(AppUser user) async {
    await _audit.append(
      eventType: 'auth.logout',
      action: 'logout',
      actor: AuditActor(userId: user.id, name: user.displayName),
      entityType: 'user',
      entityId: user.id,
      message: '${user.displayName} signed out.',
    );
  }

  Future<void> changePin({
    required String userId,
    required String currentPin,
    required String newPin,
  }) async {
    _validatePin(newPin);
    final row = await (_database.select(
      _database.users,
    )..where((table) => table.id.equals(userId))).getSingleOrNull();
    if (row == null) {
      throw StateError('User not found.');
    }
    final valid = PinHasher.verify(
      pin: currentPin,
      saltHex: row.pinSalt,
      rounds: row.pinIterations,
      expectedHash: row.pinHash,
    );
    if (!valid) {
      throw StateError('The current PIN is incorrect.');
    }

    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(newPin, salt, PinHasher.iterations);
    await _database.transaction(() async {
      await (_database.update(
        _database.users,
      )..where((table) => table.id.equals(userId))).write(
        UsersCompanion(
          pinHash: Value(hash),
          pinSalt: Value(salt),
          pinIterations: const Value(PinHasher.iterations),
          mustChangePin: const Value(false),
          updatedAt: Value(DateTime.now().toUtc()),
          isSynced: const Value(false),
        ),
      );
      await _audit.append(
        eventType: 'auth.pin_changed',
        action: 'update',
        entityType: 'user',
        entityId: userId,
        message: '${row.displayName} changed their PIN.',
        before: <String, Object?>{'must_change_pin': row.mustChangePin},
        after: <String, Object?>{'must_change_pin': false},
        payload: const <String, Object?>{'pin_changed': true},
      );
    });
  }

  Future<String> createUser({
    required String displayName,
    required String roleId,
    required String pin,
  }) async {
    _validatePin(pin);
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Name is required.',
      );
    }
    final role = await _role(roleId);
    if (role == null) {
      throw StateError('Role not found.');
    }
    final id = _uuid.v4();
    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(pin, salt, PinHasher.iterations);
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await _database
          .into(_database.users)
          .insert(
            UsersCompanion.insert(
              id: id,
              displayName: name,
              roleId: roleId,
              pinHash: hash,
              pinSalt: salt,
              pinIterations: const Value(PinHasher.iterations),
              mustChangePin: const Value(true),
              updatedAt: now,
            ),
          );
      await _audit.append(
        eventType: 'rbac.user_created',
        action: 'create',
        entityType: 'user',
        entityId: id,
        message: 'User $name created with role ${role.name}.',
        after: <String, Object?>{
          'display_name': name,
          'role': role.name,
          'must_change_pin': true,
        },
      );
    });
    return id;
  }

  Future<void> updateUser({
    required String userId,
    required String displayName,
    required String roleId,
    required bool isActive,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Name is required.',
      );
    }
    final role = await _role(roleId);
    if (role == null) {
      throw StateError('Role not found.');
    }
    final existingRows = await _userQuery(
      where: 'u.id = ?',
      variables: [Variable.withString(userId)],
    );
    if (existingRows.isEmpty) {
      throw StateError('User not found.');
    }
    final existing = _mapUser(existingRows.single);

    if (existing.can(AppPermission.manageUsers) && !isActive) {
      final remaining = await _database.customSelect('''
              SELECT COUNT(*) AS admin_count
              FROM users u
              INNER JOIN roles r ON r.id = u.role_id
              WHERE u.is_active = 1
                AND u.is_deleted = 0
                AND r.permissions_json LIKE '%users.manage%'
            ''').getSingle();
      if (remaining.read<int>('admin_count') <= 1) {
        throw StateError('The last active administrator cannot be disabled.');
      }
    }

    await _database.transaction(() async {
      await (_database.update(
        _database.users,
      )..where((table) => table.id.equals(userId))).write(
        UsersCompanion(
          displayName: Value(name),
          roleId: Value(roleId),
          isActive: Value(isActive),
          updatedAt: Value(DateTime.now().toUtc()),
          isSynced: const Value(false),
        ),
      );
      await _audit.append(
        eventType: 'rbac.user_updated',
        action: 'update',
        entityType: 'user',
        entityId: userId,
        message: 'User ${existing.displayName} updated.',
        before: <String, Object?>{
          'display_name': existing.displayName,
          'role': existing.roleName,
          'is_active': existingRows.single.read<int>('is_active') != 0,
        },
        after: <String, Object?>{
          'display_name': name,
          'role': role.name,
          'is_active': isActive,
        },
      );
    });
  }

  Future<void> resetPin({
    required String userId,
    required String newPin,
  }) async {
    _validatePin(newPin);
    final userRows = await _userQuery(
      where: 'u.id = ?',
      variables: [Variable.withString(userId)],
    );
    if (userRows.isEmpty) {
      throw StateError('User not found.');
    }
    final user = _mapUser(userRows.single);
    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(newPin, salt, PinHasher.iterations);

    await _database.transaction(() async {
      await (_database.update(
        _database.users,
      )..where((table) => table.id.equals(userId))).write(
        UsersCompanion(
          pinHash: Value(hash),
          pinSalt: Value(salt),
          pinIterations: const Value(PinHasher.iterations),
          mustChangePin: const Value(true),
          updatedAt: Value(DateTime.now().toUtc()),
          isSynced: const Value(false),
        ),
      );
      await _audit.append(
        eventType: 'rbac.pin_reset',
        action: 'update',
        entityType: 'user',
        entityId: userId,
        message: 'PIN reset for ${user.displayName}.',
        before: <String, Object?>{'must_change_pin': user.mustChangePin},
        after: <String, Object?>{'must_change_pin': true},
      );
    });
  }

  Future<void> _upsertRole({
    required String id,
    required String name,
    required List<AppPermission> permissions,
    required DateTime now,
  }) async {
    final permissionsJson = jsonEncode(
      permissions.map((permission) => permission.key).toList(growable: false),
    );
    await _database
        .into(_database.roles)
        .insertOnConflictUpdate(
          RolesCompanion.insert(
            id: id,
            name: name,
            permissionsJson: permissionsJson,
            isSystem: const Value(true),
            updatedAt: now,
          ),
        );
  }

  Future<List<QueryRow>> _userQuery({
    required String where,
    List<Variable<Object>> variables = const <Variable<Object>>[],
  }) {
    return _database.customSelect('''
        SELECT u.id, u.display_name, u.role_id, u.pin_hash, u.pin_salt,
               u.pin_iterations, u.must_change_pin, u.is_active,
               u.last_login_at, u.is_deleted,
               r.name AS role_name, r.permissions_json
        FROM users u
        INNER JOIN roles r ON r.id = u.role_id
        WHERE $where
        ORDER BY u.display_name COLLATE NOCASE
      ''', variables: variables).get();
  }

  AppUser _mapUser(QueryRow row) {
    final lastLoginSeconds = row.readNullable<int>('last_login_at');
    return AppUser(
      id: row.read<String>('id'),
      displayName: row.read<String>('display_name'),
      roleId: row.read<String>('role_id'),
      roleName: row.read<String>('role_name'),
      permissions: _decodePermissions(row.read<String>('permissions_json')),
      mustChangePin: row.read<int>('must_change_pin') != 0,
      isActive: row.read<int>('is_active') != 0,
      lastLoginAt: lastLoginSeconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              lastLoginSeconds * 1000,
              isUtc: true,
            ),
    );
  }

  Set<AppPermission> _decodePermissions(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) {
      return const <AppPermission>{};
    }
    return decoded
        .whereType<String>()
        .map(AppPermission.fromKey)
        .whereType<AppPermission>()
        .toSet();
  }

  Future<RoleOption?> _role(String roleId) async {
    final roles = await listRoles();
    for (final role in roles) {
      if (role.id == roleId) {
        return role;
      }
    }
    return null;
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError('PIN must be 4 to 8 digits.');
    }
  }
}
