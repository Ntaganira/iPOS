/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : draft_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Encrypted per-operator cart draft storage. Writes are upserts
 *               into the settings registry so no schema migration is required;
 *               clearing a draft deletes the row. Malformed or partial JSON is
 *               treated as no draft rather than blocking sign-in.
 * </pre>
 */

import 'dart:convert';

import '../database/app_database.dart';
import '../models/cart_draft.dart';

/// Stores one active draft per user id.
class DraftRepository {
  DraftRepository(this._database);

  final AppDatabase _database;

  static String keyFor(String userId) => 'draft.cart.$userId';

  Future<CartDraft?> load(String userId) async {
    final row =
        await (_database.select(_database.appSettings)
              ..where((table) => table.settingKey.equals(keyFor(userId))))
            .getSingleOrNull();
    if (row == null || row.settingValue.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(row.settingValue);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final draft = CartDraft.fromJson(decoded);
      return draft.isEmpty ? null : draft;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String userId, CartDraft draft) async {
    if (draft.isEmpty) {
      await clear(userId);
      return;
    }
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            settingKey: keyFor(userId),
            settingValue: jsonEncode(draft.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> clear(String userId) async {
    await (_database.delete(
      _database.appSettings,
    )..where((table) => table.settingKey.equals(keyFor(userId)))).go();
  }
}
