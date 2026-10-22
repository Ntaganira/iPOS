/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.features.register
 * - File      : catalog_controller.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : UI state owner for the center register workspace. Coordinates
 *               debounced catalog search, cascading make/model/year lists, and
 *               stale-result rejection so rapid keyboard/scanner input can
 *               never paint an older query over a newer one. All database
 *               work is delegated to CatalogRepository; the controller remains
 *               framework- and SQL-free for testability.
 * </pre>
 */

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/catalog_part.dart';
import '../../data/repositories/catalog_repository.dart';

/// Search and YMM state for the front-counter catalog.
class CatalogController extends ChangeNotifier {
  CatalogController({
    required CatalogRepository repository,
    this.searchDebounce = const Duration(milliseconds: 180),
  }) : _repository = repository;

  final CatalogRepository _repository;
  final Duration searchDebounce;

  String _query = '';
  String? _selectedMake;
  String? _selectedModel;
  int? _selectedYear;

  List<String> _makes = const <String>[];
  List<String> _models = const <String>[];
  List<int> _years = const <int>[];
  List<CatalogPart> _results = const <CatalogPart>[];

  bool _loading = false;
  String? _error;
  Timer? _debounceTimer;
  int _requestEpoch = 0;
  bool _disposed = false;

  String get query => _query;
  String? get selectedMake => _selectedMake;
  String? get selectedModel => _selectedModel;
  int? get selectedYear => _selectedYear;
  List<String> get makes => _makes;
  List<String> get models => _models;
  List<int> get years => _years;
  List<CatalogPart> get results => _results;
  bool get loading => _loading;
  String? get error => _error;

  bool get hasVehicleFilter =>
      _selectedMake != null || _selectedModel != null || _selectedYear != null;

  bool get hasAnyFilter => hasVehicleFilter || _query.trim().isNotEmpty;

  /// Loads the initial make list, then performs the first catalog query.
  Future<void> initialize() async {
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      _makes = await _repository.listMakes();
    } catch (error, stackTrace) {
      _error = 'Vehicle makes could not be loaded from the local catalog.';
      debugPrint('Catalog make list failed: $error\n$stackTrace');
    } finally {
      _loading = false;
      _safeNotify();
    }

    await refresh();
  }

  /// Updates the free-text term immediately and debounces the SQL round trip.
  void setQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(searchDebounce, () => unawaited(refresh()));
    _safeNotify();
  }

  /// Bypasses the debounce for Enter/scanner submissions and waits for results.
  Future<void> submitQuery(String value) async {
    _query = value;
    _debounceTimer?.cancel();
    await refresh();
  }

  /// Cascades the make selection: resets dependent selections and loads models.
  Future<void> selectMake(String? make) async {
    if (_selectedMake == make) {
      return;
    }

    final epoch = ++_requestEpoch;
    _selectedMake = make;
    _selectedModel = null;
    _selectedYear = null;
    _models = const <String>[];
    _years = const <int>[];
    _debounceTimer?.cancel();
    _safeNotify();

    if (make != null) {
      try {
        final models = await _repository.listModels(make: make);
        if (_disposed || epoch != _requestEpoch) {
          return;
        }
        _models = models;
        _safeNotify();
      } catch (error, stackTrace) {
        if (_disposed || epoch != _requestEpoch) {
          return;
        }
        _error = 'Models for $make could not be loaded.';
        debugPrint('Catalog model list failed: $error\n$stackTrace');
        _safeNotify();
        return;
      }
    }

    if (_disposed || epoch != _requestEpoch) {
      return;
    }
    await refresh();
  }

  /// Cascades the model selection and loads the available model years.
  Future<void> selectModel(String? model) async {
    if (_selectedModel == model) {
      return;
    }

    final epoch = ++_requestEpoch;
    _selectedModel = model;
    _selectedYear = null;
    _years = const <int>[];
    _debounceTimer?.cancel();
    _safeNotify();

    final make = _selectedMake;
    if (make != null && model != null) {
      try {
        final years = await _repository.listYears(make: make, model: model);
        if (_disposed || epoch != _requestEpoch) {
          return;
        }
        _years = years;
        _safeNotify();
      } catch (error, stackTrace) {
        if (_disposed || epoch != _requestEpoch) {
          return;
        }
        _error = 'Years for $make $model could not be loaded.';
        debugPrint('Catalog year list failed: $error\n$stackTrace');
        _safeNotify();
        return;
      }
    }

    if (_disposed || epoch != _requestEpoch) {
      return;
    }
    await refresh();
  }

  /// Applies the year filter immediately.
  Future<void> selectYear(int? year) async {
    if (_selectedYear == year) {
      return;
    }
    _selectedYear = year;
    _debounceTimer?.cancel();
    _safeNotify();
    await refresh();
  }

  /// Clears the free-text term and all YMM filters, then reloads the catalog.
  Future<void> resetAll() async {
    _query = '';
    _selectedMake = null;
    _selectedModel = null;
    _selectedYear = null;
    _models = const <String>[];
    _years = const <int>[];
    _debounceTimer?.cancel();
    _safeNotify();
    await refresh();
  }

  /// Re-runs the current query. Also used by the error-state retry action.
  Future<void> refresh() async {
    final epoch = ++_requestEpoch;
    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final results = await _repository.searchCatalog(
        term: _query,
        make: _selectedMake,
        model: _selectedModel,
        year: _selectedYear,
      );
      if (_disposed || epoch != _requestEpoch) {
        return;
      }
      _results = results;
    } catch (error, stackTrace) {
      if (_disposed || epoch != _requestEpoch) {
        return;
      }
      _results = const <CatalogPart>[];
      _error = 'Catalog lookup failed. The local ledger may be locked.';
      debugPrint('Catalog search failed: $error\n$stackTrace');
    } finally {
      if (!_disposed && epoch == _requestEpoch) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
