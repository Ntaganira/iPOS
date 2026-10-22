/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.core
 * - File      : invoice_email_service_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Recipient validation and configuration failure behavior; SMTP
 *               transport itself is exercised only against a live relay.
 * </pre>
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/email/invoice_email_service.dart';
import 'package:ipos/core/printing/esc_pos_printer.dart';
import 'package:ipos/data/models/terminal_settings.dart';
import 'package:ipos/data/repositories/checkout_repository.dart';

ReceiptDocument _document() {
  return ReceiptDocument(
    storeName: 'iPOS Parts Counter',
    invoiceNumber: 'INV-1',
    issuedAt: DateTime.utc(2026, 10, 22),
    lines: const <CheckoutLineSnapshot>[
      CheckoutLineSnapshot(
        sku: 'SKU-1',
        partName: 'Brake Pad',
        quantity: 1,
        uomLabel: 'EA',
        unitPriceCents: 1000,
        lineTotalCents: 1000,
        coreFeeCents: 0,
      ),
    ],
    subtotalCents: 1000,
    taxCents: 180,
    coreFeeCents: 0,
    totalCents: 1180,
    paymentMethod: 'cash',
  );
}

void main() {
  test('accepts practical email addresses and rejects malformed input', () {
    expect(InvoiceEmailService.isValidAddress('parts@example.com'), isTrue);
    expect(InvoiceEmailService.isValidAddress('a.b+c@sub.example.co'), isTrue);
    expect(InvoiceEmailService.isValidAddress('parts@'), isFalse);
    expect(InvoiceEmailService.isValidAddress('@example.com'), isFalse);
    expect(
      InvoiceEmailService.isValidAddress('two words@example.com'),
      isFalse,
    );
    expect(InvoiceEmailService.isValidAddress('parts@example'), isFalse);
  });

  test('refuses to send before SMTP settings are configured', () async {
    const service = InvoiceEmailService(
      settings: TerminalSettings(deviceId: 'device-1'),
    );

    await expectLater(
      service.send(
        document: _document(),
        request: const EmailRequest(
          recipient: 'parts@example.com',
          delivery: EmailDelivery.text,
        ),
      ),
      throwsA(isA<EmailConfigurationException>()),
    );
  });
}
