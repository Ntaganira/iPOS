/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : http_sync_transport_test.dart
 * - Date      : 2026. 10. 23.
 * - User      : NTAGANIRA H.
 * - Desc      : Verifies the sync transport turns HTTP 429 responses into a
 *               typed failure that carries the server's Retry-After delay so
 *               the outbox is never retried in a tight loop.
 * </pre>
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ipos/data/sync/http_sync_transport.dart';
import 'package:ipos/data/sync/sync_contract.dart';

HttpSyncTransport transportFor(Map<String, String> headers) {
  return HttpSyncTransport(
    endpoint: 'https://sync.example.test',
    token: 'token',
    client: MockClient(
      (request) async =>
          http.Response('{"error":"rate limited"}', 429, headers: headers),
    ),
  );
}

SyncPushItem item() => SyncPushItem(
  id: 'outbox-1',
  entityType: 'part',
  entityId: 'part-1',
  operation: 'upsert',
  payload: const <String, Object?>{'id': 'part-1'},
  occurredAt: DateTime.utc(2026, 10, 23),
);

void main() {
  test('429 carries the numeric Retry-After delay', () async {
    final transport = transportFor(const {'retry-after': '45'});

    await expectLater(
      transport.push(deviceId: 'device-1', items: [item()]),
      throwsA(
        isA<SyncException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 45),
            ),
      ),
    );
  });

  test(
    '429 without a usable Retry-After leaves the delay to the service',
    () async {
      final transport = transportFor(const {'retry-after': 'later'});

      await expectLater(
        transport.push(deviceId: 'device-1', items: [item()]),
        throwsA(
          isA<SyncException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having((error) => error.retryAfter, 'retryAfter', isNull),
        ),
      );
    },
  );
}
