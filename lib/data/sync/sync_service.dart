/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.sync
 * - File      : sync_service.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Durable outbox drain and master-data reconciliation. Pending
 *               revisions upload in occurrence order with bounded batches;
 *               acknowledged rows leave the queue, server conflicts overwrite
 *               local master rows, and transport failures stay pending with
 *               exponential backoff instead of dropping sales. Pulls apply
 *               server changes transactionally and persist the cursor in the
 *               encrypted settings registry.
 * </pre>
 */

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import 'http_sync_transport.dart';
import 'sync_contract.dart';

/// Summary of one push/pull cycle.
class SyncRunResult {
  const SyncRunResult({
    required this.pushed,
    required this.conflicts,
    required this.pulled,
    required this.skipped,
    required this.pending,
  });

  final int pushed;
  final int conflicts;
  final int pulled;
  final int skipped;
  final int pending;
}

/// Push/pull reconciliation engine for the terminal outbox.
class SyncService {
  SyncService({
    required AppDatabase database,
    required SyncTransport transport,
    required String deviceId,
    NotificationRepository? notifications,
    this.batchSize = 100,
  }) : _database = database,
       _transport = transport,
       _deviceId = deviceId,
       _notifications = notifications ?? NotificationRepository(database);

  static const String cursorKey = 'sync.cursor';

  final AppDatabase _database;
  final SyncTransport _transport;
  final String _deviceId;
  final NotificationRepository _notifications;
  final int batchSize;

  /// Runs one push then pull. Throws on transport failure after scheduling a
  /// bounded retry; successful partial progress is never rolled back.
  Future<SyncRunResult> run() async {
    var pushed = 0;
    var conflicts = 0;
    var pulled = 0;
    var skipped = 0;

    try {
      final pending = await _pending();
      if (pending.isNotEmpty) {
        final result = await _transport.push(
          deviceId: _deviceId,
          items: pending.map(_toItem).toList(growable: false),
        );
        await _database.transaction(() async {
          await _acknowledge(result.accepted);
          for (final conflict in result.conflicts) {
            await _applyPayload(
              entityType: conflict.entityType,
              operation: conflict.operation,
              payload: conflict.payload,
              fallbackId: conflict.entityId,
            );
            await _acknowledge(<String>[conflict.outboxId]);
          }
        });
        pushed = result.accepted.length;
        conflicts = result.conflicts.length;
      }

      final cursor = await _readCursor();
      final page = await _transport.pull(deviceId: _deviceId, cursor: cursor);
      for (final change in page.changes) {
        try {
          await _applyPayload(
            entityType: change.entityType,
            operation: change.operation,
            payload: change.payload,
            fallbackId: change.entityId,
          );
          pulled++;
        } on FormatException catch (error) {
          skipped++;
          await _notify(
            kind: 'sync_change_skipped',
            title: 'Sync change skipped',
            message:
                '${change.entityType}/${change.entityId} could not be applied: '
                '${error.message}',
            severity: NotificationSeverity.warning,
            dedupeKey: 'sync_skipped:${change.entityType}:${change.entityId}',
          );
        }
      }
      await _writeCursor(page.nextCursor);
    } catch (error) {
      await _deferPending(error);
      final rateLimited = error is SyncException && error.statusCode == 429;
      await _notify(
        kind: 'sync_failed',
        title: 'Sync failed',
        message: rateLimited
            ? 'Sync is rate-limited. The outbox is preserved and will retry '
                  'after the server delay.'
            : _truncate(error.toString()),
        severity: NotificationSeverity.warning,
        dedupeKey: 'sync_failed',
      );
      rethrow;
    }

    return SyncRunResult(
      pushed: pushed,
      conflicts: conflicts,
      pulled: pulled,
      skipped: skipped,
      pending: await _pendingCount(),
    );
  }

  Future<List<SyncOutboxRow>> _pending() {
    final now = DateTime.now().toUtc();
    return (_database.select(_database.syncOutbox)
          ..where(
            (table) =>
                table.isAcknowledged.equals(false) &
                (table.nextAttemptAt.isNull() |
                    table.nextAttemptAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.occurredAt)])
          ..limit(batchSize))
        .get();
  }

  Future<int> _pendingCount() async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS pending FROM sync_outbox '
          'WHERE is_acknowledged = 0',
        )
        .getSingle();
    return row.read<int>('pending');
  }

  SyncPushItem _toItem(SyncOutboxRow row) {
    final decoded = jsonDecode(row.payloadJson);
    return SyncPushItem(
      id: row.id,
      entityType: row.entityType,
      entityId: row.entityId,
      operation: row.operation,
      payload: decoded is Map<String, Object?>
          ? decoded
          : const <String, Object?>{},
      occurredAt: row.occurredAt,
    );
  }

  Future<void> _acknowledge(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.syncOutbox,
    )..where((table) => table.id.isIn(ids))).write(
      SyncOutboxCompanion(
        isAcknowledged: const Value(true),
        acknowledgedAt: Value(now),
      ),
    );
  }

  Future<void> _deferPending(Object failure) async {
    final now = DateTime.now().toUtc();
    final syncFailure = failure is SyncException ? failure : null;
    final retryAfter = syncFailure?.retryAfter;
    final rateLimited = syncFailure?.statusCode == 429;
    final pending = await (_database.select(
      _database.syncOutbox,
    )..where((table) => table.isAcknowledged.equals(false))).get();
    for (final row in pending) {
      final attempts = row.attempts + 1;
      final backoff = Duration(
        seconds: min(3600, 30 * pow(2, min(attempts, 7)).toInt()),
      );
      final delay = retryAfter != null
          ? Duration(seconds: retryAfter.inSeconds.clamp(1, 3600))
          : rateLimited
          ? Duration(seconds: max(120, backoff.inSeconds).clamp(120, 3600))
          : backoff;
      await (_database.update(
        _database.syncOutbox,
      )..where((table) => table.id.equals(row.id))).write(
        SyncOutboxCompanion(
          attempts: Value(attempts),
          nextAttemptAt: Value(now.add(delay)),
          lastError: Value(_truncate(failure.toString())),
        ),
      );
    }
  }

  Future<void> _applyPayload({
    required String entityType,
    required String operation,
    required Map<String, Object?> payload,
    required String fallbackId,
  }) async {
    final id = _string(payload, 'id', fallback: fallbackId);
    final deleted = operation == 'delete' || _bool(payload, 'is_deleted');
    switch (entityType) {
      case 'product':
        if (deleted) {
          await _tombstone(_database.products, id);
          return;
        }
        await _database
            .into(_database.products)
            .insertOnConflictUpdate(
              ProductsCompanion.insert(
                id: id,
                sku: _string(payload, 'sku', required: true),
                oemNumber: Value(_nullableString(payload, 'oem_number')),
                partName: _string(payload, 'part_name', required: true),
                brand: Value(_nullableString(payload, 'brand')),
                retailPrice: _int(payload, 'retail_price', required: true),
                tradePrice: Value(_nullableInt(payload, 'trade_price')),
                coreFeeCents: Value(_int(payload, 'core_fee_cents')),
                baseUnit: Value(_nullableString(payload, 'base_unit') ?? 'EA'),
                updatedAt: _date(payload),
                isSynced: const Value(true),
                isDeleted: const Value(false),
              ),
            );
      case 'customer':
        if (deleted) {
          await _tombstone(_database.customers, id);
          return;
        }
        await _database
            .into(_database.customers)
            .insertOnConflictUpdate(
              CustomersCompanion.insert(
                id: id,
                displayName: _string(payload, 'display_name', required: true),
                phone: Value(_nullableString(payload, 'phone')),
                taxId: Value(_nullableString(payload, 'tax_id')),
                balanceCents: Value(_int(payload, 'balance_cents')),
                updatedAt: _date(payload),
                isSynced: const Value(true),
                isDeleted: const Value(false),
              ),
            );
      case 'vehicle':
        if (deleted) {
          await _tombstone(_database.vehicles, id);
          return;
        }
        await _database
            .into(_database.vehicles)
            .insertOnConflictUpdate(
              VehiclesCompanion.insert(
                id: id,
                make: _string(payload, 'make', required: true),
                model: _string(payload, 'model', required: true),
                year: _int(payload, 'year', required: true),
                engineCode: Value(_nullableString(payload, 'engine_code')),
                updatedAt: _date(payload),
                isSynced: const Value(true),
                isDeleted: const Value(false),
              ),
            );
      case 'product_compatibility':
        if (deleted) {
          await _tombstone(_database.productCompatibility, id);
          return;
        }
        await _database
            .into(_database.productCompatibility)
            .insertOnConflictUpdate(
              ProductCompatibilityCompanion.insert(
                id: id,
                productId: _string(payload, 'product_id', required: true),
                vehicleId: _string(payload, 'vehicle_id', required: true),
                updatedAt: _date(payload),
                isSynced: const Value(true),
                isDeleted: const Value(false),
              ),
            );
      case 'uom_conversion':
        if (deleted) {
          await _tombstone(_database.uomConversions, id);
          return;
        }
        await _database
            .into(_database.uomConversions)
            .insertOnConflictUpdate(
              UomConversionsCompanion.insert(
                id: id,
                productId: _string(payload, 'product_id', required: true),
                fromUnit: _string(payload, 'from_unit', required: true),
                toUnit: _string(payload, 'to_unit', required: true),
                factor: _int(payload, 'factor', required: true),
                updatedAt: _date(payload),
                isSynced: const Value(true),
                isDeleted: const Value(false),
              ),
            );
      default:
        throw FormatException('Unsupported entity type "$entityType".');
    }
  }

  Future<void> _tombstone<T extends Table, D>(
    TableInfo<T, D> table,
    String id,
  ) async {
    await _database.customUpdate(
      'UPDATE ${table.actualTableName} SET is_deleted = 1, is_synced = 1 '
      'WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {table},
    );
  }

  Future<int> _readCursor() async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((table) => table.settingKey.equals(cursorKey))).getSingleOrNull();
    return int.tryParse(row?.settingValue ?? '') ?? 0;
  }

  Future<void> _writeCursor(int cursor) async {
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            settingKey: cursorKey,
            settingValue: '$cursor',
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> _notify({
    required String kind,
    required String title,
    required String message,
    required NotificationSeverity severity,
    required String dedupeKey,
  }) {
    return _notifications.add(
      kind: kind,
      title: title,
      message: message,
      severity: severity,
      dedupeKey: dedupeKey,
    );
  }

  String _string(
    Map<String, Object?> payload,
    String key, {
    bool required = false,
    String? fallback,
  }) {
    final value = _nullableString(payload, key) ?? fallback;
    if (value == null || value.isEmpty) {
      if (required) {
        throw FormatException('Missing required field "$key".');
      }
      return fallback ?? '';
    }
    return value;
  }

  String? _nullableString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int _int(Map<String, Object?> payload, String key, {bool required = false}) {
    final value = _nullableInt(payload, key);
    if (value == null) {
      if (required) {
        throw FormatException('Missing required integer "$key".');
      }
      return 0;
    }
    return value;
  }

  int? _nullableInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  bool _bool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is bool) {
      return value;
    }
    return value?.toString().toLowerCase() == 'true';
  }

  DateTime _date(Map<String, Object?> payload) {
    return DateTime.tryParse(
          payload['updated_at']?.toString() ?? '',
        )?.toUtc() ??
        DateTime.now().toUtc();
  }

  String _truncate(String value) =>
      value.length <= 200 ? value : '${value.substring(0, 200)}...';
}
