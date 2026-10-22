/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : checkout_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline checkout persistence. Writes the invoice header,
 *               immutable line snapshots, negative stock-ledger movements, a
 *               durable sync-outbox bundle, and a hash-chained audit event in
 *               one ACID transaction. Totals are recomputed from the cart using
 *               integer minor-unit math before persistence so the on-screen
 *               amount and the accounting record cannot diverge. Core/deposit
 *               fees are tracked separately from merchandise and VAT, and stock
 *               is deducted in base units using the selected UOM factor.
 * </pre>
 */

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/money.dart';
import '../database/app_database.dart';
import '../models/app_notification.dart';
import '../models/cart_line.dart';
import '../models/customer_option.dart';
import 'audit_repository.dart';
import 'notification_repository.dart';

/// Immutable receipt line captured at commit time.
class CheckoutLineSnapshot {
  const CheckoutLineSnapshot({
    required this.sku,
    required this.partName,
    required this.quantity,
    required this.uomLabel,
    required this.unitPriceCents,
    required this.lineTotalCents,
    required this.coreFeeCents,
  });

  final String sku;
  final String partName;
  final int quantity;
  final String uomLabel;
  final int unitPriceCents;
  final int lineTotalCents;
  final int coreFeeCents;
}

/// Immutable receipt summary returned after a successful local commit.
class CheckoutResult {
  const CheckoutResult({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.subtotalCents,
    required this.taxCents,
    required this.coreFeeCents,
    required this.totalCents,
    required this.paymentMethod,
    required this.issuedAt,
    required this.lines,
  });

  final String invoiceId;
  final String invoiceNumber;
  final int subtotalCents;
  final int taxCents;
  final int coreFeeCents;
  final int totalCents;
  final String paymentMethod;
  final DateTime issuedAt;
  final List<CheckoutLineSnapshot> lines;
}

/// Transactional sale writer.
class CheckoutRepository {
  CheckoutRepository(
    this._database, {
    AuditActor? Function()? actorProvider,
    this.lowStockThreshold = 3,
  }) : _audit = AuditRepository(_database, actorProvider: actorProvider),
       _notifications = NotificationRepository(_database);

  final AppDatabase _database;
  final AuditRepository _audit;
  final NotificationRepository _notifications;
  final int lowStockThreshold;
  final Uuid _uuid = Uuid();

  /// Active account list for the right-hand customer selector.
  Future<List<CustomerOption>> activeCustomers() async {
    final rows = await _database.customSelect('''
          SELECT id, display_name, phone
          FROM customers
          WHERE is_deleted = 0
          ORDER BY display_name COLLATE NOCASE
        ''').get();

    return rows
        .map(
          (row) => CustomerOption(
            id: row.read<String>('id'),
            displayName: row.read<String>('display_name'),
            phone: row.readNullable<String>('phone'),
          ),
        )
        .toList(growable: false);
  }

  /// Commits a counter sale without requiring network connectivity.
  ///
  /// The transaction boundary is deliberate:
  /// - invoice number allocation,
  /// - invoice header,
  /// - each invoice line,
  /// - each negative stock movement in base units,
  /// - the sync-outbox bundle,
  /// - the audit event,
  ///
  /// all succeed or all roll back. A power loss or process kill cannot produce
  /// a paid invoice with missing lines, phantom stock, or an invisible audit
  /// trail. Sync flags start false so the back-office puller can later claim
  /// these rows.
  Future<CheckoutResult> commitSale({
    required List<CartLine> lines,
    required CustomerOption? customer,
    required int taxRateBps,
    required String paymentMethod,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError.value(lines, 'lines', 'Cannot commit an empty sale.');
    }
    for (final line in lines) {
      if (line.quantity < 1) {
        throw ArgumentError.value(
          line.quantity,
          'quantity',
          'Every sale line must have a positive quantity.',
        );
      }
      if (line.uom.factor < 1) {
        throw ArgumentError.value(
          line.uom.factor,
          'uomFactor',
          'A selling unit must convert to at least one base unit.',
        );
      }
    }

    final normalizedPayment = paymentMethod.trim().toLowerCase();
    if (normalizedPayment.isEmpty) {
      throw ArgumentError.value(
        paymentMethod,
        'paymentMethod',
        'A payment method is required.',
      );
    }

    final subtotalCents = lines.fold<int>(
      0,
      (sum, line) => sum + line.lineSubtotalCents,
    );
    final coreFeeCents = lines.fold<int>(
      0,
      (sum, line) => sum + line.coreFeeCents,
    );
    final taxCents = Money.taxCents(
      subtotalCents: subtotalCents,
      rateBps: taxRateBps,
    );
    final totalCents = subtotalCents + taxCents + coreFeeCents;

    return _database.transaction(() async {
      final issuedAt = DateTime.now().toUtc();
      final timestamp = _epochSeconds(issuedAt);
      final invoiceId = _uuid.v4();
      final invoiceNumber = await _nextInvoiceNumber(issuedAt);
      final linePayloads = <Map<String, Object?>>[];
      final movementPayloads = <Map<String, Object?>>[];
      final snapshots = <CheckoutLineSnapshot>[];

      await _database.customStatement(
        '''
          INSERT INTO invoices (
            id, invoice_number, customer_id, subtotal_cents, tax_cents,
            core_fee_total_cents, discount_cents, total_cents, tax_rate_bps,
            payment_method, status, issued_at, updated_at, is_synced, is_deleted
          ) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?, 'completed', ?, ?, 0, 0)
        ''',
        <Object?>[
          invoiceId,
          invoiceNumber,
          customer?.id,
          subtotalCents,
          taxCents,
          coreFeeCents,
          totalCents,
          taxRateBps,
          normalizedPayment,
          timestamp,
          timestamp,
        ],
      );

      for (final line in lines) {
        final lineId = _uuid.v4();
        final movementId = _uuid.v4();
        await _database.customStatement(
          '''
            INSERT INTO invoice_lines (
              id, invoice_id, product_id, sku_snapshot, part_name_snapshot,
              brand_snapshot, unit_price_cents, quantity, uom_factor, uom_label,
              core_fee_cents, line_discount_cents, tax_rate_bps,
              line_total_cents, updated_at, is_synced, is_deleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, 0, 0)
          ''',
          <Object?>[
            lineId,
            invoiceId,
            line.part.id,
            line.part.sku,
            line.part.partName,
            line.part.brand,
            line.part.retailPriceCents,
            line.quantity,
            line.uom.factor,
            line.uom.label,
            line.part.coreFeeCents,
            taxRateBps,
            line.lineSubtotalCents,
            timestamp,
          ],
        );

        await _database.customStatement(
          '''
            INSERT INTO stock_ledger (
              id, product_id, bin_location, qty_delta, reference_type,
              reference_id, updated_at, is_synced
            ) VALUES (?, ?, 'FRONT', ?, 'sale', ?, ?, 0)
          ''',
          <Object?>[
            movementId,
            line.part.id,
            -line.stockQuantity,
            invoiceId,
            timestamp,
          ],
        );

        linePayloads.add(<String, Object?>{
          'id': lineId,
          'invoice_id': invoiceId,
          'product_id': line.part.id,
          'sku_snapshot': line.part.sku,
          'part_name_snapshot': line.part.partName,
          'brand_snapshot': line.part.brand,
          'unit_price_cents': line.part.retailPriceCents,
          'quantity': line.quantity,
          'uom_factor': line.uom.factor,
          'uom_label': line.uom.label,
          'core_fee_cents': line.part.coreFeeCents,
          'line_discount_cents': 0,
          'tax_rate_bps': taxRateBps,
          'line_total_cents': line.lineSubtotalCents,
          'updated_at': issuedAt.toIso8601String(),
          'is_deleted': false,
        });
        movementPayloads.add(<String, Object?>{
          'id': movementId,
          'product_id': line.part.id,
          'bin_location': 'FRONT',
          'qty_delta': -line.stockQuantity,
          'reference_type': 'sale',
          'reference_id': invoiceId,
          'updated_at': issuedAt.toIso8601String(),
        });

        final stockRow = await _database
            .customSelect(
              '''
                SELECT COALESCE(SUM(qty_delta), 0) AS on_hand
                FROM stock_ledger
                WHERE product_id = ?
              ''',
              variables: [Variable.withString(line.part.id)],
            )
            .getSingle();
        final onHand = stockRow.read<int>('on_hand');
        if (onHand <= lowStockThreshold) {
          await _notifications.add(
            kind: 'low_stock',
            severity: onHand <= 0
                ? NotificationSeverity.critical
                : NotificationSeverity.warning,
            title: 'Low stock: ${line.part.sku}',
            message:
                '${line.part.partName} has $onHand base units remaining '
                'after sale $invoiceNumber.',
            entityType: 'product',
            entityId: line.part.id,
            dedupeKey: 'low-stock:${line.part.id}',
          );
        }
        snapshots.add(
          CheckoutLineSnapshot(
            sku: line.part.sku,
            partName: line.part.partName,
            quantity: line.quantity,
            uomLabel: line.uom.label,
            unitPriceCents: line.part.retailPriceCents,
            lineTotalCents: line.lineSubtotalCents,
            coreFeeCents: line.coreFeeCents,
          ),
        );
      }

      final invoicePayload = <String, Object?>{
        'id': invoiceId,
        'invoice_number': invoiceNumber,
        'customer_id': customer?.id,
        'subtotal_cents': subtotalCents,
        'tax_cents': taxCents,
        'core_fee_total_cents': coreFeeCents,
        'discount_cents': 0,
        'total_cents': totalCents,
        'tax_rate_bps': taxRateBps,
        'payment_method': normalizedPayment,
        'status': 'completed',
        'issued_at': issuedAt.toIso8601String(),
        'updated_at': issuedAt.toIso8601String(),
        'is_deleted': false,
      };

      await _database.customStatement(
        '''
          INSERT INTO sync_outbox (
            id, entity_type, entity_id, operation, payload_json, occurred_at,
            attempts, is_acknowledged
          ) VALUES (?, 'invoice_bundle', ?, 'upsert', ?, ?, 0, 0)
        ''',
        <Object?>[
          _uuid.v4(),
          invoiceId,
          jsonEncode(<String, Object?>{
            'invoice': invoicePayload,
            'lines': linePayloads,
            'movements': movementPayloads,
          }),
          timestamp,
        ],
      );

      await _audit.append(
        eventType: 'checkout.completed',
        action: 'create',
        entityType: 'invoice',
        entityId: invoiceId,
        message: 'Sale $invoiceNumber committed offline.',
        payload: <String, Object?>{
          'invoice_id': invoiceId,
          'invoice_number': invoiceNumber,
          'subtotal_cents': subtotalCents,
          'tax_cents': taxCents,
          'core_fee_cents': coreFeeCents,
          'total_cents': totalCents,
          'tax_rate_bps': taxRateBps,
          'payment_method': normalizedPayment,
          'line_count': lines.length,
          'issued_at': issuedAt.toIso8601String(),
        },
        after: <String, Object?>{
          'invoice_number': invoiceNumber,
          'total_cents': totalCents,
          'payment_method': normalizedPayment,
          'line_count': lines.length,
        },
        occurredAt: issuedAt,
      );

      return CheckoutResult(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        subtotalCents: subtotalCents,
        taxCents: taxCents,
        coreFeeCents: coreFeeCents,
        totalCents: totalCents,
        paymentMethod: normalizedPayment,
        issuedAt: issuedAt,
        lines: List<CheckoutLineSnapshot>.unmodifiable(snapshots),
      );
    });
  }

  /// Allocates the next daily sequence inside the protected transaction.
  ///
  /// The number is for operator/audit readability; the UUID remains the true
  /// identity. Because offline terminals may allocate the same daily sequence,
  /// the unique constraint deliberately fails a collision and the back-office
  /// reconciler can namespace by terminal during sync onboarding.
  Future<String> _nextInvoiceNumber(DateTime issuedAtUtc) async {
    final prefix =
        'INV-${DateFormat('yyyyMMdd').format(issuedAtUtc.toLocal())}-';
    final lastRow = await _database
        .customSelect(
          '''
            SELECT invoice_number
            FROM invoices
            WHERE invoice_number LIKE ?
            ORDER BY invoice_number DESC
            LIMIT 1
          ''',
          variables: [Variable.withString('$prefix%')],
        )
        .getSingleOrNull();

    var nextSequence = 1;
    if (lastRow != null) {
      final lastNumber = lastRow.read<String>('invoice_number');
      if (lastNumber.length > prefix.length) {
        final parsed = int.tryParse(lastNumber.substring(prefix.length));
        if (parsed != null) {
          nextSequence = parsed + 1;
        }
      }
    }

    return '$prefix${nextSequence.toString().padLeft(5, '0')}';
  }

  /// Drift's default DateTime storage for SQLite is epoch seconds. Writing the
  /// integer explicitly keeps raw inserts byte-identical to generated inserts.
  int _epochSeconds(DateTime value) =>
      value.toUtc().millisecondsSinceEpoch ~/ 1000;
}
