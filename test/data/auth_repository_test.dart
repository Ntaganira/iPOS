/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : auth_repository_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Proves first-run bootstrap, seeded roles, PIN verification,
 *               forced PIN rotation, last-administrator protection, failed
 *               login auditing, actor attribution, and hash-chain integrity
 *               across the RBAC flows.
 * </pre>
 */

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/security/permissions.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/repositories/audit_repository.dart';
import 'package:ipos/data/repositories/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late AuditActor? actor;
  late AuthRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    actor = null;
    repository = AuthRepository(database, actorProvider: () => actor);
  });

  tearDown(() => database.close());

  test('bootstrap seeds roles and the first administrator once', () async {
    final bootstrap = await repository.ensureBootstrap();
    expect(bootstrap.createdAdministrator, isTrue);
    expect(bootstrap.defaultPin, AuthRepository.defaultAdminPin);

    final roles = await repository.listRoles();
    expect(
      roles.map((role) => role.id),
      containsAll(<String>[
        SystemRoles.adminId,
        SystemRoles.managerId,
        SystemRoles.cashierId,
      ]),
    );
    expect(
      roles.firstWhere((role) => role.id == SystemRoles.adminId).permissions,
      contains(AppPermission.manageUsers),
    );

    final users = await repository.listAllUsers();
    expect(users, hasLength(1));
    expect(users.single.mustChangePin, isTrue);

    final again = await repository.ensureBootstrap();
    expect(again.createdAdministrator, isFalse);
    expect(await repository.listAllUsers(), hasLength(1));
  });

  test('authentication rejects bad PINs and audits both outcomes', () async {
    await repository.ensureBootstrap();

    expect(
      await repository.authenticate(
        userId: AuthRepository.defaultAdminId,
        pin: '0000',
      ),
      isNull,
    );

    final admin = await repository.authenticate(
      userId: AuthRepository.defaultAdminId,
      pin: AuthRepository.defaultAdminPin,
    );
    expect(admin, isNotNull);
    expect(admin!.displayName, 'Administrator');
    expect(admin.mustChangePin, isTrue);
    expect(admin.can(AppPermission.manageUsers), isTrue);

    final entries = await AuditRepository(database).list();
    expect(
      entries.where((entry) => entry.eventType == 'auth.login_failed'),
      hasLength(1),
    );
    final login = entries.singleWhere(
      (entry) => entry.eventType == 'auth.login',
    );
    expect(login.actorUserId, admin.id);
    expect(login.action, 'login');
    expect((await AuditRepository(database).verifyChain()).isValid, isTrue);
  });

  test('PIN change revokes the old PIN and clears the forced change', () async {
    await repository.ensureBootstrap();
    actor = const AuditActor(userId: 'user-admin', name: 'Administrator');

    await repository.changePin(
      userId: AuthRepository.defaultAdminId,
      currentPin: AuthRepository.defaultAdminPin,
      newPin: '87654321',
    );

    expect(
      await repository.authenticate(
        userId: AuthRepository.defaultAdminId,
        pin: AuthRepository.defaultAdminPin,
      ),
      isNull,
    );
    final admin = await repository.authenticate(
      userId: AuthRepository.defaultAdminId,
      pin: '87654321',
    );
    expect(admin!.mustChangePin, isFalse);

    final audit = await AuditRepository(database).list();
    final event = audit.singleWhere(
      (entry) => entry.eventType == 'auth.pin_changed',
    );
    expect(event.actorName, 'Administrator');
    expect(event.before?['must_change_pin'], isTrue);
    expect(event.after?['must_change_pin'], isFalse);
  });

  test('cannot disable the last administrator', () async {
    await repository.ensureBootstrap();
    actor = const AuditActor(userId: 'user-admin', name: 'Administrator');

    await expectLater(
      repository.updateUser(
        userId: AuthRepository.defaultAdminId,
        displayName: 'Administrator',
        roleId: SystemRoles.adminId,
        isActive: false,
      ),
      throwsA(isA<StateError>()),
    );

    final admin = await repository.authenticate(
      userId: AuthRepository.defaultAdminId,
      pin: AuthRepository.defaultAdminPin,
    );
    expect(admin, isNotNull);
  });

  test('cashier users inherit only cashier permissions', () async {
    await repository.ensureBootstrap();
    actor = const AuditActor(userId: 'user-admin', name: 'Administrator');

    final id = await repository.createUser(
      displayName: 'Aline',
      roleId: SystemRoles.cashierId,
      pin: '2468',
    );

    final cashier = await repository.authenticate(userId: id, pin: '2468');
    expect(cashier, isNotNull);
    expect(cashier!.can(AppPermission.sell), isTrue);
    expect(cashier.can(AppPermission.manageUsers), isFalse);
    expect(cashier.can(AppPermission.viewAudit), isFalse);

    final created = (await AuditRepository(
      database,
    ).list()).singleWhere((entry) => entry.eventType == 'rbac.user_created');
    expect(created.actorUserId, 'user-admin');
    expect(created.after?['role'], 'Cashier');
  });
}
