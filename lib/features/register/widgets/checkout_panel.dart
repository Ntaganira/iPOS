/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.features.register.widgets
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

import '../../../core/theme/app_layout.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/cart_line.dart';
import '../../../data/models/customer_option.dart';
import '../../../data/repositories/checkout_repository.dart';
import '../checkout_controller.dart';

/// Persistent/drawer checkout surface.
class CheckoutPanel extends StatefulWidget {
  const CheckoutPanel({
    super.key,
    required this.controller,
    this.onClose,
  });

  final CheckoutController controller;
  final VoidCallback? onClose;

  @override
  State<CheckoutPanel> createState() => _CheckoutPanelState();
}

class _CheckoutPanelState extends State<CheckoutPanel> {
  Future<void> _charge() async {
    final result = await widget.controller.completeSale();
    if (!mounted || result == null) {
      return;
    }
    await _showReceipt(result);
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
        );
      },
    );
  }

  Future<void> _showReceipt(CheckoutResult result) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          color: scheme.primary,
          size: 36,
        ),
        title: const Text('Sale completed'),
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
              'Saved to the encrypted local ledger. Invoice lines and stock '
              'movements were committed together.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('New sale'),
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
              // fit a sticky header/customer/footer stack. In that case the
              // entire checkout scrolls instead of producing a RenderFlex
              // overflow; taller counters keep the charge action pinned.
              if (constraints.maxHeight < 620) {
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
                Text('Checkout', style: theme.textTheme.titleMedium),
                Text(
                  '$itemCount unit${itemCount == 1 ? '' : 's'} · '
                  '$lineCount line${lineCount == 1 ? '' : 's'}',
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
            tooltip: 'Clear cart',
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
              tooltip: 'Close checkout',
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CUSTOMER ACCOUNT',
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
                  const DropdownMenuItem<CustomerOption?>(
                    value: null,
                    child: Text('Walk-in customer'),
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
              'Cart is empty',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan a part, press Enter for an unambiguous match, or tap a '
              'catalog row to begin.',
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
  });

  final CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                tooltip: 'Remove line',
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
              Text(
                '${Money.formatCents(line.part.retailPriceCents)} each',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _QuantityStepper(
                quantity: line.quantity,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
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
            tooltip: quantity <= 1 ? 'Remove line' : 'Decrease quantity',
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
            tooltip: 'Increase quantity',
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
  });

  final CheckoutController controller;
  final VoidCallback onCharge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
            label: 'Subtotal',
            amountCents: controller.subtotalCents,
          ),
          const SizedBox(height: 3),
          _AmountRow(
            label:
                'VAT ${Money.percentLabel(CheckoutController.taxRateBps)}',
            amountCents: controller.taxCents,
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'TOTAL',
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
            'PAYMENT',
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
                         const Text('Charge'),
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
            'Offline commit · invoice + lines + stock ledger are atomic',
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
      label: Text(method.label),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
      ),
    );
  }
}
