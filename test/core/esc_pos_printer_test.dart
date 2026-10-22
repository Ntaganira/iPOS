/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.core
 * - File      : esc_pos_printer_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Verifies deterministic ESC/POS ticket bytes and the network
 *               transport against an in-process TCP listener.
 * </pre>
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/printing/a4_receipt_pdf.dart';
import 'package:ipos/core/printing/esc_pos_printer.dart';
import 'package:ipos/core/printing/receipt_factory.dart';
import 'package:ipos/core/printing/receipt_paper.dart';
import 'package:ipos/data/models/cart_line.dart';
import 'package:ipos/data/models/catalog_part.dart';
import 'package:ipos/data/repositories/checkout_repository.dart';

ReceiptDocument _document() {
  return ReceiptDocument(
    storeName: 'iPOS Parts Counter',
    invoiceNumber: 'INV-20261022-0001',
    issuedAt: DateTime.utc(2026, 10, 22, 9, 30),
    lines: const <CheckoutLineSnapshot>[
      CheckoutLineSnapshot(
        sku: 'SKU-100',
        partName: 'Brake Pad Front',
        quantity: 2,
        uomLabel: 'pc',
        unitPriceCents: 12500,
        lineTotalCents: 25000,
        coreFeeCents: 0,
      ),
    ],
    subtotalCents: 25000,
    taxCents: 4500,
    coreFeeCents: 0,
    totalCents: 29500,
    paymentMethod: 'cash',
    footer: 'Thank you',
  );
}

void main() {
  test('ticket contains identity, lines, totals, cut, and drawer kick', () {
    final bytes = EscPosTicketBuilder.build(_document());
    final text = latin1.decode(bytes);

    expect(text, contains('IPOS PARTS COUNTER'));
    expect(text, contains('INV-20261022-0001'));
    expect(text, contains('2 x Brake Pad Front'));
    expect(text, contains('295.00'));
    expect(text, contains('cash'));
    expect(bytes.sublist(bytes.length - 5), <int>[
      0x1B,
      0x70,
      0x00,
      0x19,
      0xFA,
    ]);
    expect(bytes, containsAllInOrder(<int>[0x1D, 0x56, 0x42, 0x00]));
  });

  test(
    'network printer streams the ticket to the configured endpoint',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<List<int>>();
      final subscription = server.listen((socket) {
        final buffer = <int>[];
        socket.listen(
          buffer.addAll,
          onDone: () {
            received.complete(buffer);
            socket.destroy();
          },
        );
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close();
      });

      await EscPosPrinter(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      ).print(_document());

      final bytes = await received.future.timeout(const Duration(seconds: 5));
      expect(bytes, isNotEmpty);
      expect(latin1.decode(bytes), contains('INV-20261022-0001'));
    },
  );

  test('58 mm preview stays inside 32 columns and marks proformas', () {
    final document = buildProformaDocument(
      storeName: 'iPOS Parts Counter',
      lines: [
        CartLine(
          part: CatalogPart(
            id: 'part-1',
            sku: 'SKU-100',
            partName: 'Brake Pad Front',
            retailPriceCents: 12500,
            updatedAt: DateTime.utc(2026, 10, 20),
          ),
          quantity: 2,
        ),
      ],
      taxRateBps: 1800,
      issuedAt: DateTime.utc(2026, 10, 22, 9, 30),
    );

    final preview = EscPosTicketBuilder.preview(
      document,
      paper: ReceiptPaperSize.mm58,
    );

    expect(document.kind, ReceiptKind.proforma);
    expect(
      document.invoiceNumber,
      matches(RegExp(r'^PRO-20261022-\d{4}$')),
    );
    expect(document.totalCents, 29500);
    expect(preview, contains('PROFORMA'));
    expect(preview, isNot(contains('Paid')));
    for (final line in preview.split('\n')) {
      expect(line.length, lessThanOrEqualTo(32), reason: line);
    }
  });

  test('A4 renderer produces a PDF attachment', () async {
    final bytes = await A4ReceiptPdfBuilder.build(_document());

    expect(bytes.length, greaterThan(1000));
    expect(latin1.decode(bytes.take(4).toList()), '%PDF');
  });
}
