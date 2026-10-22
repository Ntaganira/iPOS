/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.diagnostics
 * - File      : crash_reporter.dart
 * - Date      : 2026. 10. 23.
 * - User      : NTAGANIRA H.
 * - Desc      : Local crash and unhandled-error journal. Every entry is written
 *               as one redacted JSON line under the app-private diagnostics
 *               directory, with size-bounded rotation so a failing terminal
 *               cannot exhaust disk. Passwords, PINs, bearer tokens, sync
 *               tokens, SMTP credentials, SQLCipher raw keys, and operator home
 *               paths never reach the file. Reporting is best-effort: an I/O
 *               failure must never take the till down.
 * </pre>
 */

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Best-effort local error journal with secret redaction.
class CrashReporter {
  CrashReporter({
    required this.logFile,
    DateTime Function()? clock,
    this.maxBytes = 512 * 1024,
  }) : _clock = clock ?? DateTime.now;

  /// Resolves `<app support>/iPOS/diagnostics/crash.log`.
  static Future<CrashReporter> open() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final diagnosticsDirectory = Directory(
      p.join(supportDirectory.path, 'iPOS', 'diagnostics'),
    );
    await diagnosticsDirectory.create(recursive: true);
    return CrashReporter(
      logFile: File(p.join(diagnosticsDirectory.path, 'crash.log')),
    );
  }

  final File logFile;
  final int maxBytes;
  final DateTime Function() _clock;
  Future<void> _pending = Future<void>.value();

  /// Queues one structured entry. Never throws.
  Future<void> record(
    Object error,
    StackTrace stackTrace, {
    String context = 'unhandled',
    Map<String, Object?>? details,
  }) {
    final entry = <String, Object?>{
      'at': _clock().toUtc().toIso8601String(),
      'context': redact(context),
      'error': redact(error.toString()),
      'stack': redact(stackTrace.toString()),
      if (details != null) 'details': _redactedDetails(details),
    };
    final line = '${jsonEncode(entry)}\n';
    _pending = _pending.then((_) => _append(line)).catchError((Object _) {
      // Diagnostics must never become a second failure.
    });
    return _pending;
  }

  Future<void> _append(String line) async {
    final parent = logFile.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
    if (logFile.existsSync() && logFile.lengthSync() + line.length > maxBytes) {
      await _rotate();
    }
    await logFile.writeAsString(line, mode: FileMode.append, flush: true);
  }

  Future<void> _rotate() async {
    final previous = File('${logFile.path}.1');
    if (previous.existsSync()) {
      await previous.delete();
    }
    if (logFile.existsSync()) {
      await logFile.rename(previous.path);
    }
  }

  Object _redactedDetails(Map<String, Object?> details) {
    try {
      return jsonDecode(redact(jsonEncode(details))) as Object;
    } catch (_) {
      return redact(details.toString());
    }
  }

  /// Removes credentials and operator-identifying paths from arbitrary text.
  static String redact(String input) {
    var output = input.replaceAllMapped(
      RegExp(
        r'(\b(?:smtps?|imaps?|https?|postgres(?:ql)?)://[^:\s/@]+:)[^@\s]+@',
        caseSensitive: false,
      ),
      (match) => '${match[1]}[REDACTED]@',
    );
    output = output.replaceAllMapped(
      RegExp(
        r'(\bauthorization\b\s*[:=]\s*)(?:bearer\s+|basic\s+)?[^\s,;}]+',
        caseSensitive: false,
      ),
      (match) => '${match[1]}[REDACTED]',
    );
    output = output.replaceAllMapped(
      RegExp(
        r"""(\bkey\b\s*=\s*["']?)x'[0-9a-f]{32,}'""",
        caseSensitive: false,
      ),
      (match) => "${match[1]}x'[REDACTED]'",
    );
    output = output.replaceAll(RegExp(r'\b[0-9a-fA-F]{64}\b'), '[REDACTED]');
    output = output.replaceAllMapped(
      RegExp(
        r'''\b((?:email|sync|smtp)[_-]?(?:password|passwd|pwd|token)|(?:email|sync|smtp)(?:Password|Token)|password|passwd|pwd|pin|token|secret|api[_-]?key)\b(\s*["']?\s*[:=]\s*["']?)([^"'\s,;}]+)''',
        caseSensitive: false,
      ),
      (match) => '${match[1]}${match[2]}[REDACTED]',
    );
    output = output.replaceAll(
      RegExp(r'C:\\Users\\[^\\\s]+', caseSensitive: false),
      r'C:\Users\[USER]',
    );
    output = output.replaceAll(
      RegExp(r'/home/[^/\s]+', caseSensitive: false),
      '/home/[USER]',
    );
    return output;
  }
}
