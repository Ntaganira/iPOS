/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.core
 * - File      : crash_reporter_test.dart
 * - Date      : 2026. 10. 23.
 * - User      : NTAGANIRA H.
 * - Desc      : Proves crash entries are redacted before they reach disk,
 *               remain valid JSON lines, rotate at the configured size, and
 *               that a write failure never propagates into the till.
 * </pre>
 */

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/diagnostics/crash_reporter.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('ipos_crash_');
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  test('redacts credentials, raw keys, and operator home paths', () {
    const raw =
        'sign-in failed password=hunter2 '
        'email_password: "smtp-secret" '
        'syncToken=tok_live_abc '
        'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload '
        "PRAGMA key = \"x'00112233445566778899aabbccddeeff"
        "00112233445566778899aabbccddeeff'\"; "
        'smtp://clerk:averysecret@smtp.example.com:587 '
        'C:\\Users\\Muganga\\iPOS\\ipos.sqlite3';

    final redacted = CrashReporter.redact(raw);

    expect(redacted, isNot(contains('hunter2')));
    expect(redacted, isNot(contains('smtp-secret')));
    expect(redacted, isNot(contains('tok_live_abc')));
    expect(redacted, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    expect(redacted, isNot(contains('00112233445566778899aabbccddeeff')));
    expect(redacted, isNot(contains('averysecret')));
    expect(redacted, isNot(contains('Muganga')));
    expect(redacted, contains('[REDACTED]'));
    expect(redacted, contains(r'C:\Users\[USER]'));
  });

  test('writes one redacted JSON line per error and rotates', () async {
    final logFile = File('${directory.path}/crash.log');
    final reporter = CrashReporter(
      logFile: logFile,
      maxBytes: 260,
      clock: () => DateTime.utc(2026, 10, 23, 8, 30),
    );

    await reporter.record(
      Exception('checkout failed token=tok_live_abc'),
      StackTrace.fromString('at sale() in C:\\Users\\Muganga\\pos.dart'),
      context: 'checkout',
      details: const {'password': 'hunter2', 'invoice': 'INV-1'},
    );
    await reporter.record(
      StateError('second failure'),
      StackTrace.current,
      context: 'sync',
    );

    expect(logFile.existsSync(), isTrue);
    final rotated = File('${logFile.path}.1');
    expect(rotated.existsSync(), isTrue);

    final lines = [
      ...rotated.readAsLinesSync(),
      ...logFile.readAsLinesSync(),
    ].where((line) => line.trim().isNotEmpty).toList();
    expect(lines.length, 2);
    for (final line in lines) {
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['at'], isA<String>());
    }
    final contents = lines.join('\n');
    expect(contents, isNot(contains('hunter2')));
    expect(contents, isNot(contains('tok_live_abc')));
    expect(contents, isNot(contains('Muganga')));
    expect(contents, contains('"invoice":"INV-1"'));
  });

  test('a write failure is swallowed', () async {
    final blocker = File('${directory.path}/blocked');
    blocker.writeAsStringSync('not a directory');
    final reporter = CrashReporter(
      logFile: File('${blocker.path}/nested/crash.log'),
    );

    await expectLater(
      reporter.record(Exception('cannot persist'), StackTrace.empty),
      completes,
    );
  });
}
