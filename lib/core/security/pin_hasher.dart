/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.security
 * - File      : pin_hasher.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : PIN hashing for local RBAC. Implements PBKDF2-HMAC-SHA256 with
 *               a per-user 128-bit salt and 30,000 iterations. The database is
 *               already SQLCipher-encrypted; hashing is defense in depth so a
 *               decrypted export or memory dump does not reveal operator PINs.
 *               Verification uses a constant-time comparison.
 * </pre>
 */

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Salted PIN digest helpers.
abstract final class PinHasher {
  static const int iterations = 30000;

  /// Generates a 128-bit random salt as lowercase hex.
  static String generateSalt() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return _toHex(bytes);
  }

  /// Derives a 256-bit digest and returns it as lowercase hex.
  static String hash(String pin, String saltHex, int rounds) {
    final password = utf8.encode(pin);
    final salt = _fromHex(saltHex);
    final hmac = Hmac(sha256, password);

    final block = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..[salt.length] = 0
      ..[salt.length + 1] = 0
      ..[salt.length + 2] = 0
      ..[salt.length + 3] = 1;

    var u = Uint8List.fromList(hmac.convert(block).bytes);
    final derived = Uint8List.fromList(u);
    for (var round = 1; round < rounds; round++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var i = 0; i < derived.length; i++) {
        derived[i] ^= u[i];
      }
    }
    return _toHex(derived);
  }

  /// Constant-time comparison to avoid timing leaks.
  static bool verify({
    required String pin,
    required String saltHex,
    required int rounds,
    required String expectedHash,
  }) {
    final actual = hash(pin, saltHex, rounds);
    if (actual.length != expectedHash.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _toHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Uint8List _fromHex(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.length.isOdd) {
      throw ArgumentError('Hex value must have an even length.');
    }
    final bytes = Uint8List(normalized.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
