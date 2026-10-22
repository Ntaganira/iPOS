/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.register.widgets
 * - File      : email_invoice_dialog.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Recipient and delivery picker used after a sale and for
 *               proformas. Validation happens before the dialog closes so the
 *               operator can correct a mistyped address without losing the
 *               cart or re-entering the message.
 * </pre>
 */

import 'package:flutter/material.dart';

import '../../../core/email/invoice_email_service.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Returns the delivery request, or null when cancelled.
class EmailInvoiceDialog extends StatefulWidget {
  const EmailInvoiceDialog({
    super.key,
    required this.documentTitle,
    required this.reference,
  });

  final String documentTitle;
  final String reference;

  @override
  State<EmailInvoiceDialog> createState() => _EmailInvoiceDialogState();
}

class _EmailInvoiceDialogState extends State<EmailInvoiceDialog> {
  final TextEditingController _recipient = TextEditingController();
  EmailDelivery _delivery = EmailDelivery.attachment;
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final recipient = _recipient.text.trim();
    if (!InvoiceEmailService.isValidAddress(recipient)) {
      setState(() => _error = l10n.emailInvalid);
      return;
    }
    Navigator.of(
      context,
    ).pop(EmailRequest(recipient: recipient, delivery: _delivery));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.outgoing_mail, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.emailInvoice)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.documentTitle} ${widget.reference}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _recipient,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.emailRecipient,
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.emailDelivery.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<EmailDelivery>(
              segments: [
                ButtonSegment(
                  value: EmailDelivery.attachment,
                  label: Text(l10n.emailPdfAttachment),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                ),
                ButtonSegment(
                  value: EmailDelivery.text,
                  label: Text(l10n.emailPlainText),
                  icon: const Icon(Icons.notes_rounded, size: 16),
                ),
              ],
              selected: {_delivery},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _delivery = selection.first);
              },
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
          onPressed: _submit,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(l10n.sendEmail),
        ),
      ],
    );
  }
}
