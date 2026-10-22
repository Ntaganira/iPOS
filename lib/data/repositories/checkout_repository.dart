/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : checkout_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline checkout persistence. Writes the invoice header,
 *               immutable line snapshots, and negative stock-ledger movements
 *               inside one ACID transaction. Totals are recomputed from the
 *               cart using integer minor-unit math before persistence so the
 *               on-screen amount and the accounting record cannot diverge.
 * </pre>
 */

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/money.dart';
import '../database/app_database.dart';
import '../models/cart_line.dart';
import '../models/customer_option.dart';

/// Immutable receipt summary returned after a successful local commit.
class CheckoutResult {
  const CheckoutResult({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.subtotalCents,
    required this.taxCents,
    required this.totalCents,
    required this.issuedAt,
  });

  final String invoiceId;
  final String invoiceNumber;
  final int subtotalCents;
  final int taxCents;
  final int totalCents;
  final DateTime issuedAt;
}

/// Transactional sale writer.
class CheckoutRepository {
  CheckoutRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = Uuid();

  /// Active account list for the right-hand customer selector.
  Future<List<CustomerOption>> activeCustomers() async {
    final rows = await _database
        .customSelect('''
          SELECT id, display_name, phone
          FROM customers
          WHERE is_deleted = 0
          ORDER BY display_name COLLATE NOCASE
        ''')
        .get();

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
  /// - each negative stock movement,
  ///
  /// all succeed or all roll back. A power loss or process kill cannot produce
  /// a paid invoice with missing lines or phantom stock movement. Sync flags
  /// start false so the back-office puller can later claim these rows.
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
    final taxCents = Money.taxCents(
      subtotalCents: subtotalCents,
      rateBps: taxRateBps,
    );
    final totalCents = subtotalCents + taxCents;

    return _database.transaction(() async {
      final issuedAt = DateTime.now().toUtc();
      final timestamp = _epochSeconds(issuedAt);
      final invoiceId = _uuid.v4();
      final invoiceNumber = await _nextInvoiceNumber(issuedAt);

      await _database.customStatement(
        '''
          INSERT INTO invoices (
            id, invoice_number, customer_id, subtotal_cents, tax_cents,
            discount_cents, total_cents, tax_rate_bps, payment_method, status,
            issued_at, updated_at, is_synced, is_deleted
          ) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, 'completed', ?, ?, 0, 0)
        ''',
        <Object?>[
          invoiceId,
          invoiceNumber,
          customer?.id,
          subtotalCents,
          taxCents,
          totalCents,
          taxRateBps,
          normalizedPayment,
          timestamp,
          timestamp,
        ],
      );

      for (final line in lines) {
        final lineId = _uuid.v4();
        await _database.customStatement(
          '''
            INSERT INTO invoice_lines (
              id, invoice_id, product_id, sku_snapshot, part_name_snapshot,
              brand_snapshot, unit_price_cents, quantity, line_discount_cents,
              tax_rate_bps, line_total_cents, updated_at, is_synced, is_deleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, 0, 0)
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
            taxRateBps,
            line.lineSubtotalCents,
            timestamp,
          ],
        );

        final movementId = _uuid.v4();
        await _database.customStatement(
          '''
            INSERT INTO stock_ledger (
              id, product_id, bin_location, qty_delta, updated_at, is_synced
            ) VALUES (?, ?, 'FRONT', ?, ?, 0)
          ''',
          <Object?>[
            movementId,
            line.part.id,
            -line.quantity,
            timestamp,
          ],
        );
      }

      return CheckoutResult(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        subtotalCents: subtotalCents,
        taxCents: taxCents,
        totalCents: totalCents,
        issuedAt: issuedAt,
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
