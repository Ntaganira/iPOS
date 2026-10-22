/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.security
 * - File      : database_key_rotation_service.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Explicit administrator key-rotation ceremony. The database must
 *               be closed; the service checkpoints the WAL, keeps an encrypted
 *               pre-rotation backup, applies SQLCipher PRAGMA rekey with a raw
 *               256-bit key, and verifies the new key before the secure store
 *               is updated. Old-key access is verified to fail.
 * </pre>
 */

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Outcome of the rotation, including the recovery backup.
class KeyRotationResult {
  const KeyRotationResult({required this.backupFile, required this.rotatedAt});

  final File backupFile;
  final DateTime rotatedAt;
}

/// Rotates the SQLCipher file key while preserving the encrypted ledger.
class DatabaseKeyRotationService {
  static final RegExp _keyPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Rotates [databaseFile] from [oldKeyHex] to [newKeyHex].
  ///
  /// The caller is responsible for closing the app database first and for
  /// writing [newKeyHex] to the platform secure store only after this method
  /// succeeds. A pre-rotation encrypted backup is returned so a failed secure
  /// store write can be recovered manually.
  Future<KeyRotationResult> rotate({
    required File databaseFile,
    required String oldKeyHex,
    required String newKeyHex,
  }) async {
    final oldKey = oldKeyHex.trim().toLowerCase();
    final newKey = newKeyHex.trim().toLowerCase();

    if (!_keyPattern.hasMatch(oldKey) || !_keyPattern.hasMatch(newKey)) {
      throw ArgumentError('Both keys must be 64 lowercase hex characters.');
    }
    if (oldKey == newKey) {
      throw ArgumentError('The new key must differ from the current key.');
    }
    if (!databaseFile.existsSync()) {
      throw StateError('The encrypted database file does not exist.');
    }

    final backupDirectory = Directory(
      p.join(databaseFile.parent.path, 'backups'),
    );
    await backupDirectory.create(recursive: true);
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final backupFile = File(
      p.join(backupDirectory.path, 'pre-rotate-$stamp.sqlite3'),
    );

    _checkpoint(databaseFile.path, oldKey);
    await databaseFile.copy(backupFile.path);

    _rekey(databaseFile.path, oldKey, newKey);
    _assertKeyOpens(databaseFile.path, newKey);
    _assertKeyRejected(databaseFile.path, oldKey);

    return KeyRotationResult(
      backupFile: backupFile,
      rotatedAt: DateTime.now().toUtc(),
    );
  }

  void _checkpoint(String path, String key) {
    final database = sqlite3.open(path);
    try {
      _applyKey(database, key);
      database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      database.close();
    }
  }

  void _rekey(String path, String oldKey, String newKey) {
    final database = sqlite3.open(path);
    try {
      _applyKey(database, oldKey);
      database.execute('PRAGMA rekey = "x\'$newKey\'"');
      database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      database.close();
    }
  }

  void _assertKeyOpens(String path, String key) {
    final database = sqlite3.open(path);
    try {
      _applyKey(database, key);
      final result = database.select('PRAGMA integrity_check');
      final value = result.first.values.first.toString();
      if (value != 'ok') {
        throw StateError('Rotated database failed integrity verification.');
      }
    } finally {
      database.close();
    }
  }

  void _assertKeyRejected(String path, String key) {
    final database = sqlite3.open(path);
    try {
      _applyKey(database, key);
      database.select('SELECT count(*) FROM sqlite_master');
      throw StateError(
        'The old key still opens the database after rotation. Aborting.',
      );
    } on SqliteException {
      // Expected: the old key cannot decrypt the rekeyed pages.
    } finally {
      database.close();
    }
  }

  void _applyKey(Database database, String keyHex) {
    database.execute("PRAGMA key = \"x'$keyHex'\"");
    database.execute('PRAGMA cipher_compatibility = 4');
    database.select('SELECT count(*) FROM sqlite_master');
  }
}
