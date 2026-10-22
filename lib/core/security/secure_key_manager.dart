/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.security
 * - File      : secure_key_manager.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : OS-protected-at-rest lifecycle owner for the 256-bit
 *               SQLCipher database key. The key is generated once with a
 *               cryptographically secure RNG, stored only in the platform
 *               secure store, validated on every cold start, and never
 *               written to logs, preferences, or the SQLite file itself.
 * </pre>
 */

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Creates, stores, and retrieves the single AES-256 database key used by the
/// encrypted local ledger.
///
/// Security model:
/// - The key is 32 random bytes (256 bits) encoded as 64 lowercase hex
///   characters. SQLCipher receives it as a raw key (`x'...'`), which means no
///   passphrase KDF is performed and the full 256 bits are used directly.
/// - The key material lives in the operating system's protected secret store:
///   Android Keystore-backed cipher storage, Apple Keychain, Windows
///   credential protection, or Linux Secret Service. Depending on the device,
///   the wrapping key is protected by a TEE, StrongBox, Secure Enclave, or the
///   platform credential vault. Hardware backing is a platform guarantee, not
///   something Dart can assert at runtime.
/// - This class fails closed. If a key exists but is malformed, it refuses to
///   regenerate it, because replacing a live key would permanently orphan the
///   encrypted database. Recovery must go through an explicit admin ceremony.
/// - Dart strings cannot be reliably zeroized. The key necessarily exists in
///   managed memory while the database is open; do not cache it in analytics,
///   crash reports, screenshots, or diagnostic logs.
class SecureKeyManager {
  /// Creates a manager. Tests may inject a fake [FlutterSecureStorage].
  SecureKeyManager({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage;

  /// Process-wide instance used by the application bootstrap.
  static final SecureKeyManager instance = SecureKeyManager();

  /// Versioned alias. Bump only with a deliberate key-rotation migration.
  static const String _databaseKeyAlias = 'ipos.sqlcipher.aes256.v1';

  /// Exactly 64 lowercase hexadecimal characters == 32 bytes == 256 bits.
  static final RegExp _keyPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Secure-store configuration.
  ///
  /// Android 10+ uses RSA-OAEP SHA-256 key wrapping plus AES-GCM payload
  /// encryption. macOS is configured for the legacy login keychain so the app
  /// does not require Keychain Sharing provisioning solely to read its own
  /// database key. iOS/macOS still use the Keychain; Windows uses the platform
  /// credential vault; Linux uses Secret Service/libsecret.
  static final FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      // Preserve data if the Android cipher implementation ever changes.
      migrateWithBackup: true,
    ),
    mOptions: const MacOsOptions(usesDataProtectionKeychain: false),
  );

  final FlutterSecureStorage _storage;

  /// In-process cache. The database needs the key while it is mounted, so this
  /// avoids a secure-store round trip for every repository call.
  String? _cachedKeyHex;

  /// Single-flight guard preventing two concurrent first-launch generations.
  Future<String>? _pendingLoad;

  /// Returns the existing 256-bit database key or provisions a new one exactly
  /// once. Concurrent callers share the same in-flight future.
  ///
  /// Throws [StateError] if the secure store contains a malformed value or if
  /// the newly generated value cannot be verified after writing.
  Future<String> databaseKeyHex() {
    final cached = _cachedKeyHex;
    if (cached != null) {
      return Future<String>.value(cached);
    }

    final pending = _pendingLoad;
    if (pending != null) {
      return pending;
    }

    final load = _loadOrProvision().then((key) {
      _cachedKeyHex = key;
      return key;
    });
    _pendingLoad = load;
    return load.whenComplete(() => _pendingLoad = null);
  }

  /// Reads and validates the platform secret, provisioning a new key only when
  /// no value exists at all.
  Future<String> _loadOrProvision() async {
    final existing = await _storage.read(key: _databaseKeyAlias);
    if (existing != null) {
      final normalized = existing.trim().toLowerCase();
      if (!_keyPattern.hasMatch(normalized)) {
        throw StateError(
          'The secure store contains an invalid iPOS database key. '
          'Refusing to regenerate it: doing so would make the existing '
          'encrypted ledger unreadable. Restore the original key or follow '
          'the documented disaster-recovery procedure.',
        );
      }
      return normalized;
    }

    final generated = _generateHexKey();
    await _storage.write(key: _databaseKeyAlias, value: generated);

    // Read-back verification catches silent platform write failures, which are
    // especially common when Keychain Sharing/entitlements are misconfigured.
    final persisted = await _storage.read(key: _databaseKeyAlias);
    if (persisted != generated) {
      throw StateError(
        'The 256-bit database key could not be persisted to the platform '
        'secure store. Verify Android backup settings or Apple Keychain '
        'entitlements before opening the database.',
      );
    }

    return generated;
  }

  /// Generates 32 bytes from the platform CSPRNG and encodes them as lowercase
  /// hexadecimal. Hex is used because SQLCipher's raw-key syntax accepts it
  /// directly, avoiding a second encoder and any ambiguity in string handling.
  String _generateHexKey() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Drops the in-memory copy without touching the persistent key. Intended for
  /// tests and for lock-screen flows that deliberately re-open the vault.
  void evictCachedKey() {
    _cachedKeyHex = null;
  }
}
