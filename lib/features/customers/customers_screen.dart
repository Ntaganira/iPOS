/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.customers
 * - File      : customers_screen.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Trade-account directory. Creates, edits, searches, and
 *               tombstones customers while keeping cached receivables visible
 *               for counter context. Soft delete preserves historical invoices
 *               and every mutation is audited with actor and before/after
 *               snapshots by the repository.
 * </pre>
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/money.dart';
import '../../data/models/customer_account.dart';
import '../../data/repositories/customer_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Customer directory and editor.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.repository});

  final CustomerRepository repository;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<CustomerAccount> _customers = const <CustomerAccount>[];
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
      _customers = await widget.repository.list(term: _search.text);
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
    final draft = await showDialog<CustomerDraft>(
      context: context,
      builder: (context) => const _CustomerDialog(),
    );
    if (draft == null) {
      return;
    }
    try {
      await widget.repository.create(draft);
      await _load();
      if (mounted) {
        _snack(AppLocalizations.of(context).customerCreated);
      }
    } catch (error) {
      if (mounted) {
        _snack(error.toString(), error: true);
      }
    }
  }

  Future<void> _edit(CustomerAccount customer) async {
    final draft = await showDialog<CustomerDraft>(
      context: context,
      builder: (context) => _CustomerDialog(customer: customer),
    );
    if (draft == null) {
      return;
    }
    try {
      await widget.repository.update(customer.id, draft);
      await _load();
      if (mounted) {
        _snack(AppLocalizations.of(context).customerUpdated);
      }
    } catch (error) {
      if (mounted) {
        _snack(error.toString(), error: true);
      }
    }
  }

  Future<void> _delete(CustomerAccount customer) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDeleteCustomer),
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
    await widget.repository.softDelete(customer.id);
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
                      l10n.customersTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.customersSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(l10n.addCustomer),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: l10n.searchCustomers,
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
                : _customers.isEmpty
                ? Center(child: Text(l10n.noCustomers))
                : ListView.separated(
                    itemCount: _customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final customer = _customers[index];
                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: scheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              _initials(customer.displayName),
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            customer.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (customer.phone != null) customer.phone!,
                              if (customer.taxId != null)
                                '${l10n.taxId}: ${customer.taxId}',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    l10n.balance,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    Money.formatCents(customer.balanceCents),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: customer.balanceCents > 0
                                          ? const Color(0xFFE0A100)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                tooltip: l10n.editCustomer,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _edit(customer);
                                  } else {
                                    _delete(customer);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      title: Text(l10n.editCustomer),
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2));
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog({this.customer});

  final CustomerAccount? customer;

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _taxId;
  late final TextEditingController _balance;
  String? _error;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.displayName ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
    _taxId = TextEditingController(text: customer?.taxId ?? '');
    _balance = TextEditingController(
      text: customer == null
          ? '0.00'
          : (customer.balanceCents / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _taxId.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final balance = double.tryParse(_balance.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || balance == null || balance < 0) {
      setState(() => _error = l10n.invalidNumber);
      return;
    }
    Navigator.of(context).pop(
      CustomerDraft(
        displayName: name,
        phone: _blank(_phone.text),
        taxId: _blank(_taxId.text),
        balanceCents: (balance * 100).round(),
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
      title: Text(
        widget.customer == null ? l10n.addCustomer : l10n.editCustomer,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.customerName),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.phone),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _taxId,
                decoration: InputDecoration(labelText: l10n.taxId),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: InputDecoration(labelText: l10n.balance),
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
