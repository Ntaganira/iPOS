/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.printing
 * - File      : esc_pos_printer.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : ESC/POS network printer for 80 mm counter rolls and 58 mm
 *               mini/mobile printers. Builds a deterministic ticket on the
 *               selected column grid, then emits init, paper cut, and
 *               cash-drawer kick commands over a short-lived TCP connection.
 *               A plain-text renderer backs the in-app print preview. Print
 *               failures never roll back the already-committed invoice.
 * </pre>
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/repositories/checkout_repository.dart';
import '../utils/money.dart';
import 'receipt_paper.dart';

/// Document class shown on the printed header.
enum ReceiptKind { sale, proforma }

/// One printable receipt, independent of Flutter and localization.
class ReceiptDocument {
  const ReceiptDocument({
    required this.storeName,
    required this.invoiceNumber,
    required this.issuedAt,
    required this.lines,
    required this.subtotalCents,
    required this.taxCents,
    required this.coreFeeCents,
    required this.totalCents,
    required this.paymentMethod,
    this.kind = ReceiptKind.sale,
    this.customerName,
    this.footer,
  });

  final String storeName;
  final String invoiceNumber;
  final DateTime issuedAt;
  final List<CheckoutLineSnapshot> lines;
  final int subtotalCents;
  final int taxCents;
  final int coreFeeCents;
  final int totalCents;
  final String paymentMethod;
  final ReceiptKind kind;
  final String? customerName;
  final String? footer;

  bool get isProforma => kind == ReceiptKind.proforma;

  String get documentTitle => isProforma ? 'PROFORMA' : 'RECEIPT';

  /// Builds a document from the committed checkout result.
  factory ReceiptDocument.fromCheckout({
    required String storeName,
    required CheckoutResult result,
    String? footer,
  }) {
    return ReceiptDocument(
      storeName: storeName,
      invoiceNumber: result.invoiceNumber,
      issuedAt: result.issuedAt,
      lines: result.lines,
      subtotalCents: result.subtotalCents,
      taxCents: result.taxCents,
      coreFeeCents: result.coreFeeCents,
      totalCents: result.totalCents,
      paymentMethod: result.paymentMethod,
      footer: footer,
    );
  }
}

/// Sends ESC/POS bytes to a network-attached thermal printer.
class EscPosPrinter {
  EscPosPrinter({
    required this.host,
    required this.port,
    this.timeout = const Duration(seconds: 4),
  });

  final String host;
  final int port;
  final Duration timeout;

  bool get isConfigured => host.trim().isNotEmpty && port > 0;

  /// Connects, writes the ticket, kicks the cash drawer, cuts, and disconnects.
  Future<void> print(
    ReceiptDocument document, {
    ReceiptPaperSize paper = ReceiptPaperSize.mm80,
  }) async {
    if (!isConfigured) {
      throw StateError('No receipt printer is configured.');
    }
    if (!paper.isThermal) {
      throw StateError('A4 receipts require the system print dialog.');
    }
    final bytes = EscPosTicketBuilder.build(document, paper: paper);
    final socket = await Socket.connect(host.trim(), port, timeout: timeout);
    try {
      socket.add(bytes);
      await socket.flush().timeout(timeout);
    } finally {
      socket.destroy();
    }
  }
}

/// Pure ESC/POS byte builder so ticket layout is testable without hardware.
class EscPosTicketBuilder {
  static const int width = 42;

  static List<int> build(
    ReceiptDocument document, {
    ReceiptPaperSize paper = ReceiptPaperSize.mm80,
  }) {
    if (!paper.isThermal) {
      throw ArgumentError.value(paper, 'paper', 'A4 is not an ESC/POS roll.');
    }
    final columns = paper.columns;
    final body = _body(document, columns);
    final out = <int>[];
    void raw(List<int> value) => out.addAll(value);
    void line([String value = '']) => raw(_encode('$value\n'));

    raw(const <int>[0x1B, 0x40]); // Initialize.
    raw(const <int>[0x1B, 0x61, 0x01]); // Center.
    raw(const <int>[0x1B, 0x45, 0x01]); // Bold.
    line(_fit(document.storeName.toUpperCase(), columns, center: true));
    line(_fit(document.documentTitle, columns, center: true));
    raw(const <int>[0x1B, 0x45, 0x00]);
    line(_fit(document.invoiceNumber, columns, center: true));
    line(_fit(_stamp(document.issuedAt), columns, center: true));
    line(_repeat('-', columns));

    raw(const <int>[0x1B, 0x61, 0x00]); // Left.
    for (var index = 0; index < body.lines.length; index++) {
      if (index == body.totalIndex) {
        raw(const <int>[0x1B, 0x45, 0x01]);
        line(body.lines[index]);
        raw(const <int>[0x1B, 0x45, 0x00]);
      } else {
        line(body.lines[index]);
      }
    }

    if (document.footer != null && document.footer!.trim().isNotEmpty) {
      line(_repeat('-', columns));
      raw(const <int>[0x1B, 0x61, 0x01]);
      line(_fit(document.footer!, columns, center: true));
    }

    raw(const <int>[0x0A, 0x0A, 0x0A]);
    raw(const <int>[0x1D, 0x56, 0x42, 0x00]); // Feed and partial cut.
    raw(const <int>[0x1B, 0x70, 0x00, 0x19, 0xFA]); // Cash drawer kick.
    return out;
  }

  /// Plain-text rendering used by the in-app preview. Mirrors the roll layout
  /// without control commands or bold styling.
  static String preview(
    ReceiptDocument document, {
    ReceiptPaperSize paper = ReceiptPaperSize.mm80,
  }) {
    final columns = paper.isThermal ? paper.columns : width;
    final lines = <String>[
      _fit(document.storeName.toUpperCase(), columns, center: true),
      _fit(document.documentTitle, columns, center: true),
      _fit(document.invoiceNumber, columns, center: true),
      _fit(_stamp(document.issuedAt), columns, center: true),
      _repeat('-', columns),
      ..._body(document, columns).lines,
    ];
    if (document.footer != null && document.footer!.trim().isNotEmpty) {
      lines
        ..add(_repeat('-', columns))
        ..add(_fit(document.footer!, columns, center: true));
    }
    return lines.join('\n');
  }

  static ({List<String> lines, int totalIndex}) _body(
    ReceiptDocument document,
    int columns,
  ) {
    final lines = <String>[];
    for (final item in document.lines) {
      final label = '${item.quantity} x ${item.partName}';
      final amount = Money.formatCents(item.lineTotalCents);
      final labelWidth = columns - amount.length - 1;
      if (labelWidth > 3) {
        final clipped = label.length <= labelWidth
            ? label
            : '${label.substring(0, labelWidth - 3)}...';
        lines.add('${_asAscii(clipped).padRight(labelWidth)} $amount');
      } else {
        lines
          ..add(_asAscii(label))
          ..add(amount.padLeft(columns));
      }
      if (item.uomLabel.isNotEmpty) {
        lines.add(
          '  ${item.uomLabel} @ ${Money.formatCents(item.unitPriceCents)}',
        );
      }
    }
    lines.add(_repeat('-', columns));
    lines.add(_amount('Subtotal', document.subtotalCents, columns));
    lines.add(_amount('VAT', document.taxCents, columns));
    if (document.coreFeeCents > 0) {
      lines.add(_amount('Core deposits', document.coreFeeCents, columns));
    }
    final totalIndex = lines.length;
    lines.add(_amount('TOTAL', document.totalCents, columns));
    if (!document.isProforma) {
      lines.add(_labeled('Paid', document.paymentMethod, columns));
    }
    return (lines: lines, totalIndex: totalIndex);
  }

  static String _amount(String label, int cents, int columns) =>
      _labeled(label, Money.formatCents(cents), columns);

  static String _labeled(String label, String value, int columns) {
    final safeLabel = _asAscii(label);
    final safeValue = _asAscii(value);
    final gap = columns - safeLabel.length - safeValue.length;
    return '$safeLabel${' ' * (gap < 1 ? 1 : gap)}$safeValue';
  }

  static String _stamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _fit(String value, int columns, {bool center = false}) {
    final text = _asAscii(value);
    if (text.length >= columns) {
      return text.substring(0, columns);
    }
    if (!center) {
      return text;
    }
    final left = (columns - text.length) ~/ 2;
    return '${' ' * left}$text';
  }

  static String _repeat(String value, int count) => value * count;

  static String _asAscii(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      buffer.writeCharCode(rune <= 0x7F ? rune : 0x3F);
    }
    return buffer.toString();
  }

  static List<int> _encode(String value) => latin1.encode(_asAscii(value));
}
