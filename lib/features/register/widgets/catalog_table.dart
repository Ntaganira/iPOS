/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.register.widgets
 * - File      : catalog_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Dense, virtualized inline catalog table for the center
 *               workspace. Uses fixed-height rows and responsive column
 *               shedding instead of a horizontally scrolling DataTable, so
 *               hundreds of parts remain fast and the register never overflows
 *               on tablets. Rows are focusable and activate with Enter/Space.
 * </pre>
 */

import 'package:flutter/material.dart';

import '../../../core/theme/app_layout.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/catalog_part.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Virtualized catalog list with an aligned sticky header.
class CatalogTable extends StatefulWidget {
  const CatalogTable({
    super.key,
    required this.results,
    required this.loading,
    required this.error,
    required this.onAdd,
    required this.onRetry,
  });

  final List<CatalogPart> results;
  final bool loading;
  final String? error;
  final ValueChanged<CatalogPart> onAdd;
  final VoidCallback onRetry;

  @override
  State<CatalogTable> createState() => _CatalogTableState();
}

class _CatalogTableState extends State<CatalogTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSku = constraints.maxWidth >= 520;
        final showOem = constraints.maxWidth >= 720;

        return Column(
          children: [
            _CatalogHeader(showSku: showSku, showOem: showOem),
            if (widget.loading && widget.results.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _buildBody(context, showSku: showSku, showOem: showOem),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool showSku,
    required bool showOem,
  }) {
    final l10n = AppLocalizations.of(context);
    if (widget.loading && widget.results.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (widget.error != null && widget.results.isEmpty) {
      return _CatalogMessage(
        icon: Icons.storage_rounded,
        title: l10n.catalogUnavailable,
        message: widget.error!,
        actionLabel: l10n.retry,
        onAction: widget.onRetry,
        isError: true,
      );
    }

    if (widget.results.isEmpty) {
      return _CatalogMessage(
        icon: Icons.search_off_rounded,
        title: l10n.noMatchingParts,
        message: l10n.noMatchingPartsHint,
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemExtent: AppLayout.catalogRowHeight,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: widget.results.length,
        itemBuilder: (context, index) {
          final part = widget.results[index];
          return _CatalogRow(
            part: part,
            showSku: showSku,
            showOem: showOem,
            onAdd: () => widget.onAdd(part),
          );
        },
      ),
    );
  }
}

/// Sticky header mirroring the row flex weights exactly.
class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.showSku, required this.showOem});

  final bool showSku;
  final bool showOem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.8,
    );
    final partFlex = (showSku || showOem) ? 5 : 6;

    return Container(
      height: AppLayout.catalogHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (showSku) Expanded(flex: 2, child: Text('SKU', style: style)),
          if (showOem)
            Expanded(
              flex: 2,
              child: Text(l10n.oem.toUpperCase(), style: style),
            ),
          Expanded(
            flex: partFlex,
            child: Text(l10n.part.toUpperCase(), style: style),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(l10n.price.toUpperCase(), style: style),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// One 56 px interactive catalog row.
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.part,
    required this.showSku,
    required this.showOem,
    required this.onAdd,
  });

  final CatalogPart part;
  final bool showSku;
  final bool showOem;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final partFlex = (showSku || showOem) ? 5 : 6;
    final subtitle = showSku
        ? part.brandOrOem
        : '${part.sku} · ${part.brandOrOem}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: Row(
            children: [
              if (showSku)
                Expanded(
                  flex: 2,
                  child: Text(
                    part.sku,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (showOem)
                Expanded(
                  flex: 2,
                  child: Text(
                    part.oemNumber ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Expanded(
                flex: partFlex,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.partName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        Money.formatCents(part.retailPriceCents),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: AppLocalizations.of(context).addToCart,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared empty/error presentation for the body region.
class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = isError ? scheme.error : scheme.onSurfaceVariant;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: accent),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
