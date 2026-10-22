/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.core
 * - File      : secure_key_manager_test.dart
 * - Date      : 2026. 10. 23.
 * - User      : NTAGANIRA H.
 * - Desc      : Verifies first-launch key provisioning is distinct from key
 *               recovery: an existing ledger with no secure-store entry must
 *               fail closed instead of silently generating a new key, while a
 *               genuinely malformed key is never overwritten.
 * </pre>
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/security/secure_key_manager.dart';

class _MemoryStorage extends FlutterSecureStorage {
  _MemoryStorage([this.value]);

  String? value;
  int writes = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => value;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes++;
    this.value = value;
  }
}

void main() {
  const key =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

  test('first launch provisions and verifies a 256-bit key', () async {
    final storage = _MemoryStorage();
    final manager = SecureKeyManager(storage: storage);

    final provisioned = await manager.databaseKeyHex();

    expect(provisioned, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(storage.value, provisioned);
    expect(storage.writes, 1);
  });

  test('existing ledger with a missing key fails without writing', () async {
    final storage = _MemoryStorage();
    final manager = SecureKeyManager(storage: storage);

    await expectLater(
      manager.existingDatabaseKeyHex(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('database key is missing'),
        ),
      ),
    );
    expect(storage.writes, 0);
  });

  test('an existing valid key is reused', () async {
    final storage = _MemoryStorage(key);
    final manager = SecureKeyManager(storage: storage);

    expect(await manager.existingDatabaseKeyHex(), key);
    expect(await manager.databaseKeyHex(), key);
    expect(storage.writes, 0);
  });

  test('a malformed key is rejected and never overwritten', () async {
    final storage = _MemoryStorage('not-a-key');
    final manager = SecureKeyManager(storage: storage);

    await expectLater(
      manager.existingDatabaseKeyHex(),
      throwsA(isA<StateError>()),
    );
    expect(storage.value, 'not-a-key');
    expect(storage.writes, 0);
  });
}
