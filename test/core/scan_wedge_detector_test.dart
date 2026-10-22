/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.core
 * - File      : scan_wedge_detector_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Verifies scanner cadence detection, minimum length, suffix
 *               extraction when a scan follows an existing query, and Enter
 *               suppression of the timeout path.
 * </pre>
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/input/scan_wedge_detector.dart';

void main() {
  test('submits a rapid scan once input settles', () async {
    final scans = <String>[];
    final detector = ScanWedgeDetector(
      minLength: 4,
      timeout: const Duration(milliseconds: 20),
      onScan: scans.add,
    );
    addTearDown(detector.dispose);

    for (var index = 1; index <= 6; index++) {
      detector.textChanged('ABC123'.substring(0, index));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(scans, ['ABC123']);
  });

  test('ignores human-paced typing', () async {
    final scans = <String>[];
    final detector = ScanWedgeDetector(
      minLength: 4,
      timeout: const Duration(milliseconds: 20),
      onScan: scans.add,
    );
    addTearDown(detector.dispose);

    const value = 'ABC123';
    for (var index = 1; index <= value.length; index++) {
      detector.textChanged(value.substring(0, index));
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(scans, isEmpty);
  });

  test('requires the configured minimum number of rapid characters', () async {
    final scans = <String>[];
    final detector = ScanWedgeDetector(
      minLength: 6,
      timeout: const Duration(milliseconds: 20),
      onScan: scans.add,
    );
    addTearDown(detector.dispose);

    for (var index = 1; index <= 5; index++) {
      detector.textChanged('AB123'.substring(0, index));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(scans, isEmpty);
  });

  test('extracts only the scanned suffix after an existing query', () async {
    final scans = <String>[];
    final detector = ScanWedgeDetector(
      minLength: 4,
      timeout: const Duration(milliseconds: 20),
      onScan: scans.add,
    );
    addTearDown(detector.dispose);

    for (var index = 1; index <= 5; index++) {
      detector.textChanged('BRAKE'.substring(0, index));
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    const scan = 'SKU123';
    for (var index = 1; index <= scan.length; index++) {
      detector.textChanged('BRAKE${scan.substring(0, index)}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(scans, [scan]);
  });

  test('Enter suppresses the pending timeout submission', () async {
    final scans = <String>[];
    final detector = ScanWedgeDetector(
      minLength: 4,
      timeout: const Duration(milliseconds: 20),
      onScan: scans.add,
    );
    addTearDown(detector.dispose);

    for (var index = 1; index <= 6; index++) {
      detector.textChanged('ABC123'.substring(0, index));
    }
    detector.submitted();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(scans, isEmpty);
  });
}
