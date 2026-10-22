/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.sync
 * - File      : sync_contract.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Wire contract shared conceptually with the back office. One
 *               push carries outbox revisions; the server returns accepted ids,
 *               authoritative conflict resolutions, and a cursor. Pull returns
 *               master-data changes after that cursor. Payload values contain no
 *               database keys or platform secrets.
 * </pre>
 */

import 'package:flutter/foundation.dart';

/// One outbox revision ready for upload.
@immutable
class SyncPushItem {
  const SyncPushItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.occurredAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, Object?> payload;
  final DateTime occurredAt;
}

/// Authoritative server record for a conflicting outbox item.
@immutable
class SyncConflict {
  const SyncConflict({
    required this.outboxId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
  });

  final String outboxId;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, Object?> payload;
}

/// Push response.
@immutable
class SyncPushResult {
  const SyncPushResult({
    required this.accepted,
    required this.conflicts,
    required this.serverTime,
  });

  final List<String> accepted;
  final List<SyncConflict> conflicts;
  final DateTime serverTime;
}

/// One server-side change.
@immutable
class SyncChange {
  const SyncChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.updatedAt,
  });

  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
}

/// Pull response.
@immutable
class SyncPullResult {
  const SyncPullResult({
    required this.changes,
    required this.nextCursor,
    required this.serverTime,
  });

  final List<SyncChange> changes;
  final int nextCursor;
  final DateTime serverTime;
}

/// Transport abstraction so the drain policy is testable without a server.
abstract interface class SyncTransport {
  Future<SyncPushResult> push({
    required String deviceId,
    required List<SyncPushItem> items,
  });

  Future<SyncPullResult> pull({required String deviceId, required int cursor});
}
