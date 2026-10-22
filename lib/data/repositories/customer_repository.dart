/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : customer_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline customer-account administration. Creates and edits
 *               trade accounts, maintains cached balances, writes sync-outbox
 *               revisions, and audits changes. Soft-delete tombstones preserve
 *               historical invoices while removing the account from checkout
 *               selection.
 * </pre>
 */

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/customer_account.dart';
import 'audit_repository.dart';

/// Customer directory gateway.
class CustomerRepository {
  CustomerRepository(this._database, {AuditActor? Function()? actorProvider})
    : _audit = AuditRepository(_database, actorProvider: actorProvider),
      _uuid = Uuid();

  final AppDatabase _database;
  final AuditRepository _audit;
  final Uuid _uuid;

  Future<List<CustomerAccount>> list({String? term}) async {
    final normalized = term?.trim() ?? '';
    final variables = <Variable<Object>>[];
    var filter = 'is_deleted = 0';
    if (normalized.isNotEmpty) {
      final pattern = '%${_escapeLike(normalized)}%';
      filter +=
          " AND (display_name LIKE ? ESCAPE '\\' "
          "OR phone LIKE ? ESCAPE '\\' "
          "OR tax_id LIKE ? ESCAPE '\\')";
      variables
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern));
    }

    final rows = await _database.customSelect('''
            SELECT id, display_name, phone, tax_id, balance_cents, updated_at
            FROM customers
            WHERE $filter
            ORDER BY display_name COLLATE NOCASE
            LIMIT 1000
          ''', variables: variables).get();

    return rows.map(_map).toList(growable: false);
  }

  Future<String> create(CustomerDraft draft) async {
    final normalized = _normalize(draft);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await _database
          .into(_database.customers)
          .insert(
            CustomersCompanion.insert(
              id: id,
              displayName: normalized.displayName,
              phone: Value(normalized.phone),
              taxId: Value(normalized.taxId),
              balanceCents: Value(normalized.balanceCents),
              updatedAt: now,
            ),
          );
      await _enqueue(id, normalized, now, operation: 'upsert');
      await _audit.append(
        eventType: 'customer.created',
        action: 'create',
        entityType: 'customer',
        entityId: id,
        message: 'Customer ${normalized.displayName} created.',
        after: _draftSnapshot(normalized),
      );
    });
    return id;
  }

  Future<void> update(String customerId, CustomerDraft draft) async {
    final normalized = _normalize(draft);
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      final existing = await (_database.select(
        _database.customers,
      )..where((table) => table.id.equals(customerId))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Customer not found.');
      }
      final changed =
          await (_database.update(
            _database.customers,
          )..where((table) => table.id.equals(customerId))).write(
            CustomersCompanion(
              displayName: Value(normalized.displayName),
              phone: Value(normalized.phone),
              taxId: Value(normalized.taxId),
              balanceCents: Value(normalized.balanceCents),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );
      if (changed == 0) {
        throw StateError('Customer not found.');
      }
      await _enqueue(customerId, normalized, now, operation: 'upsert');
      await _audit.append(
        eventType: 'customer.updated',
        action: 'update',
        entityType: 'customer',
        entityId: customerId,
        message: 'Customer ${normalized.displayName} updated.',
        before: _snapshot(existing),
        after: _draftSnapshot(normalized),
      );
    });
  }

  Future<void> softDelete(String customerId) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      final customer = await (_database.select(
        _database.customers,
      )..where((table) => table.id.equals(customerId))).getSingleOrNull();
      if (customer == null) {
        return;
      }
      await (_database.update(
        _database.customers,
      )..where((table) => table.id.equals(customerId))).write(
        CustomersCompanion(
          isDeleted: const Value(true),
          isSynced: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _database
          .into(_database.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: _uuid.v4(),
              entityType: 'customer',
              entityId: customerId,
              operation: 'delete',
              payloadJson: jsonEncode(<String, Object?>{
                'id': customerId,
                'updated_at': now.toIso8601String(),
                'is_deleted': true,
              }),
              occurredAt: now,
            ),
          );
      await _audit.append(
        eventType: 'customer.deleted',
        action: 'delete',
        entityType: 'customer',
        entityId: customerId,
        message: 'Customer ${customer.displayName} tombstoned.',
        before: _snapshot(customer),
        after: const <String, Object?>{'is_deleted': true},
      );
    });
  }

  Future<void> _enqueue(
    String customerId,
    CustomerDraft draft,
    DateTime now, {
    required String operation,
  }) async {
    await _database
        .into(_database.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: _uuid.v4(),
            entityType: 'customer',
            entityId: customerId,
            operation: operation,
            payloadJson: jsonEncode(<String, Object?>{
              'id': customerId,
              'display_name': draft.displayName,
              'phone': draft.phone,
              'tax_id': draft.taxId,
              'balance_cents': draft.balanceCents,
              'updated_at': now.toIso8601String(),
              'is_deleted': false,
            }),
            occurredAt: now,
          ),
        );
  }

  CustomerDraft _normalize(CustomerDraft draft) {
    final name = draft.displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        draft.displayName,
        'displayName',
        'Customer name is required.',
      );
    }
    if (draft.balanceCents < 0) {
      throw ArgumentError('Balance cannot be negative in this ledger.');
    }
    return CustomerDraft(
      displayName: name,
      phone: _blankToNull(draft.phone),
      taxId: _blankToNull(draft.taxId),
      balanceCents: draft.balanceCents,
    );
  }

  CustomerAccount _map(QueryRow row) {
    return CustomerAccount(
      id: row.read<String>('id'),
      displayName: row.read<String>('display_name'),
      phone: row.readNullable<String>('phone'),
      taxId: row.readNullable<String>('tax_id'),
      balanceCents: row.read<int>('balance_cents'),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at') * 1000,
        isUtc: true,
      ),
    );
  }

  Map<String, Object?> _snapshot(CustomerRow customer) {
    return <String, Object?>{
      'display_name': customer.displayName,
      'phone': customer.phone,
      'tax_id': customer.taxId,
      'balance_cents': customer.balanceCents,
      'is_deleted': customer.isDeleted,
    };
  }

  Map<String, Object?> _draftSnapshot(CustomerDraft draft) {
    return <String, Object?>{
      'display_name': draft.displayName,
      'phone': draft.phone,
      'tax_id': draft.taxId,
      'balance_cents': draft.balanceCents,
      'is_deleted': false,
    };
  }

  String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
