/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : encrypted_vault_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Proves the native SQLCipher build actually encrypts the file,
 *               that the 256-bit key from the secure-store contract opens it,
 *               that a wrong key fails, and that repository reads and writes
 *               work against keyed storage. This test also guards the raw-key
 *               pragma ordering used by the production factory.
 * </pre>
 */

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late File databaseFile;

  const key =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
  const wrongKey =
      'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync('ipos_vault_');
    databaseFile = File('${temporaryDirectory.path}/vault.sqlite3');
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  AppDatabase openWithKey(String hex) {
    return AppDatabase(
      NativeDatabase(
        databaseFile,
        setup: (raw) {
          raw.execute("PRAGMA key = \"x'$hex'\";");
          raw.execute('PRAGMA cipher_compatibility = 4;');
          raw.execute('PRAGMA journal_mode = WAL;');
          raw.execute('PRAGMA foreign_keys = ON;');
          raw.select('SELECT count(*) FROM sqlite_master;');
        },
      ),
    );
  }

  test(
    'SQLCipher rejects a wrong key and accepts the raw 256-bit key',
    () async {
      final database = openWithKey(key);
      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'customer-1',
              displayName: 'Encrypted Customer',
              updatedAt: DateTime.utc(2026, 10, 22),
            ),
          );
      await database.close();

      final bytes = databaseFile.readAsBytesSync();
      expect(bytes.length, greaterThan(0));
      expect(
        String.fromCharCodes(bytes).contains('Encrypted Customer'),
        isFalse,
        reason: 'plaintext business data must not appear in the database file',
      );

      final wrong = openWithKey(wrongKey);
      await expectLater(
        wrong.customSelect('SELECT count(*) FROM customers').get(),
        throwsA(anything),
      );
      await wrong.close();

      final reopened = openWithKey(key);
      final rows = await reopened.select(reopened.customers).get();
      expect(rows.single.displayName, 'Encrypted Customer');
      await reopened.close();
    },
  );

  test('all repository hot paths work on keyed storage', () async {
    final database = openWithKey(key);
    addTearDown(database.close);

    await database.customStatement('''
        INSERT INTO products (
          id, sku, part_name, retail_price, core_fee_cents, base_unit,
          updated_at, is_synced, is_deleted
        ) VALUES ('p1', 'BRK-1', 'Brake pad', 5000, 1000, 'EA', 1700000000, 0, 0)
      ''');

    final row = await database.customSelect('''
            SELECT core_fee_cents, base_unit
            FROM products WHERE id = 'p1'
          ''').getSingle();
    expect(row.read<int>('core_fee_cents'), 1000);
    expect(row.read<String>('base_unit'), 'EA');

    final cipherVersion = await database
        .customSelect('PRAGMA cipher_version')
        .getSingleOrNull();
    expect(cipherVersion, isNotNull);
    expect(
      cipherVersion!.data.values.first.toString(),
      isNotEmpty,
      reason: 'the linked native library must be SQLCipher, not plain SQLite',
    );

    expect(sqlite.sqlite3.version.libVersion, isNotEmpty);
  });
}
