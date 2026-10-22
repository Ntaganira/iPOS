/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : settings_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Persists terminal preferences in the encrypted database. The
 *               terminal UUID is generated once and never reused across
 *               installations. Reads merge defaults for forward compatibility;
 *               writes are upserts so older builds can add new keys without a
 *               migration.
 * </pre>
 */

import 'package:uuid/uuid.dart';

import '../../core/printing/receipt_paper.dart';
import '../database/app_database.dart';
import '../models/terminal_settings.dart';
import 'audit_repository.dart';

/// Encrypted key/value settings gateway.
class SettingsRepository {
  SettingsRepository(this._database, {AuditActor? Function()? actorProvider})
    : _audit = AuditRepository(_database, actorProvider: actorProvider);

  static const String _deviceIdKey = 'terminal.device_id';
  static const String _storeNameKey = 'store.name';
  static const String _taxRateKey = 'tax.rate_bps';
  static const String _scannerMinKey = 'scanner.min_length';
  static const String _scannerTimeoutKey = 'scanner.timeout_ms';
  static const String _searchHotkeyKey = 'hotkey.search';
  static const String _checkoutHotkeyKey = 'hotkey.checkout';
  static const String _printerHostKey = 'printer.host';
  static const String _printerPortKey = 'printer.port';
  static const String _printerPaperKey = 'printer.paper';
  static const String _emailHostKey = 'email.host';
  static const String _emailPortKey = 'email.port';
  static const String _emailUsernameKey = 'email.username';
  static const String _emailPasswordKey = 'email.password';
  static const String _emailFromAddressKey = 'email.from_address';
  static const String _emailFromNameKey = 'email.from_name';
  static const String _emailSslKey = 'email.ssl';
  static const String _syncEndpointKey = 'sync.endpoint';
  static const String _syncTokenKey = 'sync.token';
  static const String _darkModeKey = 'theme.dark';
  static const String _languageKey = 'ui.language';

  final AppDatabase _database;
  final AuditRepository _audit;
  final Uuid _uuid = Uuid();

  Future<TerminalSettings> load() async {
    final rows = await _database.select(_database.appSettings).get();
    final values = <String, String>{
      for (final row in rows) row.settingKey: row.settingValue,
    };

    var deviceId = values[_deviceIdKey];
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = _uuid.v4();
      await _write(_deviceIdKey, deviceId);
    }

    return TerminalSettings(
      deviceId: deviceId,
      storeName:
          values[_storeNameKey] ??
          const TerminalSettings(deviceId: '').storeName,
      taxRateBps: _readInt(values[_taxRateKey], 1800),
      scannerMinLength: _readInt(
        values[_scannerMinKey],
        4,
      ).clamp(1, 64).toInt(),
      scannerTimeoutMs: _readInt(
        values[_scannerTimeoutKey],
        80,
      ).clamp(10, 2000).toInt(),
      searchHotkey: values[_searchHotkeyKey] ?? 'F2',
      checkoutHotkey: values[_checkoutHotkeyKey] ?? 'F3',
      printerHost: values[_printerHostKey] ?? '',
      printerPort: _readInt(
        values[_printerPortKey],
        9100,
      ).clamp(1, 65535).toInt(),
      receiptPaper: ReceiptPaperSize.fromId(values[_printerPaperKey]),
      emailHost: values[_emailHostKey] ?? '',
      emailPort: _readInt(values[_emailPortKey], 587).clamp(1, 65535).toInt(),
      emailUsername: values[_emailUsernameKey] ?? '',
      emailPassword: values[_emailPasswordKey] ?? '',
      emailFromAddress: values[_emailFromAddressKey] ?? '',
      emailFromName: values[_emailFromNameKey] ?? '',
      emailUseSsl: (values[_emailSslKey] ?? 'false') == 'true',
      syncEndpoint: values[_syncEndpointKey] ?? '',
      syncToken: values[_syncTokenKey] ?? '',
      darkMode: (values[_darkModeKey] ?? 'true') == 'true',
      languageCode: _readLanguage(values[_languageKey]),
    );
  }

  /// Saves all values atomically and audits the change without recording the
  /// sync token or other credential values.
  Future<void> save(TerminalSettings settings) async {
    await _database.transaction(() async {
      final before = await load();
      await _write(_storeNameKey, settings.storeName);
      await _write(_taxRateKey, '${settings.taxRateBps}');
      await _write(_scannerMinKey, '${settings.scannerMinLength}');
      await _write(_scannerTimeoutKey, '${settings.scannerTimeoutMs}');
      await _write(_searchHotkeyKey, settings.searchHotkey);
      await _write(_checkoutHotkeyKey, settings.checkoutHotkey);
      await _write(_printerHostKey, settings.printerHost);
      await _write(_printerPortKey, '${settings.printerPort}');
      await _write(_printerPaperKey, settings.receiptPaper.id);
      await _write(_emailHostKey, settings.emailHost);
      await _write(_emailPortKey, '${settings.emailPort}');
      await _write(_emailUsernameKey, settings.emailUsername);
      await _write(_emailPasswordKey, settings.emailPassword);
      await _write(_emailFromAddressKey, settings.emailFromAddress);
      await _write(_emailFromNameKey, settings.emailFromName);
      await _write(_emailSslKey, '${settings.emailUseSsl}');
      await _write(_syncEndpointKey, settings.syncEndpoint);
      await _write(_syncTokenKey, settings.syncToken);
      await _write(_darkModeKey, '${settings.darkMode}');
      await _write(_languageKey, settings.languageCode);

      await _audit.append(
        eventType: 'settings.updated',
        action: 'update',
        message: 'Terminal settings were updated.',
        before: _snapshot(before),
        after: _snapshot(settings),
      );
    });
  }

  Future<void> _write(String key, String value) async {
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            settingKey: key,
            settingValue: value,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  int _readInt(String? raw, int fallback) =>
      int.tryParse(raw ?? '') ?? fallback;

  Map<String, Object?> _snapshot(TerminalSettings settings) {
    return <String, Object?>{
      'store_name': settings.storeName,
      'tax_rate_bps': settings.taxRateBps,
      'printer_host': settings.printerHost,
      'printer_port': settings.printerPort,
      'receipt_paper': settings.receiptPaper.id,
      'email_host': settings.emailHost,
      'email_port': settings.emailPort,
      'email_from_address': settings.emailFromAddress,
      'email_from_name': settings.emailFromName,
      'email_ssl': settings.emailUseSsl,
      'email_configured': settings.emailConfigured,
      'printer_configured': settings.printerConfigured,
      'sync_endpoint': settings.syncEndpoint,
      'sync_configured': settings.syncConfigured,
      'scanner_min_length': settings.scannerMinLength,
      'scanner_timeout_ms': settings.scannerTimeoutMs,
      'search_hotkey': settings.searchHotkey,
      'checkout_hotkey': settings.checkoutHotkey,
      'dark_mode': settings.darkMode,
      'language': settings.languageCode,
    };
  }

  String _readLanguage(String? raw) {
    const supported = <String>{'en', 'fr', 'rw'};
    final normalized = raw?.trim().toLowerCase();
    return supported.contains(normalized) ? normalized! : 'en';
  }
}
