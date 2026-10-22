/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.database.tables
 * - File      : app_settings_table.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Local key/value settings for terminal identity, tax profile,
 *               scanner timing, hotkeys, printer transport, sync credentials,
 *               and appearance. Values are cached in controllers and never
 *               written to logs.
 * </pre>
 */

import 'package:drift/drift.dart';

/// Durable terminal preferences. Keys are namespaced with dots.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get settingKey => text()();
  TextColumn get settingValue => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {settingKey};
}
