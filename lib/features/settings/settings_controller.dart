/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.settings
 * - File      : settings_controller.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Shared terminal-settings state. Loads once at startup, exposes
 *               validated updates to the shell and register, and persists
 *               through the encrypted settings repository. Theme and VAT
 *               changes propagate without restarting the app.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import '../../data/models/terminal_settings.dart';
import '../../data/repositories/settings_repository.dart';

/// Owns the current [TerminalSettings].
class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsRepository repository,
    TerminalSettings? initial,
  }) : _repository = repository,
       _settings = initial ?? const TerminalSettings(deviceId: '');

  final SettingsRepository _repository;

  TerminalSettings _settings;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  TerminalSettings get settings => _settings;
  String get languageCode => _settings.languageCode;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await _repository.load();
    } catch (error, stackTrace) {
      _error = 'Terminal settings could not be loaded. Defaults are active.';
      debugPrint('Settings load failed: $error\n$stackTrace');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> setLanguage(String languageCode) {
    if (!const <String>{'en', 'fr', 'rw'}.contains(languageCode)) {
      return Future<bool>.value(false);
    }
    return save(_settings.copyWith(languageCode: languageCode));
  }

  Future<bool> save(TerminalSettings next) async {
    if (_saving) {
      return false;
    }
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.save(next);
      _settings = next;
      return true;
    } catch (error, stackTrace) {
      _error = 'Settings were not saved. Check storage and try again.';
      debugPrint('Settings save failed: $error\n$stackTrace');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
