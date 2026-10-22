/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.settings
 * - File      : settings_screen.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Permission-gated back-office hub. General settings cover store
 *               identity, language, appearance, VAT, scanner timing, hotkeys,
 *               printer transport, and sync credentials. Separate tabs expose
 *               user administration, the audit trail, and database maintenance
 *               only when the signed-in role holds the matching capability.
 *               Saves are audited by the repository and propagate theme, locale,
 *               and checkout VAT immediately.
 * </pre>
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/email/invoice_email_service.dart';
import '../../core/printing/receipt_paper.dart';
import '../../core/security/permissions.dart';
import '../../data/database/database_maintenance_service.dart';
import '../../data/models/terminal_settings.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../audit/audit_log_view.dart';
import '../auth/auth_controller.dart';
import '../users/users_roles_screen.dart';
import 'maintenance_view.dart';
import 'settings_controller.dart';

/// Back-office settings and administration.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authController,
    required this.auditRepository,
    required this.maintenance,
    required this.shifts,
    required this.onSettingsSaved,
    this.onSyncNow,
    this.onRotateKey,
  });

  final SettingsController controller;
  final AuthController authController;
  final AuditRepository auditRepository;
  final DatabaseMaintenanceService maintenance;
  final ShiftRepository shifts;
  final ValueChanged<TerminalSettings> onSettingsSaved;
  final Future<SyncRunResult> Function()? onSyncNow;
  final Future<void> Function()? onRotateKey;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _storeName;
  late final TextEditingController _taxRate;
  late final TextEditingController _scannerMin;
  late final TextEditingController _scannerTimeout;
  late final TextEditingController _searchHotkey;
  late final TextEditingController _checkoutHotkey;
  late final TextEditingController _printerHost;
  late final TextEditingController _printerPort;
  late final TextEditingController _syncEndpoint;
  late final TextEditingController _syncToken;
  late final TextEditingController _emailHost;
  late final TextEditingController _emailPort;
  late final TextEditingController _emailUsername;
  late final TextEditingController _emailPassword;
  late final TextEditingController _emailFromAddress;
  late final TextEditingController _emailFromName;
  late String _language;
  late bool _darkMode;
  late ReceiptPaperSize _receiptPaper;
  late bool _emailUseSsl;
  bool _showEmailPassword = false;
  bool _saving = false;
  bool _syncing = false;
  String? _error;

  TerminalSettings get _settings => widget.controller.settings;

  @override
  void initState() {
    super.initState();
    final s = _settings;
    _storeName = TextEditingController(text: s.storeName);
    _taxRate = TextEditingController(
      text: (s.taxRateBps / 100).toStringAsFixed(2),
    );
    _scannerMin = TextEditingController(text: '${s.scannerMinLength}');
    _scannerTimeout = TextEditingController(text: '${s.scannerTimeoutMs}');
    _searchHotkey = TextEditingController(text: s.searchHotkey);
    _checkoutHotkey = TextEditingController(text: s.checkoutHotkey);
    _printerHost = TextEditingController(text: s.printerHost);
    _printerPort = TextEditingController(text: '${s.printerPort}');
    _syncEndpoint = TextEditingController(text: s.syncEndpoint);
    _syncToken = TextEditingController(text: s.syncToken);
    _emailHost = TextEditingController(text: s.emailHost);
    _emailPort = TextEditingController(text: '${s.emailPort}');
    _emailUsername = TextEditingController(text: s.emailUsername);
    _emailPassword = TextEditingController(text: s.emailPassword);
    _emailFromAddress = TextEditingController(text: s.emailFromAddress);
    _emailFromName = TextEditingController(text: s.emailFromName);
    _language = s.languageCode;
    _darkMode = s.darkMode;
    _receiptPaper = s.receiptPaper;
    _emailUseSsl = s.emailUseSsl;
  }

  @override
  void dispose() {
    _storeName.dispose();
    _taxRate.dispose();
    _scannerMin.dispose();
    _scannerTimeout.dispose();
    _searchHotkey.dispose();
    _checkoutHotkey.dispose();
    _printerHost.dispose();
    _printerPort.dispose();
    _syncEndpoint.dispose();
    _syncToken.dispose();
    _emailHost.dispose();
    _emailPort.dispose();
    _emailUsername.dispose();
    _emailPassword.dispose();
    _emailFromAddress.dispose();
    _emailFromName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final tax = double.tryParse(_taxRate.text.replaceAll(',', '.'));
    final min = int.tryParse(_scannerMin.text);
    final timeout = int.tryParse(_scannerTimeout.text);
    final port = int.tryParse(_printerPort.text);
    final emailPort = int.tryParse(_emailPort.text) ?? 587;
    if (tax == null || tax < 0 || tax > 100) {
      setState(() => _error = l10n.taxRate);
      return;
    }
    if (min == null || min < 1 || min > 64) {
      setState(() => _error = l10n.scannerMinLength);
      return;
    }
    if (timeout == null || timeout < 10 || timeout > 2000) {
      setState(() => _error = l10n.scannerTimeout);
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = l10n.printerPort);
      return;
    }
    final emailHost = _emailHost.text.trim();
    final emailFrom = _emailFromAddress.text.trim();
    if (emailHost.isNotEmpty || emailFrom.isNotEmpty) {
      if (emailHost.isEmpty ||
          !InvoiceEmailService.isValidAddress(emailFrom) ||
          emailPort < 1 ||
          emailPort > 65535) {
        setState(() => _error = l10n.emailInvalid);
        return;
      }
    }

    final next = _settings.copyWith(
      storeName: _storeName.text.trim(),
      languageCode: _language,
      darkMode: _darkMode,
      taxRateBps: (tax * 100).round(),
      scannerMinLength: min,
      scannerTimeoutMs: timeout,
      searchHotkey: _searchHotkey.text.trim().toUpperCase(),
      checkoutHotkey: _checkoutHotkey.text.trim().toUpperCase(),
      printerHost: _printerHost.text.trim(),
      printerPort: port,
      receiptPaper: _receiptPaper,
      emailHost: emailHost,
      emailPort: emailPort,
      emailUsername: _emailUsername.text.trim(),
      emailPassword: _emailPassword.text,
      emailFromAddress: emailFrom,
      emailFromName: _emailFromName.text.trim(),
      emailUseSsl: _emailUseSsl,
      syncEndpoint: _syncEndpoint.text.trim(),
      syncToken: _syncToken.text.trim(),
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.controller.save(next);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (!ok) {
      setState(() => _error = widget.controller.error);
      return;
    }
    widget.onSettingsSaved(next);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
  }

  Future<void> _sync() async {
    final sync = widget.onSyncNow;
    if (sync == null || _syncing) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);
    try {
      await sync();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.syncComplete)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  String _paperLabel(AppLocalizations l10n, ReceiptPaperSize paper) {
    return switch (paper) {
      ReceiptPaperSize.a4 => l10n.paperA4,
      ReceiptPaperSize.mm80 => l10n.paper80mm,
      ReceiptPaperSize.mm58 => l10n.paper58mm,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = widget.authController.currentUser;
    final canSettings = user?.can(AppPermission.manageSettings) ?? false;
    final canUsers = user?.can(AppPermission.manageUsers) ?? false;
    final canAudit = user?.can(AppPermission.viewAudit) ?? false;
    final canMaintenance =
        (user?.can(AppPermission.manageBackup) ?? false) ||
        (user?.can(AppPermission.viewReports) ?? false);

    final tabs = <Tab>[
      if (canSettings)
        Tab(icon: const Icon(Icons.tune_rounded), text: l10n.settingsTitle),
      if (canSettings)
        Tab(
          icon: const Icon(Icons.alternate_email_rounded),
          text: l10n.emailSettings,
        ),
      if (canUsers)
        Tab(icon: const Icon(Icons.badge_outlined), text: l10n.usersTitle),
      if (canAudit)
        Tab(icon: const Icon(Icons.history_rounded), text: l10n.auditTitle),
      if (canMaintenance)
        Tab(
          icon: const Icon(Icons.storage_rounded),
          text: l10n.databaseMaintenance,
        ),
    ];
    final views = <Widget>[
      if (canSettings) _generalTab(l10n, theme, scheme),
      if (canSettings) _emailTab(l10n, theme, scheme),
      if (canUsers) UsersRolesScreen(authController: widget.authController),
      if (canAudit) AuditLogView(repository: widget.auditRepository),
      if (canMaintenance)
        MaintenanceView(
          maintenance: widget.maintenance,
          shifts: widget.shifts,
          canBackup: user?.can(AppPermission.manageBackup) ?? false,
          canCloseShift:
              (user?.can(AppPermission.viewReports) ?? false) ||
              (user?.can(AppPermission.sell) ?? false),
          canRotate: user?.can(AppPermission.rotateKeys) ?? false,
          onRotate: widget.onRotateKey,
        ),
    ];

    if (tabs.isEmpty) {
      return Center(child: Text(l10n.permissionDenied));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: scheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: tabs,
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }

  Widget _emailTab(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(
          l10n.emailSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: l10n.emailSettings,
          children: [
            TextField(
              controller: _emailHost,
              decoration: InputDecoration(
                labelText: l10n.emailHost,
                hintText: 'smtp.example.com',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailPort,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.emailPort),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      l10n.emailUseSsl,
                      style: theme.textTheme.bodySmall,
                    ),
                    value: _emailUseSsl,
                    onChanged: (value) {
                      setState(() => _emailUseSsl = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailUsername,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.emailUsername),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailPassword,
              obscureText: !_showEmailPassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.emailPassword,
                suffixIcon: IconButton(
                  tooltip: _showEmailPassword ? 'Hide' : 'Show',
                  icon: Icon(
                    _showEmailPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _showEmailPassword = !_showEmailPassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailFromAddress,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.emailFromAddress),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailFromName,
              decoration: InputDecoration(labelText: l10n.emailFromName),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.emailConfigNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(l10n.saveSettings),
        ),
      ],
    );
  }

  Widget _generalTab(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(
          l10n.settingsSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: l10n.storeName,
          children: [
            TextField(
              controller: _storeName,
              decoration: InputDecoration(labelText: l10n.storeName),
            ),
          ],
        ),
        _Section(
          title: l10n.appearance,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: InputDecoration(labelText: l10n.language),
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Text(l10n.languageEnglish),
                ),
                DropdownMenuItem(value: 'fr', child: Text(l10n.languageFrench)),
                DropdownMenuItem(
                  value: 'rw',
                  child: Text(l10n.languageKinyarwanda),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _language = value ?? _language),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.darkMode),
              value: _darkMode,
              onChanged: (value) => setState(() => _darkMode = value),
            ),
            TextField(
              controller: _taxRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.taxRate,
                suffixText: '%',
              ),
            ),
          ],
        ),
        _Section(
          title: l10n.scannerSettings,
          children: [
            TextField(
              controller: _scannerMin,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.scannerMinLength),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _scannerTimeout,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.scannerTimeout),
            ),
          ],
        ),
        _Section(
          title: l10n.hotkeys,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchHotkey,
                    decoration: InputDecoration(labelText: l10n.searchHotkey),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _checkoutHotkey,
                    decoration: InputDecoration(labelText: l10n.checkoutHotkey),
                  ),
                ),
              ],
            ),
          ],
        ),
        _Section(
          title: l10n.printerSettings,
          children: [
            TextField(
              controller: _printerHost,
              decoration: InputDecoration(labelText: l10n.printerHost),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _printerPort,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.printerPort),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ReceiptPaperSize>(
              initialValue: _receiptPaper,
              decoration: InputDecoration(labelText: l10n.receiptPaper),
              items: [
                for (final paper in ReceiptPaperSize.values)
                  DropdownMenuItem(
                    value: paper,
                    child: Text(_paperLabel(l10n, paper)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _receiptPaper = value);
                }
              },
            ),
          ],
        ),
        _Section(
          title: l10n.syncSettings,
          children: [
            TextField(
              controller: _syncEndpoint,
              decoration: InputDecoration(labelText: l10n.syncEndpoint),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _syncToken,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.syncToken),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onSyncNow == null || _syncing ? null : _sync,
              icon: _syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_rounded, size: 18),
              label: Text(l10n.syncNow),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(l10n.saveSettings),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
