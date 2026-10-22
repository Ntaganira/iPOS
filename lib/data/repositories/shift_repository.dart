/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : shift_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Shift-close accounting snapshot. Aggregates every completed
 *               invoice since the previous closure, freezes payment totals in
 *               an immutable local row, enqueues the summary for the back
 *               office, and audits the closure. The caller then runs WAL
 *               checkpoint/VACUUM maintenance.
 * </pre>
 */

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/app_notification.dart';
import 'audit_repository.dart';
import 'notification_repository.dart';

/// Frozen shift totals.
class ShiftSummary {
  const ShiftSummary({
    required this.id,
    required this.closedAt,
    required this.invoiceCount,
    required this.grossCents,
    required this.taxCents,
    required this.coreFeeCents,
    required this.paymentTotals,
  });

  final String id;
  final DateTime closedAt;
  final int invoiceCount;
  final int grossCents;
  final int taxCents;
  final int coreFeeCents;
  final Map<String, int> paymentTotals;
}

/// Shift lifecycle gateway.
class ShiftRepository {
  ShiftRepository(this._database, {AuditActor? Function()? actorProvider})
    : _audit = AuditRepository(_database, actorProvider: actorProvider),
      _notifications = NotificationRepository(_database),
      _uuid = Uuid();

  final AppDatabase _database;
  final AuditRepository _audit;
  final NotificationRepository _notifications;
  final Uuid _uuid;

  Future<ShiftSummary?> latest() async {
    final row = await _database.customSelect('''
            SELECT id, closed_at, invoice_count, gross_cents, tax_cents,
                   core_fee_cents, payment_summary_json
            FROM shift_closures
            ORDER BY closed_at DESC
            LIMIT 1
          ''').getSingleOrNull();
    if (row == null) {
      return null;
    }
    final payments =
        jsonDecode(row.read<String>('payment_summary_json'))
            as Map<String, Object?>;
    return ShiftSummary(
      id: row.read<String>('id'),
      closedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('closed_at') * 1000,
        isUtc: true,
      ),
      invoiceCount: row.read<int>('invoice_count'),
      grossCents: row.read<int>('gross_cents'),
      taxCents: row.read<int>('tax_cents'),
      coreFeeCents: row.read<int>('core_fee_cents'),
      paymentTotals: payments.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
    );
  }

  /// Closes the shift. Re-running immediately produces an empty closure, so the
  /// UI should disable the action until new sales arrive.
  Future<ShiftSummary> closeShift() async {
    final now = DateTime.now().toUtc();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final previous = await latest();
    final previousSeconds = previous == null
        ? 0
        : previous.closedAt.millisecondsSinceEpoch ~/ 1000;
    final id = _uuid.v4();

    return _database.transaction(() async {
      final totals = await _database
          .customSelect(
            '''
              SELECT COUNT(*) AS invoice_count,
                     COALESCE(SUM(total_cents), 0) AS gross_cents,
                     COALESCE(SUM(tax_cents), 0) AS tax_cents,
                     COALESCE(SUM(core_fee_total_cents), 0) AS core_fee_cents
              FROM invoices
              WHERE status = 'completed'
                AND is_deleted = 0
                AND issued_at > ?
                AND issued_at <= ?
            ''',
            variables: [
              Variable.withInt(previousSeconds),
              Variable.withInt(nowSeconds),
            ],
          )
          .getSingle();

      final paymentRows = await _database
          .customSelect(
            '''
              SELECT payment_method,
                     COUNT(*) AS sale_count,
                     COALESCE(SUM(total_cents), 0) AS total_cents
              FROM invoices
              WHERE status = 'completed'
                AND is_deleted = 0
                AND issued_at > ?
                AND issued_at <= ?
              GROUP BY payment_method
            ''',
            variables: [
              Variable.withInt(previousSeconds),
              Variable.withInt(nowSeconds),
            ],
          )
          .get();

      final paymentTotals = <String, int>{};
      for (final row in paymentRows) {
        paymentTotals[row.read<String>('payment_method')] = row.read<int>(
          'total_cents',
        );
      }
      final paymentJson = jsonEncode(paymentTotals);
      final invoiceCount = totals.read<int>('invoice_count');
      final grossCents = totals.read<int>('gross_cents');
      final taxCents = totals.read<int>('tax_cents');
      final coreFeeCents = totals.read<int>('core_fee_cents');

      await _database
          .into(_database.shiftClosures)
          .insert(
            ShiftClosuresCompanion.insert(
              id: id,
              closedAt: now,
              invoiceCount: invoiceCount,
              grossCents: grossCents,
              taxCents: taxCents,
              coreFeeCents: coreFeeCents,
              paymentSummaryJson: paymentJson,
            ),
          );

      await _database
          .into(_database.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: _uuid.v4(),
              entityType: 'shift_closure',
              entityId: id,
              operation: 'upsert',
              payloadJson: jsonEncode(<String, Object?>{
                'id': id,
                'closed_at': now.toIso8601String(),
                'invoice_count': invoiceCount,
                'gross_cents': grossCents,
                'tax_cents': taxCents,
                'core_fee_cents': coreFeeCents,
                'payment_totals': paymentTotals,
              }),
              occurredAt: now,
            ),
          );

      await _audit.append(
        eventType: 'shift.closed',
        action: 'create',
        entityType: 'shift_closure',
        entityId: id,
        message: 'Shift closed with $invoiceCount invoices.',
        after: <String, Object?>{
          'invoice_count': invoiceCount,
          'gross_cents': grossCents,
          'tax_cents': taxCents,
          'core_fee_cents': coreFeeCents,
          'payment_totals': paymentTotals,
        },
        occurredAt: now,
      );
      await _notifications.add(
        kind: 'shift_closed',
        severity: NotificationSeverity.info,
        title: 'Shift closed',
        message:
            '$invoiceCount invoices, gross ${(grossCents / 100).toStringAsFixed(2)}.',
        entityType: 'shift_closure',
        entityId: id,
      );

      return ShiftSummary(
        id: id,
        closedAt: now,
        invoiceCount: invoiceCount,
        grossCents: grossCents,
        taxCents: taxCents,
        coreFeeCents: coreFeeCents,
        paymentTotals: Map<String, int>.unmodifiable(paymentTotals),
      );
    });
  }
}
