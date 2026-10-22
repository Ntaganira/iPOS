/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : terminal_settings.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Immutable terminal configuration loaded from the encrypted
 *               settings registry. Covers store identity, VAT, scanner timing,
 *               hotkeys, receipt printer transport, sync endpoint, and theme.
 *               The sync token lives in the encrypted database and is never
 *               shown in logs or exported reports.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import '../../core/printing/receipt_paper.dart';

/// Terminal-level preferences.
@immutable
class TerminalSettings {
  const TerminalSettings({
    required this.deviceId,
    this.storeName = 'iPOS Parts Counter',
    this.taxRateBps = 1800,
    this.scannerMinLength = 4,
    this.scannerTimeoutMs = 80,
    this.searchHotkey = 'F2',
    this.checkoutHotkey = 'F3',
    this.printerHost = '',
    this.printerPort = 9100,
    this.receiptPaper = ReceiptPaperSize.mm80,
    this.emailHost = '',
    this.emailPort = 587,
    this.emailUsername = '',
    this.emailPassword = '',
    this.emailFromAddress = '',
    this.emailFromName = '',
    this.emailUseSsl = false,
    this.syncEndpoint = '',
    this.syncToken = '',
    this.darkMode = true,
    this.languageCode = 'en',
  });

  final String deviceId;
  final String storeName;
  final int taxRateBps;
  final int scannerMinLength;
  final int scannerTimeoutMs;
  final String searchHotkey;
  final String checkoutHotkey;
  final String printerHost;
  final int printerPort;
  final ReceiptPaperSize receiptPaper;
  final String emailHost;
  final int emailPort;
  final String emailUsername;
  final String emailPassword;
  final String emailFromAddress;
  final String emailFromName;
  final bool emailUseSsl;
  final String syncEndpoint;
  final String syncToken;
  final bool darkMode;
  final String languageCode;

  bool get printerConfigured => printerHost.trim().isNotEmpty;
  bool get syncConfigured =>
      syncEndpoint.trim().isNotEmpty && syncToken.trim().isNotEmpty;
  bool get emailConfigured =>
      emailHost.trim().isNotEmpty && emailFromAddress.trim().isNotEmpty;

  TerminalSettings copyWith({
    String? storeName,
    int? taxRateBps,
    int? scannerMinLength,
    int? scannerTimeoutMs,
    String? searchHotkey,
    String? checkoutHotkey,
    String? printerHost,
    int? printerPort,
    ReceiptPaperSize? receiptPaper,
    String? emailHost,
    int? emailPort,
    String? emailUsername,
    String? emailPassword,
    String? emailFromAddress,
    String? emailFromName,
    bool? emailUseSsl,
    String? syncEndpoint,
    String? syncToken,
    bool? darkMode,
    String? languageCode,
  }) {
    return TerminalSettings(
      deviceId: deviceId,
      storeName: storeName ?? this.storeName,
      taxRateBps: taxRateBps ?? this.taxRateBps,
      scannerMinLength: scannerMinLength ?? this.scannerMinLength,
      scannerTimeoutMs: scannerTimeoutMs ?? this.scannerTimeoutMs,
      searchHotkey: searchHotkey ?? this.searchHotkey,
      checkoutHotkey: checkoutHotkey ?? this.checkoutHotkey,
      printerHost: printerHost ?? this.printerHost,
      printerPort: printerPort ?? this.printerPort,
      receiptPaper: receiptPaper ?? this.receiptPaper,
      emailHost: emailHost ?? this.emailHost,
      emailPort: emailPort ?? this.emailPort,
      emailUsername: emailUsername ?? this.emailUsername,
      emailPassword: emailPassword ?? this.emailPassword,
      emailFromAddress: emailFromAddress ?? this.emailFromAddress,
      emailFromName: emailFromName ?? this.emailFromName,
      emailUseSsl: emailUseSsl ?? this.emailUseSsl,
      syncEndpoint: syncEndpoint ?? this.syncEndpoint,
      syncToken: syncToken ?? this.syncToken,
      darkMode: darkMode ?? this.darkMode,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
