/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.register.widgets
 * - File      : receipt_print_dialog.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Preview and paper chooser shared by sales receipts and
 *               proformas. Thermal formats render the exact monochrome roll
 *               layout; A4 renders a paginated invoice preview before the PDF
 *               is handed to the platform print dialog.
 * </pre>
 */

import 'package:flutter/material.dart';

import '../../../core/printing/esc_pos_printer.dart';
import '../../../core/printing/receipt_paper.dart';
import '../../../core/utils/money.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Returns the chosen paper size, or null when the operator cancels.
class ReceiptPrintDialog extends StatefulWidget {
  const ReceiptPrintDialog({
    super.key,
    required this.document,
    this.initialPaper = ReceiptPaperSize.mm80,
  });

  final ReceiptDocument document;
  final ReceiptPaperSize initialPaper;

  @override
  State<ReceiptPrintDialog> createState() => _ReceiptPrintDialogState();
}

class _ReceiptPrintDialogState extends State<ReceiptPrintDialog> {
  late ReceiptPaperSize _paper = widget.initialPaper;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.print_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.printPreview)),
        ],
      ),
      content: SizedBox(
        width: 540,
        height: 420,
        child: Column(
          children: [
            SegmentedButton<ReceiptPaperSize>(
              segments: [
                ButtonSegment(
                  value: ReceiptPaperSize.a4,
                  label: Text(l10n.paperA4),
                  icon: const Icon(Icons.description_outlined, size: 16),
                ),
                ButtonSegment(
                  value: ReceiptPaperSize.mm80,
                  label: Text(l10n.paper80mm),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                ),
                ButtonSegment(
                  value: ReceiptPaperSize.mm58,
                  label: Text(l10n.paper58mm),
                  icon: const Icon(Icons.phone_android_rounded, size: 16),
                ),
              ],
              selected: {_paper},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _paper = selection.first);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _paper == ReceiptPaperSize.a4
                      ? _A4Preview(document: widget.document)
                      : _ThermalPreview(
                          document: widget.document,
                          paper: _paper,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_paper),
          icon: const Icon(Icons.print_rounded, size: 18),
          label: Text(l10n.printNow),
        ),
      ],
    );
  }
}

class _ThermalPreview extends StatelessWidget {
  const _ThermalPreview({required this.document, required this.paper});

  final ReceiptDocument document;
  final ReceiptPaperSize paper;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
            borderRadius: BorderRadius.circular(3),
          ),
          child: SelectableText(
            EscPosTicketBuilder.preview(document, paper: paper),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              height: 1.32,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ),
    );
  }
}

class _A4Preview extends StatelessWidget {
  const _A4Preview({required this.document});

  final ReceiptDocument document;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Center(
        child: Container(
          width: 390,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.storeName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          document.isProforma
                              ? 'PROFORMA INVOICE'
                              : 'SALES RECEIPT',
                          style: const TextStyle(
                            fontSize: 8,
                            letterSpacing: 1.2,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        document.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                      Text(
                        _stamp(document.issuedAt),
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFD1D5DB)),
              const SizedBox(height: 8),
              if (document.customerName != null) ...[
                Text(
                  'Account: ${document.customerName}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const _PreviewRow(
                description: 'Description',
                qty: 'Qty',
                amount: 'Amount',
                header: true,
              ),
              for (final line in document.lines)
                _PreviewRow(
                  description: line.uomLabel.isEmpty
                      ? line.partName
                      : '${line.partName} (${line.uomLabel})',
                  qty: '${line.quantity}',
                  amount: Money.formatCents(line.lineTotalCents),
                ),
              const Divider(height: 12, color: Color(0xFFD1D5DB)),
              _PreviewTotal(label: 'Subtotal', cents: document.subtotalCents),
              _PreviewTotal(label: 'VAT', cents: document.taxCents),
              if (document.coreFeeCents > 0)
                _PreviewTotal(
                  label: 'Core deposits',
                  cents: document.coreFeeCents,
                ),
              _PreviewTotal(
                label: 'TOTAL',
                cents: document.totalCents,
                bold: true,
              ),
              if (!document.isProforma)
                _PreviewTotal(
                  label: 'Paid by',
                  trailing: document.paymentMethod,
                ),
              if (document.footer != null) ...[
                const SizedBox(height: 12),
                Text(
                  document.footer!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 7.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        ),
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.description,
    required this.qty,
    required this.amount,
    this.header = false,
  });

  final String description;
  final String qty;
  final String amount;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: header ? 7.5 : 8,
      fontWeight: header ? FontWeight.w700 : FontWeight.w400,
      color: header ? const Color(0xFF6B7280) : const Color(0xFF111111),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: Text(description, style: style)),
          Expanded(
            flex: 1,
            child: Text(qty, textAlign: TextAlign.center, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(amount, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _PreviewTotal extends StatelessWidget {
  const _PreviewTotal({
    required this.label,
    this.cents,
    this.trailing,
    this.bold = false,
  });

  final String label;
  final int? cents;
  final String? trailing;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 10 : 8.5,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      color: const Color(0xFF111111),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            trailing ?? (cents == null ? '' : Money.formatCents(cents!)),
            style: style,
          ),
        ],
      ),
    );
  }
}
