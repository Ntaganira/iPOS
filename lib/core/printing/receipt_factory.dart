/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.printing
 * - File      : receipt_factory.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Projects the live cart into a printable proforma document
 *               without writing an invoice or deducting stock. The reference is
 *               timestamp-based so a quote can be identified on the counter
 *               even while the terminal is offline.
 * </pre>
 */

import '../../data/models/cart_line.dart';
import '../../data/models/customer_option.dart';
import '../../data/repositories/checkout_repository.dart';
import '../utils/money.dart';
import 'esc_pos_printer.dart';

/// Builds a non-binding proforma for the current cart.
ReceiptDocument buildProformaDocument({
  required String storeName,
  required List<CartLine> lines,
  required int taxRateBps,
  CustomerOption? customer,
  DateTime? issuedAt,
}) {
  final now = (issuedAt ?? DateTime.now()).toLocal();
  final subtotal = lines.fold<int>(
    0,
    (sum, line) => sum + line.lineSubtotalCents,
  );
  final core = lines.fold<int>(0, (sum, line) => sum + line.coreFeeCents);
  final tax = Money.taxCents(subtotalCents: subtotal, rateBps: taxRateBps);
  return ReceiptDocument(
    storeName: storeName,
    invoiceNumber: proformaReference(now),
    issuedAt: now,
    kind: ReceiptKind.proforma,
    customerName: customer?.displayName,
    lines: lines
        .map(
          (line) => CheckoutLineSnapshot(
            sku: line.part.sku,
            partName: line.part.partName,
            quantity: line.quantity,
            uomLabel: line.uom.label,
            unitPriceCents: line.part.retailPriceCents,
            lineTotalCents: line.lineSubtotalCents,
            coreFeeCents: line.coreFeeCents,
          ),
        )
        .toList(growable: false),
    subtotalCents: subtotal,
    taxCents: tax,
    coreFeeCents: core,
    totalCents: subtotal + tax + core,
    paymentMethod: '',
    footer: 'Proforma only. Stock has not been deducted.',
  );
}

/// Stable, human-readable offline reference such as `PRO-20261022-1435`.
String proformaReference(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return 'PRO-${value.year}${two(value.month)}${two(value.day)}-'
      '${two(value.hour)}${two(value.minute)}';
}
