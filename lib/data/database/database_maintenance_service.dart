/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database
 * - File      : database_maintenance_service.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Operational maintenance for the encrypted ledger: WAL
 *               checkpointing, post-shift VACUUM, integrity verification,
 *               encrypted backup creation, and a deliberately gated plaintext
 *               export for administrators. Every mutating operation writes an
 *               audit event so data movement is reviewable.
 * </pre>
 */

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../models/app_notification.dart';
import '../repositories/audit_repository.dart';
import '../repositories/notification_repository.dart';
import 'app_database.dart';
import 'app_database_factory.dart';

/// Result of a full SQLCipher integrity probe.
class IntegrityReport {
  const IntegrityReport({
    required this.isValid,
    required this.details,
    this.cipherVersion,
  });

  final bool isValid;
  final List<String> details;
  final String? cipherVersion;
}

/// Maintenance operations that must never run silently.
class DatabaseMaintenanceService {
  DatabaseMaintenanceService(
    this._database, {
    AuditActor? Function()? actorProvider,
  }) : _audit = AuditRepository(_database, actorProvider: actorProvider),
       _notifications = NotificationRepository(_database);

  final AppDatabase _database;
  final AuditRepository _audit;
  final NotificationRepository _notifications;

  /// Flushes the WAL into the encrypted main database. Safe to run while the
  /// app is serving sales and cheap enough for periodic scheduling.
  Future<void> checkpoint() async {
    await _database.customStatement('PRAGMA wal_checkpoint(PASSIVE)');
  }

  /// Reclaims free pages after a shift. VACUUM rewrites the whole encrypted
  /// file, so it is intentionally not part of every checkout.
  Future<void> vacuum() async {
    await _database.customStatement('VACUUM');
  }

  /// Scheduled post-shift routine. Checkpoint first so VACUUM sees a compact
  /// WAL, then audit the completed maintenance.
  Future<void> runPostShiftMaintenance() async {
    await checkpoint();
    await vacuum();
    await _audit.append(
      eventType: 'maintenance.vacuum',
      action: 'update',
      message: 'WAL checkpoint and VACUUM completed after shift close.',
      after: const <String, Object?>{'checkpoint': true, 'vacuum': true},
    );
  }

  /// Runs both SQLite's structural check and SQLCipher's HMAC check.
  Future<IntegrityReport> verifyIntegrity() async {
    final details = <String>[];
    var valid = true;

    final integrityRows = await _database
        .customSelect('PRAGMA integrity_check')
        .get();
    for (final row in integrityRows) {
      final value = row.data.values.first.toString();
      details.add('integrity_check: $value');
      if (value != 'ok') {
        valid = false;
      }
    }

    try {
      final cipherRows = await _database
          .customSelect('PRAGMA cipher_integrity_check')
          .get();
      for (final row in cipherRows) {
        final value = row.data.values.first.toString();
        details.add('cipher_integrity_check: $value');
        if (value.isNotEmpty) {
          valid = false;
        }
      }
    } catch (error) {
      details.add('cipher_integrity_check unavailable: $error');
      valid = false;
    }

    final versionRows = await _database
        .customSelect('PRAGMA cipher_version')
        .getSingleOrNull();
    final cipherVersion = versionRows?.data.values.first.toString();

    await _audit.append(
      eventType: valid
          ? 'maintenance.integrity_verified'
          : 'maintenance.integrity_failed',
      action: 'verify',
      message: valid
          ? 'Encrypted ledger integrity verification passed.'
          : 'Encrypted ledger integrity verification failed.',
      after: <String, Object?>{
        'is_valid': valid,
        'cipher_version': cipherVersion,
      },
      payload: <String, Object?>{'details': details},
    );
    if (!valid) {
      await _notifications.add(
        kind: 'integrity_failed',
        severity: NotificationSeverity.critical,
        title: 'Database integrity check failed',
        message:
            'Stop entering sales and restore the latest verified backup. '
            'See the audit trail for details.',
        dedupeKey: 'integrity-failed',
      );
    }

    return IntegrityReport(
      isValid: valid,
      details: List<String>.unmodifiable(details),
      cipherVersion: cipherVersion,
    );
  }

  /// Copies the encrypted file after flushing WAL. The copy remains encrypted
  /// with the same platform-held key and can be restored by placing it back at
  /// the app-private database path.
  Future<File> createEncryptedBackup({
    File? databaseFile,
    Directory? backupDirectory,
  }) async {
    await checkpoint();
    final source = databaseFile ?? await resolveDatabaseFile();
    final targetDirectory =
        backupDirectory ?? Directory(p.join(source.parent.path, 'backups'));
    await targetDirectory.create(recursive: true);

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final target = File(p.join(targetDirectory.path, 'ipos-$stamp.sqlite3'));
    await source.copy(target.path);

    await _audit.append(
      eventType: 'maintenance.encrypted_backup',
      action: 'export',
      message: 'Encrypted ledger backup created.',
      after: <String, Object?>{'file': p.basename(target.path)},
    );
    await _notifications.add(
      kind: 'backup_created',
      severity: NotificationSeverity.info,
      title: 'Encrypted backup created',
      message:
          'Backup ${p.basename(target.path)} is ready for off-device copy.',
      dedupeKey: 'backup-created',
    );
    return target;
  }

  /// Exports a decrypted copy for an explicitly authorized administrator. This
  /// is intentionally gated by [acknowledgeRisk] and is never called from a
  /// normal reporting path.
  Future<File> exportPlaintext({
    required Directory destination,
    required bool acknowledgeRisk,
  }) async {
    if (!acknowledgeRisk) {
      throw StateError(
        'Plaintext export requires explicit administrator acknowledgement.',
      );
    }

    await checkpoint();
    await destination.create(recursive: true);
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final target = File(
      p.join(destination.path, 'ipos-plaintext-$stamp.sqlite3'),
    );
    if (target.existsSync()) {
      throw StateError('Refusing to overwrite an existing plaintext export.');
    }

    final escapedPath = target.path.replaceAll("'", "''");
    try {
      await _database.customStatement(
        "ATTACH DATABASE '$escapedPath' AS plaintext KEY ''",
      );
      await _database.customStatement("SELECT sqlcipher_export('plaintext')");
      await _database.customStatement('DETACH DATABASE plaintext');

      final probe = sqlite3.open(target.path, mode: OpenMode.readOnly);
      try {
        final result = probe.select('PRAGMA integrity_check');
        final value = result.first.values.first.toString();
        if (value != 'ok') {
          throw StateError('Plaintext export failed integrity verification.');
        }
      } finally {
        probe.close();
      }

      await _audit.append(
        eventType: 'maintenance.plaintext_export',
        action: 'export',
        message: 'Administrator exported a decrypted ledger copy.',
        after: <String, Object?>{
          'file': p.basename(target.path),
          'plaintext': true,
        },
      );
      await _notifications.add(
        kind: 'plaintext_export',
        severity: NotificationSeverity.warning,
        title: 'Plaintext export created',
        message:
            'A decrypted copy was written to ${target.path}. Move it to '
            'protected storage and delete it from this device.',
        dedupeKey: 'plaintext-export',
      );
      return target;
    } catch (_) {
      if (target.existsSync()) {
        target.deleteSync();
      }
      rethrow;
    }
  }

  /// Resolves the production app-private database path for backup/rotation.
  Future<File> resolveDatabaseFile() =>
      AppDatabaseFactory.resolveDatabaseFile();
}
