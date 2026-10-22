/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.input
 * - File      : scan_wedge_detector.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Detects keyboard-wedge barcode bursts in the search field. A
 *               scanner types faster than a human and may omit the Enter
 *               suffix, so a run of at least the configured minimum length at
 *               or below the inter-key timeout is submitted once input stops.
 * </pre>
 */

import 'dart:async';

/// Turns a rapid run of text-field edits into a completed scan.
class ScanWedgeDetector {
  ScanWedgeDetector({
    required int minLength,
    required Duration timeout,
    required this.onScan,
    DateTime Function()? clock,
  }) : _minLength = minLength,
       _timeout = timeout,
       _clock = clock ?? DateTime.now;

  final void Function(String value) onScan;
  final DateTime Function() _clock;

  int _minLength;
  Duration _timeout;
  Timer? _timer;
  DateTime? _lastEditAt;
  String? _lastValue;
  int _burstCharacters = 0;
  int _burstStart = 0;
  bool _candidate = false;

  int get minLength => _minLength;

  Duration get timeout => _timeout;

  void configure({required int minLength, required Duration timeout}) {
    _minLength = minLength;
    _timeout = timeout;
    reset();
  }

  /// Feed each user-visible text change from the search field.
  void textChanged(String value) {
    final now = _clock();
    final previous = _lastValue;
    if (value.trim().isEmpty) {
      reset();
      return;
    }

    final grewByOne =
        previous != null &&
        value.length == previous.length + 1 &&
        value.startsWith(previous);
    if (grewByOne && _lastEditAt != null) {
      final gap = now.difference(_lastEditAt!);
      if (gap <= _timeout) {
        _burstCharacters += 1;
      } else {
        _burstCharacters = 1;
        _burstStart = previous.length;
      }
    } else {
      _burstCharacters = 1;
      _burstStart = previous?.length ?? 0;
    }

    _lastValue = value;
    _lastEditAt = now;
    _candidate =
        _burstCharacters >= _minLength &&
        value.length - _burstStart >= _minLength;
    _timer?.cancel();
    if (_candidate) {
      _timer = Timer(_timeout, _onSettled);
    }
  }

  /// Called when the field already submitted through Enter; suppresses the
  /// timeout path for the same scan.
  void submitted() {
    reset();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _lastEditAt = null;
    _lastValue = null;
    _burstCharacters = 0;
    _burstStart = 0;
    _candidate = false;
  }

  void dispose() {
    reset();
  }

  void _onSettled() {
    final value = _lastValue;
    final shouldScan = _candidate;
    final start = _burstStart;
    reset();
    if (shouldScan && value != null && start < value.length) {
      onScan(value.substring(start));
    }
  }
}
