/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.register.widgets
 * - File      : checkout_panel.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Right-hand active sale panel. Hosts the customer account
 *               selector, dense cart lines with quantity controls, integer VAT
 *               totals, payment-method triggers, and the atomic charge action.
 *               The same widget is reused inline on desktop and inside an end
 *               drawer on tablets, so the checkout workflow is identical at
 *               every width. A receipt dialog confirms the locally committed
 *               invoice number and total.
 * </pre>
 */

import 'package:flutter/material.dart';

import '../../../core/email/invoice_email_service.dart';
import '../../../core/printing/esc_pos_printer.dart';
import '../../../core/printing/receipt_factory.dart';
import '../../../core/printing/receipt_paper.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/cart_line.dart';
import '../../../data/models/catalog_part.dart';
import '../../../data/models/customer_option.dart';
import '../../../data/repositories/checkout_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../checkout_controller.dart';
import 'email_invoice_dialog.dart';
import 'receipt_print_dialog.dart';

/// Persistent/drawer checkout surface.
class CheckoutPanel extends StatefulWidget {
  const CheckoutPanel({
    super.key,
    required this.controller,
    this.onClose,
    this.onPrint,
    this.onEmail,
    this.storeName = 'iPOS Parts Counter',
    this.defaultPaper = ReceiptPaperSize.mm80,
  });

  final CheckoutController controller;
  final VoidCallback? onClose;

  /// Optional printer transport. Receives a previewed document and the chosen
  /// paper format; printing only happens after the local commit succeeded.
  final Future<void> Function(ReceiptDocument document, ReceiptPaperSize paper)?
  onPrint;

  /// Optional SMTP delivery. Receives the previewed document and the operator's
  /// recipient/format choice.
  final Future<void> Function(ReceiptDocument document, EmailRequest request)?
  onEmail;

  /// Printed store identity, also used for proforma output.
  final String storeName;

  /// Last paper choice from terminal settings.
  final ReceiptPaperSize defaultPaper;

  @override
  State<CheckoutPanel> createState() => _CheckoutPanelState();
}

class _CheckoutPanelState extends State<CheckoutPanel> {
  Future<void> _charge() async {
    final result = await widget.controller.completeSale();
    if (!mounted || result == null) {
      return;
    }
    final action = await _showReceipt(result);
    if (!mounted || action == null || action == _ReceiptAction.close) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final document = ReceiptDocument.fromCheckout(
      storeName: widget.storeName,
      result: result,
    );
    if (action == _ReceiptAction.print) {
      await _previewAndPrint(
        document,
        successMessage: l10n.receiptPrinted,
        failureMessage: l10n.printFailed,
      );
    } else {
      await _emailDocument(
        document,
        successMessage: l10n.emailSent,
        failureMessage: l10n.emailFailed,
      );
    }
  }

  Future<void> _emailProforma() async {
    if (widget.onEmail == null || widget.controller.lines.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final document = buildProformaDocument(
      storeName: widget.storeName,
      lines: widget.controller.lines,
      taxRateBps: widget.controller.taxRateBps,
      customer: widget.controller.selectedCustomer,
    );
    await _emailDocument(
      document,
      successMessage: l10n.emailSentProforma,
      failureMessage: l10n.emailFailed,
    );
  }

  Future<void> _printProforma() async {
    if (widget.onPrint == null || widget.controller.lines.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final document = buildProformaDocument(
      storeName: widget.storeName,
      lines: widget.controller.lines,
      taxRateBps: widget.controller.taxRateBps,
      customer: widget.controller.selectedCustomer,
    );
    await _previewAndPrint(
      document,
      successMessage: l10n.proformaPrinted,
      failureMessage: l10n.proformaPrintFailed,
    );
  }

  Future<void> _emailDocument(
    ReceiptDocument document, {
    required String successMessage,
    required String failureMessage,
  }) async {
    final deliver = widget.onEmail;
    if (deliver == null) {
      return;
    }
    final request = await showDialog<EmailRequest>(
      context: context,
      builder: (dialogContext) => EmailInvoiceDialog(
        documentTitle: document.documentTitle,
        reference: document.invoiceNumber,
      ),
    );
    if (!mounted || request == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      await deliver(document, request);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on EmailConfigurationException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.emailNotConfigured)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    }
  }

  Future<void> _previewAndPrint(
    ReceiptDocument document, {
    required String successMessage,
    required String failureMessage,
  }) async {
    final print = widget.onPrint;
    if (print == null) {
      return;
    }
    final paper = await showDialog<ReceiptPaperSize>(
      context: context,
      builder: (dialogContext) => ReceiptPrintDialog(
        document: document,
        initialPaper: widget.defaultPaper,
      ),
    );
    if (!mounted || paper == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      await print(document, paper);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on StateError {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.printingUnavailable)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    }
  }

  /// Cart lines are the only flexible region. In the pinned layout they fill
  /// the remaining height; in the short-window layout they shrink-wrap inside
  /// the outer scroll view.
  Widget _buildCartLines(
    CheckoutController controller, {
    required bool shrinkWrap,
  }) {
    if (controller.lines.isEmpty) {
      return shrinkWrap
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 140),
              child: const _EmptyCart(),
            )
          : const _EmptyCart();
    }

    return ListView.separated(
      primary: false,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: controller.lines.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
      itemBuilder: (context, index) {
        final line = controller.lines[index];
        return _CartLineTile(
          line: line,
          onIncrement: () => controller.incrementLine(line.part.id),
          onDecrement: () => controller.decrementLine(line.part.id),
          onRemove: () => controller.removeLine(line.part.id),
          onUomChanged: (uom) => controller.setLineUom(line.part.id, uom),
        );
      },
    );
  }

  Future<_ReceiptAction?> _showReceipt(CheckoutResult result) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return showDialog<_ReceiptAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.check_circle_rounded, color: scheme.primary, size: 36),
        title: Text(l10n.saleCompleted),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.invoiceNumber,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              Money.formatCents(result.totalCents),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.saleSaved,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          if (widget.onEmail != null)
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_ReceiptAction.email),
              icon: const Icon(Icons.outgoing_mail, size: 18),
              label: Text(l10n.emailInvoice),
            ),
          if (widget.onPrint != null)
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_ReceiptAction.print),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: Text(l10n.printReceipt),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ReceiptAction.close),
            child: Text(l10n.newSale),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final controller = widget.controller;

        final header = _CheckoutHeader(
          itemCount: controller.itemCount,
          lineCount: controller.lines.length,
          canClear: controller.lines.isNotEmpty && !controller.submitting,
          onClear: controller.clearCart,
          onClose: widget.onClose,
        );
        final customer = _CustomerSelector(controller: controller);
        final footer = _CheckoutFooter(
          controller: controller,
          onCharge: _charge,
          onProforma: widget.onPrint == null ? null : _printProforma,
          onEmailProforma: widget.onEmail == null ? null : _emailProforma,
        );

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppLayout.panelRadius),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Short windows (phone landscape, split-screen tablets) cannot
              // fit a sticky header/customer/footer stack. Large text scales
              // the same stack, so the threshold scales with it. In that case
              // the entire checkout scrolls instead of producing a RenderFlex
              // overflow; taller counters keep the charge action pinned.
              final textScale = MediaQuery.textScalerOf(
                context,
              ).scale(1.0).clamp(1.0, 2.0);
              if (constraints.maxHeight < 620 * textScale) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      header,
                      Divider(height: 1, color: scheme.outlineVariant),
                      customer,
                      Divider(height: 1, color: scheme.outlineVariant),
                      _buildCartLines(controller, shrinkWrap: true),
                      Divider(height: 1, color: scheme.outlineVariant),
                      footer,
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  header,
                  Divider(height: 1, color: scheme.outlineVariant),
                  customer,
                  Divider(height: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: _buildCartLines(controller, shrinkWrap: false),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  footer,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader({
    required this.itemCount,
    required this.lineCount,
    required this.canClear,
    required this.onClear,
    this.onClose,
  });

  final int itemCount;
  final int lineCount;
  final bool canClear;
  final VoidCallback onClear;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.checkoutTitle, style: theme.textTheme.titleMedium),
                Text(
                  l10n.unitsLines(itemCount, lineCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.clearCart,
            onPressed: canClear ? onClear : null,
            icon: const Icon(Icons.delete_sweep_outlined, size: 19),
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: l10n.closeCheckout,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 19),
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

/// Account selector. Null corresponds to an anonymous walk-in sale.
class _CustomerSelector extends StatelessWidget {
  const _CustomerSelector({required this.controller});

  final CheckoutController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.customerAccount.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CustomerOption?>(
                value: controller.selectedCustomer,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(10),
                dropdownColor: scheme.surfaceContainerHigh,
                icon: Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                onChanged: controller.loadingCustomers
                    ? null
                    : controller.selectCustomer,
                items: [
                  DropdownMenuItem<CustomerOption?>(
                    value: null,
                    child: Text(l10n.walkInCustomer),
                  ),
                  for (final customer in controller.customers)
                    DropdownMenuItem<CustomerOption?>(
                      value: customer,
                      child: Text(
                        customer.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (controller.loadingCustomers) ...[
            const SizedBox(height: 5),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 30,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.cartEmpty,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.cartHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onUomChanged,
  });

  final CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final ValueChanged<UomOption> onUomChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  line.part.partName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.removeLine,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 16),
                style: IconButton.styleFrom(
                  minimumSize: const Size(26, 26),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${line.part.sku} · ${line.part.brandOrOem}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${Money.formatCents(line.part.retailPriceCents)} / '
                  '${line.uom.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (line.coreFeeCents > 0) ...[
            const SizedBox(height: 2),
            Text(
              l10n.coreIncluded(Money.formatCents(line.coreFeeCents)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.tertiary,
                fontSize: 10.5,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              _QuantityStepper(
                quantity: line.quantity,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
              const SizedBox(width: 6),
              _UomSelector(line: line, onChanged: onUomChanged),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      Money.formatCents(line.lineSubtotalCents),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UomSelector extends StatelessWidget {
  const _UomSelector({required this.line, required this.onChanged});

  final CartLine line;
  final ValueChanged<UomOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = line.part.sellingUnits;
    final label = line.uom.label;

    if (options.length < 2) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      );
    }

    return PopupMenuButton<UomOption>(
      tooltip: AppLocalizations.of(context).sellingUnit,
      initialValue: line.uom,
      onSelected: onChanged,
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem<UomOption>(
              value: option,
              child: Text(
                option.factor == 1
                    ? option.label
                    : '${option.label} (${option.factor} ${line.part.baseUnit})',
              ),
            ),
          )
          .toList(growable: false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            icon: Icons.remove_rounded,
            tooltip: quantity <= 1 ? l10n.removeLine : l10n.decreaseQuantity,
            onPressed: onDecrement,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add_rounded,
            tooltip: l10n.increaseQuantity,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      style: IconButton.styleFrom(
        minimumSize: const Size(27, 27),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({
    required this.controller,
    required this.onCharge,
    this.onProforma,
    this.onEmailProforma,
  });

  final CheckoutController controller;
  final VoidCallback onCharge;
  final Future<void> Function()? onProforma;
  final Future<void> Function()? onEmailProforma;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      controller.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _AmountRow(
            label: l10n.subtotal,
            amountCents: controller.subtotalCents,
          ),
          const SizedBox(height: 3),
          _AmountRow(
            label: l10n.vatRate(Money.percentLabel(controller.taxRateBps)),
            amountCents: controller.taxCents,
          ),
          if (controller.coreFeeCents > 0) ...[
            const SizedBox(height: 3),
            _AmountRow(
              label: l10n.coreDeposits,
              amountCents: controller.coreFeeCents,
            ),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                l10n.total.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      Money.formatCents(controller.totalCents),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.paymentMethod.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final method in PaymentMethod.values)
                _PaymentChip(
                  method: method,
                  selected: controller.paymentMethod == method,
                  onSelected: () => controller.setPaymentMethod(method),
                ),
            ],
          ),
          if (onProforma != null || onEmailProforma != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onProforma != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.canCheckout ? onProforma : null,
                      icon: const Icon(Icons.description_outlined, size: 17),
                      label: Text(
                        l10n.printProforma,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (onProforma != null && onEmailProforma != null)
                  const SizedBox(width: 6),
                if (onEmailProforma != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.canCheckout
                          ? onEmailProforma
                          : null,
                      icon: const Icon(Icons.outgoing_mail, size: 17),
                      label: Text(
                        l10n.emailProforma,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: controller.canCheckout ? onCharge : null,
              child: controller.submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      children: [
                        Text(l10n.charge),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                Money.formatCents(controller.totalCents),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.offlineCommit,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amountCents});

  final String label;
  final int amountCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                Money.formatCents(amountCents),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.method,
    required this.selected,
    required this.onSelected,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(_paymentLabel(AppLocalizations.of(context), method)),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surfaceContainerHigh,
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
    );
  }
}

String _paymentLabel(AppLocalizations l10n, PaymentMethod method) =>
    switch (method) {
      PaymentMethod.cash => l10n.cash,
      PaymentMethod.card => l10n.card,
      PaymentMethod.mobile => l10n.mobile,
    };

enum _ReceiptAction { close, print, email }
