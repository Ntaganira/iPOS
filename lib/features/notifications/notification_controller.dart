/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.notifications
 * - File      : notification_controller.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Reactive notification inbox state for the shell bell. The
 *               controller subscribes to Drift's table stream, derives the
 *               unread count, and exposes mark-read/clear actions. It never
 *               owns the database and is disposed with the app.
 * </pre>
 */

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';

/// Notification inbox state.
class NotificationController extends ChangeNotifier {
  NotificationController({required NotificationRepository repository})
    : _repository = repository;

  final NotificationRepository _repository;

  StreamSubscription<List<AppNotification>>? _subscription;
  List<AppNotification> _items = const <AppNotification>[];
  int _unread = 0;
  bool _disposed = false;

  List<AppNotification> get items => List<AppNotification>.unmodifiable(_items);
  int get unreadCount => _unread;

  Future<void> initialize() async {
    _subscription ??= _repository.watchRecent().listen(
      (items) {
        _items = items;
        _unread = items.where((item) => !item.isRead).length;
        _safeNotify();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Notification stream failed: $error\n$stackTrace');
      },
    );
    _unread = await _repository.unreadCount();
    _safeNotify();
  }

  Future<void> markRead(String id) => _repository.markRead(id);

  Future<void> markAllRead() => _repository.markAllRead();

  Future<void> clearRead() => _repository.clearRead();

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
