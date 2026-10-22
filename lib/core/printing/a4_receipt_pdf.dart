/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.printing
 * - File      : a4_receipt_pdf.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : A4 invoice/proforma renderer. Builds a paginated PDF from the
 *               same receipt snapshot used by the thermal roll, then hands it
 *               to the operating-system print dialog (which also provides the
 *               native print preview). No network is required to lay out the
 *               document.
 * </pre>
 */

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/money.dart';
import 'esc_pos_printer.dart';

/// Builds an A4 PDF for a sale receipt or proforma.
class A4ReceiptPdfBuilder {
  static Future<Uint8List> build(ReceiptDocument document) async {
    final pdf = pw.Document(
      title: '${document.documentTitle} ${document.invoiceNumber}',
      author: document.storeName,
    );
    final muted = PdfColor.fromInt(0xFF6B7280);
    final line = PdfColor.fromInt(0xFFD1D5DB);
    final ink = PdfColor.fromInt(0xFF111827);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 36),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            document.storeName,
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      document.storeName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      document.isProforma
                          ? 'PROFORMA INVOICE'
                          : 'SALES RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.6,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    document.invoiceNumber,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _stamp(document.issuedAt),
                    style: pw.TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Divider(color: line),
          pw.SizedBox(height: 10),
          if (document.customerName != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'Account: ${document.customerName}',
                style: pw.TextStyle(fontSize: 10, color: ink),
              ),
            ),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(6),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: line, width: 0.5),
              bottom: pw.BorderSide(color: line, width: 0.8),
            ),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF3F4F6),
                ),
                children: [
                  _cell('Description', muted, bold: true),
                  _cell('Qty', muted, bold: true, align: pw.TextAlign.center),
                  _cell('Unit', muted, bold: true, align: pw.TextAlign.right),
                  _cell('Amount', muted, bold: true, align: pw.TextAlign.right),
                ],
              ),
              for (final item in document.lines)
                pw.TableRow(
                  children: [
                    _cell(
                      item.uomLabel.isEmpty
                          ? item.partName
                          : '${item.partName}\n${item.uomLabel}',
                      ink,
                    ),
                    _cell('${item.quantity}', ink, align: pw.TextAlign.center),
                    _cell(
                      Money.formatCents(item.unitPriceCents),
                      ink,
                      align: pw.TextAlign.right,
                    ),
                    _cell(
                      Money.formatCents(item.lineTotalCents),
                      ink,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 210,
                child: pw.Column(
                  children: [
                    _totalRow('Subtotal', document.subtotalCents, muted),
                    _totalRow('VAT', document.taxCents, muted),
                    if (document.coreFeeCents > 0)
                      _totalRow('Core deposits', document.coreFeeCents, muted),
                    pw.Divider(color: line),
                    _totalRow(
                      'TOTAL',
                      document.totalCents,
                      ink,
                      bold: true,
                      size: 13,
                    ),
                    if (!document.isProforma) ...[
                      pw.SizedBox(height: 4),
                      _totalRow(
                        'Paid by',
                        null,
                        muted,
                        trailing: document.paymentMethod,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (document.footer != null &&
              document.footer!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 22),
            pw.Center(
              child: pw.Text(
                document.footer!,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _cell(
    String value,
    PdfColor color, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    int? cents,
    PdfColor color, {
    bool bold = false,
    double size = 10,
    String? trailing,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: size,
                color: color,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            trailing ?? (cents == null ? '' : Money.formatCents(cents)),
            style: pw.TextStyle(
              fontSize: size,
              color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static String _stamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// Sends an A4 PDF to the platform print/preview dialog.
class A4ReceiptPrinter {
  const A4ReceiptPrinter();

  Future<void> print(ReceiptDocument document) async {
    final bytes = await A4ReceiptPdfBuilder.build(document);
    await Printing.layoutPdf(
      name: '${document.invoiceNumber}.pdf',
      onLayout: (_) async => bytes,
    );
  }
}
