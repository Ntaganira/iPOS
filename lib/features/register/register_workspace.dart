/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.register
 * - File      : register_workspace.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Center column of the POS: full-width scanner/search field,
 *               cascading YMM filters, virtualized catalog results, and a dense
 *               status strip. Desktop layouts autofocus search; F2 refocuses it
 *               from anywhere in the workspace; Enter resolves an unambiguous
 *               SKU/OEM match and drops it straight into the checkout cart.
 * </pre>
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_layout.dart';
import '../../core/utils/money.dart';
import '../../data/models/catalog_part.dart';
import 'catalog_controller.dart';
import 'checkout_controller.dart';
import 'widgets/catalog_table.dart';
import 'widgets/ymm_filter_bar.dart';

/// Center register workspace.
class RegisterWorkspace extends StatefulWidget {
  const RegisterWorkspace({
    super.key,
    required this.catalogController,
    required this.checkoutController,
    this.onOpenCheckout,
  });

  final CatalogController catalogController;
  final CheckoutController checkoutController;

  /// Non-null on tablet layouts where checkout lives in an end drawer.
  final VoidCallback? onOpenCheckout;

  @override
  State<RegisterWorkspace> createState() => _RegisterWorkspaceState();
}

class _RegisterWorkspaceState extends State<RegisterWorkspace> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.catalogController.query,
    );
    _searchFocusNode = FocusNode(debugLabel: 'catalogSearch');

    // Desktop counters expect the caret ready on launch. On phones/tablets we
    // do not steal the first frame with the soft keyboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (MediaQuery.sizeOf(context).width >=
          AppLayout.inlineCheckoutBreakpoint) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String value) async {
    final catalog = widget.catalogController;
    await catalog.submitQuery(value);
    if (!mounted || value.trim().isEmpty) {
      return;
    }

    final results = catalog.results;
    if (results.isEmpty) {
      return;
    }

    final exactMatches = results
        .where((part) => part.matchesNumber(value))
        .toList(growable: false);
    final CatalogPart? candidate = exactMatches.length == 1
        ? exactMatches.single
        : (results.length == 1 ? results.single : null);

    if (candidate != null) {
      _addPart(candidate);
    }
  }

  void _addPart(CatalogPart part) {
    widget.checkoutController.addPart(part);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text(
            '${part.partName} · ${Money.formatCents(part.retailPriceCents)} '
            'added',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          action: widget.onOpenCheckout == null
              ? null
              : SnackBarAction(
                  label: 'VIEW CART',
                  onPressed: widget.onOpenCheckout!,
                ),
        ),
      );
  }

  void _clearSearch() {
    _searchController.clear();
    widget.catalogController.setQuery('');
    setState(() {});
    _searchFocusNode.requestFocus();
  }

  Future<void> _resetAll() async {
    _searchController.clear();
    if (mounted) {
      setState(() {});
    }
    await widget.catalogController.resetAll();
    if (mounted) {
      _searchFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f2): () {
            _searchFocusNode.requestFocus();
            _searchController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _searchController.text.length,
            );
          },
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: widget.checkoutController,
              builder: (context, _) => _WorkspaceHeader(
                cartCount: widget.checkoutController.itemCount,
                onOpenCheckout: widget.onOpenCheckout,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(
                    AppLayout.panelRadius,
                  ),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ListenableBuilder(
                  listenable: widget.catalogController,
                  builder: (context, _) {
                    final catalog = widget.catalogController;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (value) {
                              widget.catalogController.setQuery(value);
                              setState(() {});
                            },
                            onSubmitted: (value) =>
                                unawaited(_handleSubmitted(value)),
                            textInputAction: TextInputAction.search,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText:
                                  'Scan or type SKU, OEM number, or part name…',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 19,
                              ),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: _clearSearch,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: YmmFilterBar(
                            makes: catalog.makes,
                            models: catalog.models,
                            years: catalog.years,
                            selectedMake: catalog.selectedMake,
                            selectedModel: catalog.selectedModel,
                            selectedYear: catalog.selectedYear,
                            hasActiveFilter: catalog.hasAnyFilter,
                            onMakeChanged: (value) => unawaited(
                              catalog.selectMake(value),
                            ),
                            onModelChanged: (value) => unawaited(
                              catalog.selectModel(value),
                            ),
                            onYearChanged: (value) =>
                                unawaited(catalog.selectYear(value)),
                            onReset: () => unawaited(_resetAll()),
                          ),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        Expanded(
                          child: CatalogTable(
                            results: catalog.results,
                            loading: catalog.loading,
                            error: catalog.error,
                            onAdd: _addPart,
                            onRetry: () => unawaited(catalog.refresh()),
                          ),
                        ),
                        _CatalogStatusBar(
                          resultCount: catalog.results.length,
                          loading: catalog.loading,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.cartCount,
    this.onOpenCheckout,
  });

  final int cartCount;
  final VoidCallback? onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Front Counter', style: theme.textTheme.titleLarge),
              const SizedBox(height: 1),
              Text(
                'Offline register · YMM fitment · encrypted local invoices',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onOpenCheckout != null) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onOpenCheckout,
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined, size: 18),
            ),
            label: const Text('Cart'),
          ),
        ],
      ],
    );
  }
}

/// Bottom strip with result count, local-only badge, and keyboard affordances.
class _CatalogStatusBar extends StatelessWidget {
  const _CatalogStatusBar({
    required this.resultCount,
    required this.loading,
  });

  final int resultCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Text(
                loading
                    ? 'Searching…'
                    : '$resultCount part${resultCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  'LOCAL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 9,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              if (constraints.maxWidth >= 600) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'F2 search · Enter adds top match',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
