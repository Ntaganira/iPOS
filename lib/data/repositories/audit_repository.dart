/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : audit_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Append-only, tamper-evident local audit trail. Each event
 *               records the actor, stable action token, before/after state for
 *               edits, and a SHA-256 hash chained to the previous row. Payloads
 *               contain operational identifiers and totals only, never PINs,
 *               customer secrets, or database keys. Verification detects edited,
 *               deleted, or reordered rows.
 * </pre>
 */

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Actor attached to an audit event.
class AuditActor {
  const AuditActor({required this.userId, required this.name});

  final String userId;
  final String name;

  static const AuditActor system = AuditActor(userId: 'system', name: 'System');
}

/// One audit row decoded for the UI.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.eventType,
    required this.action,
    required this.actorName,
    required this.actorUserId,
    required this.message,
    required this.occurredAt,
    this.entityType,
    this.entityId,
    this.before,
    this.after,
    this.payload,
  });

  final String id;
  final String eventType;
  final String action;
  final String actorName;
  final String actorUserId;
  final String? entityType;
  final String? entityId;
  final String message;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
  final Map<String, Object?>? payload;
  final DateTime occurredAt;
}

/// Result of walking the audit chain.
class AuditChainVerification {
  const AuditChainVerification({
    required this.isValid,
    required this.checkedEvents,
    this.firstBrokenEventId,
  });

  final bool isValid;
  final int checkedEvents;
  final String? firstBrokenEventId;
}

/// Writes and verifies hash-chained audit events.
class AuditRepository {
  AuditRepository(this._database, {AuditActor? Function()? actorProvider})
    : _actorProvider = actorProvider;

  final AppDatabase _database;
  final AuditActor? Function()? _actorProvider;
  final Uuid _uuid = Uuid();

  /// Appends one event. Call inside a surrounding business transaction when the
  /// event must commit atomically with the mutation it describes.
  Future<void> append({
    required String eventType,
    required String message,
    String action = 'system',
    AuditActor? actor,
    String? entityType,
    String? entityId,
    Map<String, Object?> payload = const <String, Object?>{},
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    DateTime? occurredAt,
  }) async {
    final timestamp = occurredAt ?? DateTime.now().toUtc();
    // SQLite stores epoch seconds. Hash exactly the value that will be read
    // back so chain verification is byte-for-byte reproducible.
    final persistedTimestamp = DateTime.fromMillisecondsSinceEpoch(
      (timestamp.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    final resolvedActor = actor ?? _actorProvider?.call() ?? AuditActor.system;
    final previous = await _latestHash();
    final canonicalPayload = jsonEncode(payload);
    final beforeJson = before == null ? null : jsonEncode(before);
    final afterJson = after == null ? null : jsonEncode(after);
    final envelope = _envelope(
      eventType: eventType,
      action: action,
      actor: resolvedActor,
      entityType: entityType,
      entityId: entityId,
      message: message,
      payload: payload,
      before: before,
      after: after,
      occurredAt: persistedTimestamp,
    );
    final eventHash = sha256
        .convert(utf8.encode('${previous ?? ''}|${jsonEncode(envelope)}'))
        .toString();

    await _database.customStatement(
      '''
        INSERT INTO audit_events (
          id, event_type, action, actor_user_id, actor_name, entity_type,
          entity_id, message, payload_json, before_json, after_json,
          previous_hash, event_hash, occurred_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        _uuid.v4(),
        eventType,
        action,
        resolvedActor.userId == 'system' ? null : resolvedActor.userId,
        resolvedActor.name,
        entityType,
        entityId,
        message,
        canonicalPayload,
        beforeJson,
        afterJson,
        previous,
        eventHash,
        persistedTimestamp.millisecondsSinceEpoch ~/ 1000,
      ],
    );
  }

  /// Reads the audit trail newest-first with optional actor/entity filtering.
  Future<List<AuditEntry>> list({
    String? term,
    String? actorUserId,
    int limit = 200,
  }) async {
    final variables = <Variable<Object>>[];
    var filter = '1 = 1';
    final normalized = term?.trim() ?? '';
    if (normalized.isNotEmpty) {
      final pattern = '%${_escapeLike(normalized)}%';
      filter +=
          " AND (event_type LIKE ? ESCAPE '\\' "
          "OR message LIKE ? ESCAPE '\\' "
          "OR actor_name LIKE ? ESCAPE '\\' "
          "OR entity_id LIKE ? ESCAPE '\\')";
      variables
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern));
    }
    if (actorUserId != null && actorUserId.trim().isNotEmpty) {
      filter += ' AND actor_user_id = ?';
      variables.add(Variable.withString(actorUserId.trim()));
    }
    variables.add(Variable.withInt(limit.clamp(1, 1000).toInt()));

    final rows = await _database.customSelect('''
            SELECT id, event_type, action, actor_user_id, actor_name,
                   entity_type, entity_id, message, payload_json, before_json,
                   after_json, occurred_at
            FROM audit_events
            WHERE $filter
            ORDER BY occurred_at DESC, rowid DESC
            LIMIT ?
          ''', variables: variables).get();

    return rows.map(_mapEntry).toList(growable: false);
  }

  /// Recomputes every link. Use after restore, before export, and during
  /// scheduled integrity checks.
  Future<AuditChainVerification> verifyChain() async {
    final rows = await _database.customSelect('''
            SELECT id, event_type, action, actor_user_id, actor_name,
                   entity_type, entity_id, message, payload_json, before_json,
                   after_json, previous_hash, event_hash, occurred_at
            FROM audit_events
            ORDER BY occurred_at ASC, rowid ASC
          ''').get();

    String? expectedPrevious;
    var checked = 0;
    for (final row in rows) {
      final occurredAtSeconds = row.read<int>('occurred_at');
      final envelope = _envelope(
        eventType: row.read<String>('event_type'),
        action: row.read<String>('action'),
        actor: AuditActor(
          userId: row.readNullable<String>('actor_user_id') ?? 'system',
          name: row.readNullable<String>('actor_name') ?? 'System',
        ),
        entityType: row.readNullable<String>('entity_type'),
        entityId: row.readNullable<String>('entity_id'),
        message: row.read<String>('message'),
        payload:
            _decodeMap(row.readNullable<String>('payload_json')) ??
            const <String, Object?>{},
        before: _decodeMap(row.readNullable<String>('before_json')),
        after: _decodeMap(row.readNullable<String>('after_json')),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          occurredAtSeconds * 1000,
          isUtc: true,
        ),
      );
      final expectedHash = sha256
          .convert(
            utf8.encode('${expectedPrevious ?? ''}|${jsonEncode(envelope)}'),
          )
          .toString();

      if (row.readNullable<String>('previous_hash') != expectedPrevious ||
          row.read<String>('event_hash') != expectedHash) {
        return AuditChainVerification(
          isValid: false,
          checkedEvents: checked,
          firstBrokenEventId: row.read<String>('id'),
        );
      }

      expectedPrevious = row.read<String>('event_hash');
      checked++;
    }

    return AuditChainVerification(isValid: true, checkedEvents: checked);
  }

  /// Builds the hashed envelope. Legacy v2 rows (no actor columns) hash only
  /// the original fields, so upgrades do not invalidate their existing chain.
  Map<String, Object?> _envelope({
    required String eventType,
    required String action,
    required AuditActor actor,
    required String? entityType,
    required String? entityId,
    required String message,
    required Map<String, Object?> payload,
    required Map<String, Object?>? before,
    required Map<String, Object?>? after,
    required DateTime occurredAt,
  }) {
    final envelope = <String, Object?>{
      'event_type': eventType,
      'entity_type': entityType,
      'entity_id': entityId,
      'message': message,
      'payload': payload,
      'occurred_at': occurredAt.toIso8601String(),
    };
    final hasActorContext =
        actor.userId != 'system' ||
        action != 'system' ||
        before != null ||
        after != null;
    if (hasActorContext) {
      envelope
        ..['action'] = action
        ..['actor_user_id'] = actor.userId == 'system' ? null : actor.userId
        ..['actor_name'] = actor.name
        ..['before'] = before
        ..['after'] = after;
    }
    return envelope;
  }

  AuditEntry _mapEntry(QueryRow row) {
    return AuditEntry(
      id: row.read<String>('id'),
      eventType: row.read<String>('event_type'),
      action: row.read<String>('action'),
      actorUserId: row.readNullable<String>('actor_user_id') ?? 'system',
      actorName: row.readNullable<String>('actor_name') ?? 'System',
      entityType: row.readNullable<String>('entity_type'),
      entityId: row.readNullable<String>('entity_id'),
      message: row.read<String>('message'),
      before: _decodeMap(row.readNullable<String>('before_json')),
      after: _decodeMap(row.readNullable<String>('after_json')),
      payload: _decodeMap(row.readNullable<String>('payload_json')),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('occurred_at') * 1000,
        isUtc: true,
      ),
    );
  }

  Map<String, Object?>? _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    return decoded is Map<String, Object?> ? decoded : null;
  }

  String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  Future<String?> _latestHash() async {
    final row = await _database.customSelect('''
            SELECT event_hash
            FROM audit_events
            ORDER BY occurred_at DESC, rowid DESC
            LIMIT 1
          ''').getSingleOrNull();
    return row?.readNullable<String>('event_hash');
  }
}
