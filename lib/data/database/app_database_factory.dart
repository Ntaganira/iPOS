/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database
 * - File      : app_database_factory.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Encrypted database bootstrap. Resolves the 256-bit key from the
 *               platform secure store, mounts SQLCipher on the app-private
 *               SQLite file, applies cipher and durability pragmas before Drift
 *               migrations run, and eagerly probes the schema so a wrong key or
 *               corrupt vault fails at startup rather than mid-sale.
 * </pre>
 */

import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/security/secure_key_manager.dart';
import 'app_database.dart';

/// Opens the one encrypted till database for this installation.
abstract final class AppDatabaseFactory {
  static const String _directoryName = 'iPOS';
  static const String _databaseFileName = 'ipos.sqlite3';

  /// Creates the encrypted database, runs migrations, and verifies it can be
  /// queried before returning.
  ///
  /// The key is passed to a background isolate as a raw 256-bit SQLCipher key.
  /// No passphrase or key derivation is used at runtime; the secure store owns
  /// the root secret and SQLCipher owns file-level authenticated encryption.
  static Future<AppDatabase> open({SecureKeyManager? keyManager}) async {
    final manager = keyManager ?? SecureKeyManager.instance;
    final databaseFile = await resolveDatabaseFile();
    final hasExistingLedger =
        await databaseFile.exists() && await databaseFile.length() > 0;
    final keyHex = hasExistingLedger
        ? await manager.existingDatabaseKeyHex()
        : await manager.databaseKeyHex();

    final executor = NativeDatabase.createInBackground(
      databaseFile,
      // A single reader isolate keeps YMM/catalog reads off the UI thread while
      // one writer serializes checkout transactions. WAL is enabled below, so
      // the reader pool is safe.
      readPool: 1,
      cachePreparedStatements: true,
      // Statement logging can be enabled locally for diagnostics, but must stay
      // off in production because parameter values can include customer data.
      logStatements: false,
      setup: (database) {
        // 1. Mount the encrypted page store. This MUST be the first statement.
        //    `x'...'` tells SQLCipher to consume the hex as a raw 256-bit key
        //    instead of running a password KDF.
        database.execute("PRAGMA key = \"x'$keyHex'\";");

        // 2. Pin the file format and harden workspace memory. Compatibility 4
        //    prevents an upstream default change from making existing tills
        //    unreadable after an app update.
        database.execute('PRAGMA cipher_compatibility = 4;');
        database.execute('PRAGMA cipher_memory_security = ON;');

        // 3. Durability/performance profile for an interactive POS. WAL allows
        //    the single writer and read pool to coexist; NORMAL is the correct
        //    durability pairing for WAL on a battery-backed tablet or desktop.
        database.execute('PRAGMA journal_mode = WAL;');
        database.execute('PRAGMA synchronous = NORMAL;');
        database.execute('PRAGMA temp_store = MEMORY;');
        database.execute('PRAGMA foreign_keys = ON;');

        // 4. Fail fast if the key is wrong or the file is corrupt. Without this
        //    probe the first failure would surface during a checkout write.
        database.select('SELECT count(*) FROM sqlite_master;');
      },
    );

    final database = AppDatabase(executor);

    try {
      // Forces connection creation and Drift's onCreate/onUpgrade lifecycle
      // before any screen receives the database instance.
      await database
          .customSelect('SELECT count(*) AS table_count FROM sqlite_master')
          .getSingle();
      return database;
    } catch (_) {
      // Best-effort cleanup; the original open/key error is what callers need.
      try {
        await database.close();
      } catch (_) {
        // The executor may already be unusable.
      }
      rethrow;
    }
  }

  /// Resolves the app-private encrypted database file used by maintenance
  /// operations such as backup, integrity checks, and key rotation.
  static Future<File> resolveDatabaseFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      p.join(supportDirectory.path, _directoryName),
    );
    await databaseDirectory.create(recursive: true);
    return File(p.join(databaseDirectory.path, _databaseFileName));
  }
}
