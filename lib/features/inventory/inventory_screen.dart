/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.inventory
 * - File      : inventory_screen.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Inventory administration for products, prices, stock, and
 *               selling units. Every mutation goes through the repository so
 *               the stock ledger, sync outbox, and actor-attributed audit event
 *               commit atomically. Soft delete keeps historical invoice lines
 *               intact. Search is debounced to avoid hammering SQLite while
 *               typing.
 * </pre>
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/money.dart';
import '../../data/models/catalog_part.dart';
import '../../data/models/inventory_product.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Product registry with stock and UOM actions.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<InventoryProduct> _products = const <InventoryProduct>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _products = await widget.repository.listProducts(term: _search.text);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _load);
  }

  Future<void> _create() async {
    final draft = await showDialog<ProductDraft>(
      context: context,
      builder: (context) => const _ProductDialog(),
    );
    if (draft == null) {
      return;
    }
    try {
      await widget.repository.createProduct(draft);
      await _load();
      if (mounted) {
        _snack(AppLocalizations.of(context).productCreated);
      }
    } catch (error) {
      if (mounted) {
        _snack(error.toString(), error: true);
      }
    }
  }

  Future<void> _edit(InventoryProduct product) async {
    final draft = await showDialog<ProductDraft>(
      context: context,
      builder: (context) => _ProductDialog(product: product),
    );
    if (draft == null) {
      return;
    }
    try {
      await widget.repository.updateProduct(product.id, draft);
      await _load();
      if (mounted) {
        _snack(AppLocalizations.of(context).productUpdated);
      }
    } catch (error) {
      if (mounted) {
        _snack(error.toString(), error: true);
      }
    }
  }

  Future<void> _adjust(InventoryProduct product) async {
    final result = await showDialog<_Adjustment>(
      context: context,
      builder: (context) => _StockDialog(product: product),
    );
    if (result == null) {
      return;
    }
    try {
      await widget.repository.adjustStock(
        productId: product.id,
        qtyDelta: result.qtyDelta,
        reason: result.reason,
        binLocation: result.binLocation,
      );
      await _load();
      if (mounted) {
        _snack(AppLocalizations.of(context).stockAdjusted);
      }
    } catch (error) {
      if (mounted) {
        _snack(error.toString(), error: true);
      }
    }
  }

  Future<void> _units(InventoryProduct product) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _UnitsDialog(repository: widget.repository, product: product),
    );
    await _load();
  }

  Future<void> _delete(InventoryProduct product) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDeleteProduct),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.repository.softDeleteProduct(product.id);
    await _load();
    if (mounted) {
      _snack(l10n.deleted);
    }
  }

  void _snack(String message, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.errorContainer : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.inventoryTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.inventorySubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.addProduct),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: l10n.searchInventory,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: l10n.refresh,
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: SelectableText(
                      _error!,
                      style: TextStyle(color: scheme.error),
                    ),
                  )
                : _products.isEmpty
                ? Center(child: Text(l10n.noProducts))
                : ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return _ProductCard(
                        product: product,
                        onEdit: () => _edit(product),
                        onAdjust: () => _adjust(product),
                        onUnits: () => _units(product),
                        onDelete: () => _delete(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onAdjust,
    required this.onUnits,
    required this.onDelete,
  });

  final InventoryProduct product;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;
  final VoidCallback onUnits;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final out = product.stockOnHand <= 0;
    final stockColor = out
        ? scheme.error
        : product.isLowStock
        ? const Color(0xFFE0A100)
        : const Color(0xFF2E9E6B);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        product.sku,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (product.oemNumber != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            product.oemNumber!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    product.partName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        Money.formatCents(product.retailPriceCents),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.stockOnHand(product.stockOnHand),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: stockColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (product.isLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: stockColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            out ? l10n.noStock : l10n.lowStock,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: stockColor,
                            ),
                          ),
                        ),
                      if (product.uomOptions.isNotEmpty)
                        Text(
                          '${product.baseUnit} + ${product.uomOptions.length} ${l10n.sellingUnits.toLowerCase()}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.editProduct,
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'stock':
                    onAdjust();
                  case 'units':
                    onUnits();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined, size: 18),
                    title: Text(l10n.editProduct),
                  ),
                ),
                PopupMenuItem(
                  value: 'stock',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune_rounded, size: 18),
                    title: Text(l10n.adjustStock),
                  ),
                ),
                PopupMenuItem(
                  value: 'units',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.straighten_rounded, size: 18),
                    title: Text(l10n.sellingUnits),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: scheme.error,
                    ),
                    title: Text(l10n.delete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});

  final InventoryProduct? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final Map<String, TextEditingController> _fields;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _fields = {
      'sku': TextEditingController(text: p?.sku ?? ''),
      'name': TextEditingController(text: p?.partName ?? ''),
      'brand': TextEditingController(text: p?.brand ?? ''),
      'oem': TextEditingController(text: p?.oemNumber ?? ''),
      'retail': TextEditingController(
        text: p == null ? '' : (p.retailPriceCents / 100).toStringAsFixed(2),
      ),
      'trade': TextEditingController(
        text: p?.tradePriceCents == null
            ? ''
            : (p!.tradePriceCents! / 100).toStringAsFixed(2),
      ),
      'core': TextEditingController(
        text: p == null ? '0.00' : (p.coreFeeCents / 100).toStringAsFixed(2),
      ),
      'unit': TextEditingController(text: p?.baseUnit ?? 'EA'),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _cents(String key, {bool allowEmpty = false}) {
    final raw = _fields[key]!.text.trim().replaceAll(',', '.');
    if (raw.isEmpty && allowEmpty) {
      return null;
    }
    final value = double.tryParse(raw);
    return value == null || value < 0 ? null : (value * 100).round();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final sku = _fields['sku']!.text.trim();
    final name = _fields['name']!.text.trim();
    final retail = _cents('retail');
    final trade = _cents('trade', allowEmpty: true);
    final core = _cents('core');
    final unit = _fields['unit']!.text.trim().toUpperCase();
    if (sku.isEmpty || name.isEmpty || retail == null || core == null) {
      setState(() => _error = l10n.invalidNumber);
      return;
    }
    if (_fields['trade']!.text.trim().isNotEmpty && trade == null) {
      setState(() => _error = l10n.invalidNumber);
      return;
    }
    if (unit.isEmpty) {
      setState(() => _error = l10n.baseUnit);
      return;
    }
    Navigator.of(context).pop(
      ProductDraft(
        sku: sku,
        partName: name,
        brand: _blank(_fields['brand']!.text),
        oemNumber: _blank(_fields['oem']!.text),
        retailPriceCents: retail,
        tradePriceCents: trade,
        coreFeeCents: core,
        baseUnit: unit,
      ),
    );
  }

  String? _blank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.product == null ? l10n.addProduct : l10n.editProduct),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _field('sku', l10n.sku)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('oem', 'OEM')),
                ],
              ),
              const SizedBox(height: 10),
              _field('name', l10n.description),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field('brand', l10n.brand)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('unit', l10n.baseUnit)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field('retail', l10n.retailPrice)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('trade', l10n.tradePrice)),
                ],
              ),
              const SizedBox(height: 10),
              _field('core', l10n.coreFee),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }

  Widget _field(String key, String label) {
    return TextField(
      controller: _fields[key],
      keyboardType: const <String>{'retail', 'trade', 'core'}.contains(key)
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

class _Adjustment {
  const _Adjustment({
    required this.qtyDelta,
    required this.reason,
    required this.binLocation,
  });

  final int qtyDelta;
  final String reason;
  final String binLocation;
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.product});

  final InventoryProduct product;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final TextEditingController _qty = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _bin = TextEditingController(text: 'BACK');
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    _bin.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final qty = int.tryParse(_qty.text.trim());
    final reason = _reason.text.trim();
    if (qty == null || qty == 0 || reason.isEmpty) {
      setState(() => _error = l10n.invalidNumber);
      return;
    }
    Navigator.of(context).pop(
      _Adjustment(
        qtyDelta: qty,
        reason: reason,
        binLocation: _bin.text.trim().isEmpty ? 'BACK' : _bin.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.stockAdjustment),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.product.partName} · ${l10n.stockOnHand(widget.product.stockOnHand)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _qty,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              decoration: InputDecoration(
                labelText: l10n.quantityDelta,
                helperText: 'Use a negative number for shrinkage.',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              decoration: InputDecoration(labelText: l10n.adjustmentReason),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bin,
              decoration: InputDecoration(labelText: l10n.binLocation),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

class _UnitsDialog extends StatefulWidget {
  const _UnitsDialog({required this.repository, required this.product});

  final InventoryRepository repository;
  final InventoryProduct product;

  @override
  State<_UnitsDialog> createState() => _UnitsDialogState();
}

class _UnitsDialogState extends State<_UnitsDialog> {
  late List<UomOption> _units;
  final TextEditingController _label = TextEditingController();
  final TextEditingController _factor = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _units = List<UomOption>.from(widget.product.uomOptions);
  }

  @override
  void dispose() {
    _label.dispose();
    _factor.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final label = _label.text.trim().toUpperCase();
    final factor = int.tryParse(_factor.text.trim());
    if (label.isEmpty || factor == null || factor < 2) {
      setState(() => _error = l10n.invalidNumber);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveUom(
        productId: widget.product.id,
        fromUnit: label,
        factor: factor,
      );
      final hydrated = await widget.repository.findProduct(widget.product.id);
      if (mounted) {
        setState(() {
          _units = List<UomOption>.from(hydrated?.uomOptions ?? const []);
          _label.clear();
          _factor.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove(UomOption unit) async {
    setState(() => _error = null);
    final removed = await widget.repository.removeUomByProductAndLabel(
      productId: widget.product.id,
      label: unit.label,
    );
    if (!removed) {
      if (mounted) {
        setState(() => _error = 'Selling unit could not be removed.');
      }
      return;
    }
    final hydrated = await widget.repository.findProduct(widget.product.id);
    if (mounted) {
      setState(() {
        _units = List<UomOption>.from(hydrated?.uomOptions ?? const []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.sellingUnits),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.product.partName} · base ${widget.product.baseUnit}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (_units.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.noProducts),
              )
            else
              for (final unit in _units)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(unit.label),
                  subtitle: Text(
                    '1 ${unit.label} = ${unit.factor} ${widget.product.baseUnit}',
                  ),
                  trailing: IconButton(
                    tooltip: l10n.removeUnit,
                    onPressed: _busy ? null : () => _remove(unit),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _label,
                    decoration: InputDecoration(
                      labelText: l10n.unitLabel,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _factor,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.conversionFactor,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l10n.addUnit,
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
