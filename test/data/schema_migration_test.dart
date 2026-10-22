/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : schema_migration_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Verifies every exported Drift schema can be upgraded to the
 *               current version without destructive recreation. The verifier
 *               uses the checked-in snapshots in drift_schemas/ and validates
 *               the resulting schema, foreign keys, and indexes.
 * </pre>
 */

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/data/database/app_database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v1.dart' as v1;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('schema v1 upgrades to the current schema', () async {
    final connection = await verifier.startAt(1);
    final database = AppDatabase(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 3);
  });

  test('schema v2 upgrades to the current schema', () async {
    final connection = await verifier.startAt(2);
    final database = AppDatabase(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 3);
  });

  test('v1 rows survive upgrades and receive safe defaults', () async {
    await verifier.testWithDataIntegrity<v1.DatabaseAtV1, AppDatabase>(
      oldVersion: 1,
      newVersion: 3,
      createOld: v1.DatabaseAtV1.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(
          oldDb.products,
          RawValuesInsertable(<String, Expression<Object>>{
            'id': Variable.withString('legacy-product'),
            'sku': Variable.withString('SKU-1'),
            'part_name': Variable.withString('Legacy part'),
            'retail_price': Variable.withInt(4200),
            'updated_at': Variable.withInt(1700000000),
          }),
        );
      },
      validateItems: (database) async {
        final row = await database.customSelect('''
                SELECT sku, core_fee_cents, base_unit
                FROM products
                WHERE id = 'legacy-product'
              ''').getSingle();

        expect(row.read<String>('sku'), 'SKU-1');
        expect(row.read<int>('core_fee_cents'), 0);
        expect(row.read<String>('base_unit'), 'EA');
      },
    );
  });
}
