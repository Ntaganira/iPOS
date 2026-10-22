/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : app_notification.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Immutable notification projection for the operator inbox.
 *               Severity drives icon and color only; business logic must never
 *               depend on localized labels.
 * </pre>
 */

import 'package:flutter/foundation.dart';

/// Notification urgency.
enum NotificationSeverity {
  info,
  warning,
  critical;

  static NotificationSeverity fromWire(String value) {
    for (final severity in values) {
      if (severity.name == value) {
        return severity;
      }
    }
    return NotificationSeverity.info;
  }
}

/// One in-app notification.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.entityType,
    this.entityId,
  });

  final String id;
  final String kind;
  final NotificationSeverity severity;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? entityType;
  final String? entityId;
}
