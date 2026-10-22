/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.storage
 * - File      : storage_failure.dart
 * - Date      : 2026. 10. 23.
 * - User      : NTAGANIRA H.
 * - Desc      : Classifies SQLite/SQLCipher and filesystem failures into
 *               operator-safe categories. A full disk, read-only volume, busy
 *               ledger, corrupt vault, and lost key each need a different
 *               recovery action, and none of them may be reported as a generic
 *               checkout failure. Unknown errors fall back to a non-destructive
 *               retry message.
 * </pre>
 */

/// Actionable storage failure categories shown at the counter.
enum StorageFailure {
  diskFull,
  readOnly,
  busy,
  corrupt,
  keyLost,
  unknown;

  /// Maps native SQLite/SQLCipher messages and common OS errors to a category.
  static StorageFailure classify(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('disk is full') ||
        message.contains('database or disk is full') ||
        message.contains('no space left') ||
        message.contains('not enough space') ||
        message.contains('disk full')) {
      return StorageFailure.diskFull;
    }
    if (message.contains('readonly') ||
        message.contains('read-only') ||
        message.contains('permission denied') ||
        message.contains('access is denied')) {
      return StorageFailure.readOnly;
    }
    if (message.contains('database is locked') ||
        message.contains('database is busy') ||
        message.contains('sqlite_busy')) {
      return StorageFailure.busy;
    }
    if (message.contains('hmac') ||
        message.contains('file is encrypted') ||
        message.contains('file is not a database') ||
        message.contains('sqlcipher') ||
        message.contains('database disk image is malformed') ||
        message.contains('database corrupt')) {
      return StorageFailure.keyLost;
    }
    if (message.contains('unable to open database file') ||
        message.contains('disk i/o error') ||
        message.contains('input/output error')) {
      return StorageFailure.corrupt;
    }
    return StorageFailure.unknown;
  }
}
