/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : database_maintenance_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Exercises encrypted backup, integrity verification, WAL
 *               checkpoint/VACUUM, gated plaintext export, audit-chain
 *               verification, and the full PRAGMA rekey rotation ceremony.
 * </pre>
 */

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/security/database_key_rotation_service.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/database/database_maintenance_service.dart';
import 'package:ipos/data/repositories/audit_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldKey =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
  const newKey =
      'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';

  late Directory temp;
  late File databaseFile;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('ipos_maint_');
    databaseFile = File('${temp.path}/ipos.sqlite3');
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  AppDatabase openFileWithKey(File file, String key) {
    return AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute("PRAGMA key = \"x'$key'\";");
          raw.execute('PRAGMA cipher_compatibility = 4;');
          raw.execute('PRAGMA journal_mode = WAL;');
          raw.execute('PRAGMA foreign_keys = ON;');
          raw.select('SELECT count(*) FROM sqlite_master;');
        },
      ),
    );
  }

  AppDatabase openWithKey(String key) => openFileWithKey(databaseFile, key);

  Future<void> seed(AppDatabase database) async {
    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            displayName: 'Maintenance Customer',
            updatedAt: DateTime.utc(2026, 10, 22),
          ),
        );
  }

  test('backup, integrity, vacuum, export, and audit chain', () async {
    final database = openWithKey(oldKey);
    await seed(database);
    final maintenance = DatabaseMaintenanceService(database);

    await maintenance.checkpoint();
    await maintenance.vacuum();

    final report = await maintenance.verifyIntegrity();
    expect(report.isValid, isTrue);
    expect(report.cipherVersion, isNotNull);

    final backup = await maintenance.createEncryptedBackup(
      databaseFile: databaseFile,
      backupDirectory: Directory('${temp.path}/backups'),
    );
    expect(backup.existsSync(), isTrue);
    expect(backup.lengthSync(), greaterThan(0));

    final exported = await maintenance.exportPlaintext(
      destination: Directory('${temp.path}/export'),
      acknowledgeRisk: true,
    );
    expect(exported.existsSync(), isTrue);

    final plain = sqlite.sqlite3.open(
      exported.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      final rows = plain.select('SELECT display_name FROM customers');
      expect(rows.single['display_name'], 'Maintenance Customer');
    } finally {
      plain.close();
    }

    final audit = AuditRepository(database);
    final verification = await audit.verifyChain();
    expect(verification.isValid, isTrue);
    expect(verification.checkedEvents, greaterThanOrEqualTo(2));

    await expectLater(
      maintenance.exportPlaintext(
        destination: Directory('${temp.path}/export-denied'),
        acknowledgeRisk: false,
      ),
      throwsStateError,
    );

    await database.close();

    final unreadableBackup = openFileWithKey(backup, newKey);
    await expectLater(
      unreadableBackup.select(unreadableBackup.customers).get(),
      throwsA(anything),
    );
    await unreadableBackup.close();

    final backupDatabase = AppDatabase(
      NativeDatabase(
        backup,
        setup: (raw) {
          raw.execute("PRAGMA key = \"x'$oldKey'\";");
          raw.execute('PRAGMA cipher_compatibility = 4;');
          raw.select('SELECT count(*) FROM sqlite_master;');
        },
      ),
    );
    final backupRows = await backupDatabase
        .select(backupDatabase.customers)
        .get();
    expect(backupRows.single.displayName, 'Maintenance Customer');
    await backupDatabase.close();
  });

  test(
    'explicit key rotation preserves rows and rejects the old key',
    () async {
      final database = openWithKey(oldKey);
      await seed(database);
      await database.close();

      final rotation = await DatabaseKeyRotationService().rotate(
        databaseFile: databaseFile,
        oldKeyHex: oldKey,
        newKeyHex: newKey,
      );

      expect(rotation.backupFile.existsSync(), isTrue);

      final rotated = openWithKey(newKey);
      final rows = await rotated.select(rotated.customers).get();
      expect(rows.single.displayName, 'Maintenance Customer');
      await rotated.close();

      final rejected = openWithKey(oldKey);
      await expectLater(
        rejected.customSelect('SELECT count(*) FROM customers').get(),
        throwsA(anything),
      );
      await rejected.close();
    },
  );
}
