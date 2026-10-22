/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : sync_service_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Outbox drain, conflict overwrite, cursor persistence, skip
 *               handling, and retry backoff against a deterministic fake
 *               transport on an in-memory ledger.
 * </pre>
 */

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/repositories/notification_repository.dart';
import 'package:ipos/data/sync/http_sync_transport.dart';
import 'package:ipos/data/sync/sync_contract.dart';
import 'package:ipos/data/sync/sync_service.dart';

class _FakeTransport implements SyncTransport {
  _FakeTransport({this.pushResult, this.pullResult});

  SyncPushResult? pushResult;
  SyncPullResult? pullResult;
  Object? pushError;

  final List<SyncPushItem> items = <SyncPushItem>[];
  int pulls = 0;

  @override
  Future<SyncPushResult> push({
    required String deviceId,
    required List<SyncPushItem> items,
  }) async {
    this.items.addAll(items);
    final error = pushError;
    if (error != null) {
      throw error;
    }
    return pushResult ??
        SyncPushResult(
          accepted: items.map((item) => item.id).toList(growable: false),
          conflicts: const <SyncConflict>[],
          serverTime: DateTime.utc(2026, 10, 22),
        );
  }

  @override
  Future<SyncPullResult> pull({
    required String deviceId,
    required int cursor,
  }) async {
    pulls++;
    return pullResult ??
        SyncPullResult(
          changes: const <SyncChange>[],
          nextCursor: cursor,
          serverTime: DateTime.utc(2026, 10, 22),
        );
  }
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<String> enqueue({
    String type = 'product',
    String id = 'part-1',
    String operation = 'upsert',
    required Map<String, Object?> payload,
  }) async {
    const outboxId = 'outbox-1';
    await database
        .into(database.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: outboxId,
            entityType: type,
            entityId: id,
            operation: operation,
            payloadJson: jsonEncode(payload),
            occurredAt: DateTime.utc(2026, 10, 22, 8),
          ),
        );
    return outboxId;
  }

  test(
    'pushes pending work, applies pulled master data, and stores cursor',
    () async {
      final outboxId = await enqueue(
        payload: const <String, Object?>{
          'id': 'part-1',
          'sku': 'SKU-1',
          'part_name': 'Brake Pad',
          'retail_price': 12000,
        },
      );
      final transport = _FakeTransport(
        pullResult: SyncPullResult(
          changes: [
            SyncChange(
              entityType: 'product',
              entityId: 'part-9',
              operation: 'upsert',
              payload: <String, Object?>{
                'id': 'part-9',
                'sku': 'SKU-9',
                'part_name': 'Oil Filter',
                'retail_price': 8500,
                'updated_at': DateTime.utc(2026, 10, 22).toIso8601String(),
              },
              updatedAt: DateTime.utc(2026, 10, 22),
            ),
          ],
          nextCursor: 7,
          serverTime: DateTime.utc(2026, 10, 22),
        ),
      );
      final service = SyncService(
        database: database,
        transport: transport,
        deviceId: 'device-1',
      );

      final result = await service.run();

      expect(transport.items.single.id, outboxId);
      expect(result.pushed, 1);
      expect(result.pulled, 1);
      final product = await (database.select(
        database.products,
      )..where((table) => table.id.equals('part-9'))).getSingle();
      expect(product.partName, 'Oil Filter');
      expect(product.isSynced, isTrue);

      final outbox = await (database.select(
        database.syncOutbox,
      )..where((table) => table.id.equals(outboxId))).getSingle();
      expect(outbox.isAcknowledged, isTrue);

      final cursor =
          await (database.select(database.appSettings)..where(
                (table) => table.settingKey.equals(SyncService.cursorKey),
              ))
              .getSingle();
      expect(cursor.settingValue, '7');
    },
  );

  test(
    'server conflict overwrites local master data before acknowledging',
    () async {
      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'customer-1',
              displayName: 'Local Name',
              updatedAt: DateTime.utc(2026, 10, 22),
            ),
          );
      await enqueue(
        type: 'customer',
        id: 'customer-1',
        payload: const <String, Object?>{
          'id': 'customer-1',
          'display_name': 'Local Name',
        },
      );
      final transport = _FakeTransport(
        pushResult: SyncPushResult(
          accepted: const <String>[],
          conflicts: [
            SyncConflict(
              outboxId: 'outbox-1',
              entityType: 'customer',
              entityId: 'customer-1',
              operation: 'upsert',
              payload: <String, Object?>{
                'id': 'customer-1',
                'display_name': 'Server Name',
                'balance_cents': 500,
                'updated_at': DateTime.utc(2026, 10, 22).toIso8601String(),
              },
            ),
          ],
          serverTime: DateTime.utc(2026, 10, 22),
        ),
      );

      final result = await SyncService(
        database: database,
        transport: transport,
        deviceId: 'device-1',
      ).run();

      final customer = await (database.select(
        database.customers,
      )..where((table) => table.id.equals('customer-1'))).getSingle();
      expect(customer.displayName, 'Server Name');
      expect(customer.balanceCents, 500);
      expect(result.conflicts, 1);

      final outbox = await (database.select(
        database.syncOutbox,
      )..where((table) => table.id.equals('outbox-1'))).getSingle();
      expect(outbox.isAcknowledged, isTrue);
    },
  );

  test(
    'transport failure keeps work pending, backs off, and notifies',
    () async {
      await enqueue(
        payload: const <String, Object?>{
          'id': 'part-1',
          'sku': 'SKU-1',
          'part_name': 'Brake Pad',
          'retail_price': 12000,
        },
      );
      final transport = _FakeTransport()
        ..pushError = const SyncException('network down');

      await expectLater(
        SyncService(
          database: database,
          transport: transport,
          deviceId: 'device-1',
        ).run(),
        throwsA(isA<SyncException>()),
      );

      final outbox = await (database.select(
        database.syncOutbox,
      )..where((table) => table.id.equals('outbox-1'))).getSingle();
      expect(outbox.isAcknowledged, isFalse);
      expect(outbox.attempts, 1);
      expect(outbox.nextAttemptAt, isNotNull);
      expect(outbox.lastError, contains('network down'));

      final notifications = NotificationRepository(database);
      expect(await notifications.unreadCount(), 1);
    },
  );

  test(
    'unknown pulled entity types are skipped while the cursor advances',
    () async {
      final transport = _FakeTransport(
        pullResult: SyncPullResult(
          changes: [
            SyncChange(
              entityType: 'future_entity',
              entityId: 'x-1',
              operation: 'upsert',
              payload: const <String, Object?>{'id': 'x-1'},
              updatedAt: DateTime.utc(2026, 10, 22),
            ),
          ],
          nextCursor: 12,
          serverTime: DateTime.utc(2026, 10, 22),
        ),
      );

      final result = await SyncService(
        database: database,
        transport: transport,
        deviceId: 'device-1',
      ).run();

      expect(result.skipped, 1);
      final cursor =
          await (database.select(database.appSettings)..where(
                (table) => table.settingKey.equals(SyncService.cursorKey),
              ))
              .getSingle();
      expect(cursor.settingValue, '12');
    },
  );
}
