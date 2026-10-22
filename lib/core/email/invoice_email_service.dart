/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.email
 * - File      : invoice_email_service.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Sends a committed receipt or a proforma to a customer through
 *               the administrator-configured SMTP relay. The operator chooses
 *               a plain-text body or an A4 PDF attachment. Credentials stay in
 *               the encrypted settings store and are never written to audit
 *               snapshots or logs.
 * </pre>
 */

import 'dart:async';

import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

import '../../data/models/terminal_settings.dart';
import '../printing/a4_receipt_pdf.dart';
import '../printing/esc_pos_printer.dart';
import '../utils/money.dart';

/// How the invoice is delivered in the message.
enum EmailDelivery { attachment, text }

/// One operator request from the email dialog.
class EmailRequest {
  const EmailRequest({required this.recipient, required this.delivery});

  final String recipient;
  final EmailDelivery delivery;
}

/// Raised when SMTP settings are incomplete or the server rejects the message.
class EmailConfigurationException implements Exception {
  const EmailConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// SMTP gateway for receipt/proforma delivery.
class InvoiceEmailService {
  const InvoiceEmailService({
    required this.settings,
    this.timeout = const Duration(seconds: 25),
  });

  final TerminalSettings settings;
  final Duration timeout;

  /// Validates the operator input without contacting the server.
  static bool isValidAddress(String value) {
    final address = value.trim();
    final at = address.indexOf('@');
    return at > 0 &&
        at < address.length - 1 &&
        !address.contains(' ') &&
        address.substring(at + 1).contains('.');
  }

  Future<void> send({
    required ReceiptDocument document,
    required EmailRequest request,
  }) async {
    if (!settings.emailConfigured) {
      throw const EmailConfigurationException(
        'Email is not configured in Settings.',
      );
    }
    if (!isValidAddress(request.recipient)) {
      throw const EmailConfigurationException(
        'Enter a valid recipient email address.',
      );
    }

    final message = mailer.Message()
      ..from = mailer.Address(
        settings.emailFromAddress.trim(),
        settings.emailFromName.trim().isEmpty
            ? null
            : settings.emailFromName.trim(),
      )
      ..recipients.add(request.recipient.trim())
      ..subject =
          '${document.documentTitle} ${document.invoiceNumber} - '
          '${document.storeName}'
      ..text = _body(document);

    if (request.delivery == EmailDelivery.attachment) {
      final bytes = await A4ReceiptPdfBuilder.build(document);
      message.attachments.add(
        mailer.StreamAttachment(
          Stream<List<int>>.value(bytes),
          'application/pdf',
          fileName: '${document.invoiceNumber}.pdf',
        ),
      );
    }

    final server = SmtpServer(
      settings.emailHost.trim(),
      port: settings.emailPort,
      username: settings.emailUsername.trim().isEmpty
          ? null
          : settings.emailUsername.trim(),
      password: settings.emailPassword.isEmpty ? null : settings.emailPassword,
      ssl: settings.emailUseSsl,
    );
    await mailer.send(message, server, timeout: timeout);
  }

  String _body(ReceiptDocument document) {
    final buffer = StringBuffer()
      ..writeln(document.storeName)
      ..writeln(document.documentTitle)
      ..writeln(document.invoiceNumber)
      ..writeln(_stamp(document.issuedAt));
    if (document.customerName != null) {
      buffer.writeln('Account: ${document.customerName}');
    }
    buffer.writeln();
    for (final item in document.lines) {
      buffer.writeln(
        '${item.quantity} x ${item.partName}'
        '${item.uomLabel.isEmpty ? '' : ' (${item.uomLabel})'}'
        '  ${Money.formatCents(item.lineTotalCents)}',
      );
    }
    buffer
      ..writeln()
      ..writeln('Subtotal: ${Money.formatCents(document.subtotalCents)}')
      ..writeln('VAT: ${Money.formatCents(document.taxCents)}');
    if (document.coreFeeCents > 0) {
      buffer.writeln(
        'Core deposits: ${Money.formatCents(document.coreFeeCents)}',
      );
    }
    buffer.writeln('TOTAL: ${Money.formatCents(document.totalCents)}');
    if (!document.isProforma) {
      buffer.writeln('Paid by: ${document.paymentMethod}');
    }
    if (document.footer != null && document.footer!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(document.footer);
    }
    return buffer.toString();
  }

  static String _stamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
