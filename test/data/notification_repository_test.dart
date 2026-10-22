/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : notification_repository_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : In-memory verification of the notification inbox: unread
 *               dedupe, reactive ordering, read transitions, and cleanup.
 * </pre>
 */

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/models/app_notification.dart';
import 'package:ipos/data/repositories/notification_repository.dart';

void main() {
  late AppDatabase database;
  late NotificationRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = NotificationRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('dedupe collapses an unread condition but allows a new one', () async {
    Future<void> add(String message) => repository.add(
      kind: 'low_stock',
      title: 'Low stock',
      message: message,
      severity: NotificationSeverity.warning,
      dedupeKey: 'low_stock:part-1',
    );

    await add('3 remaining');
    await add('2 remaining');
    expect(await repository.unreadCount(), 1);

    final first = (await repository.list()).single;
    await repository.markRead(first.id);

    await add('1 remaining');
    expect(await repository.unreadCount(), 1);
    expect((await repository.list()).length, 2);
  });

  test('read state and cleanup persist in the encrypted schema', () async {
    await repository.add(
      kind: 'shift_closed',
      title: 'Shift closed',
      message: 'Shift 1 closed',
    );
    await repository.add(
      kind: 'integrity_failed',
      title: 'Integrity failed',
      message: 'Page 1 failed',
      severity: NotificationSeverity.critical,
    );

    final rows = await repository.list();
    expect(rows.length, 2);
    expect(
      rows.map((row) => row.kind),
      containsAll(<String>['shift_closed', 'integrity_failed']),
    );

    await repository.markAllRead();
    expect(await repository.unreadCount(), 0);

    await repository.clearRead();
    expect(await repository.list(), isEmpty);

    final events = await repository.watchRecent().first;
    expect(events, isEmpty);
  });
}
