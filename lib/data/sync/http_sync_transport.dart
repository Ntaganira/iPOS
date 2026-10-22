/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.sync
 * - File      : http_sync_transport.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Bearer-authenticated HTTPS transport for the back-office sync
 *               API. Requests are bounded by a timeout; error bodies are
 *               truncated before surfacing and never include the token. The
 *               endpoint must be configured by an administrator in Settings.
 * </pre>
 */

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_contract.dart';

/// HTTP implementation of the back-office sync contract.
class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({
    required String endpoint,
    required String token,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _endpoint = endpoint.replaceAll(RegExp(r'/+$'), ''),
       _token = token,
       _client = client ?? http.Client();

  final String _endpoint;
  final String _token;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<SyncPushResult> push({
    required String deviceId,
    required List<SyncPushItem> items,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_endpoint/sync/push'),
          headers: _headers,
          body: jsonEncode(<String, Object?>{
            'device_id': deviceId,
            'items': items
                .map(
                  (item) => <String, Object?>{
                    'outbox_id': item.id,
                    'entity_type': item.entityType,
                    'entity_id': item.entityId,
                    'operation': item.operation,
                    'payload': item.payload,
                    'occurred_at': item.occurredAt.toIso8601String(),
                  },
                )
                .toList(growable: false),
          }),
        )
        .timeout(timeout);

    final body = _decodeBody(response);
    final accepted = (body['accepted'] as List<Object?>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    final conflicts = (body['conflicts'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(
          (item) => SyncConflict(
            outboxId: item['outbox_id']?.toString() ?? '',
            entityType: item['entity_type']?.toString() ?? '',
            entityId: item['entity_id']?.toString() ?? '',
            operation: item['operation']?.toString() ?? 'upsert',
            payload:
                (item['payload'] as Map<String, Object?>?) ??
                const <String, Object?>{},
          ),
        )
        .toList(growable: false);

    return SyncPushResult(
      accepted: accepted,
      conflicts: conflicts,
      serverTime:
          DateTime.tryParse(body['server_time']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  @override
  Future<SyncPullResult> pull({
    required String deviceId,
    required int cursor,
  }) async {
    final uri = Uri.parse('$_endpoint/sync/pull').replace(
      queryParameters: <String, String>{
        'device_id': deviceId,
        'cursor': '$cursor',
      },
    );
    final response = await _client.get(uri, headers: _headers).timeout(timeout);

    final body = _decodeBody(response);
    final changes = (body['changes'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(
          (item) => SyncChange(
            entityType: item['entity_type']?.toString() ?? '',
            entityId: item['entity_id']?.toString() ?? '',
            operation: item['operation']?.toString() ?? 'upsert',
            payload:
                (item['payload'] as Map<String, Object?>?) ??
                const <String, Object?>{},
            updatedAt:
                DateTime.tryParse(
                  item['updated_at']?.toString() ?? '',
                )?.toUtc() ??
                DateTime.now().toUtc(),
          ),
        )
        .toList(growable: false);

    return SyncPullResult(
      changes: changes,
      nextCursor: (body['next_cursor'] as num?)?.toInt() ?? cursor,
      serverTime:
          DateTime.tryParse(body['server_time']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, String> get _headers => <String, String>{
    'authorization': 'Bearer $_token',
    'content-type': 'application/json',
    'accept': 'application/json',
  };

  Map<String, Object?> _decodeBody(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final preview = utf8
          .decode(response.bodyBytes, allowMalformed: true)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final truncated = preview.length > 180
          ? '${preview.substring(0, 180)}...'
          : preview;
      throw SyncException(
        'Sync request failed with HTTP ${response.statusCode}. $truncated',
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      throw const SyncException('Sync response was not a JSON object.');
    }
    return decoded;
  }
}

/// Typed transport failure safe to surface in the UI.
class SyncException implements Exception {
  const SyncException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
