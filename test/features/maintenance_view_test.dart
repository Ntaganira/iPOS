/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.features
 * - File      : maintenance_view_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Confirms the key-rotation action is permission-gated, asks for
 *               confirmation, and invokes the administrator callback exactly
 *               once.
 * </pre>
 */

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/database/database_maintenance_service.dart';
import 'package:ipos/data/repositories/shift_repository.dart';
import 'package:ipos/features/settings/maintenance_view.dart';
import 'package:ipos/l10n/generated/app_localizations.dart';
import 'package:ipos/l10n/rw_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DatabaseMaintenanceService maintenance;
  late ShiftRepository shifts;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    maintenance = DatabaseMaintenanceService(database);
    shifts = ShiftRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpView(
    WidgetTester tester, {
    required bool canRotate,
    Future<void> Function()? onRotate,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: iposLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: MaintenanceView(
            maintenance: maintenance,
            shifts: shifts,
            canBackup: true,
            canCloseShift: true,
            canRotate: canRotate,
            onRotate: onRotate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
  }

  testWidgets('rotation is disabled without the keys.rotate permission', (
    tester,
  ) async {
    await pumpView(tester, canRotate: false);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('rotate-key-action')),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('administrator confirms before rotation runs', (tester) async {
    var rotations = 0;
    await pumpView(
      tester,
      canRotate: true,
      onRotate: () async => rotations += 1,
    );

    await tester.tap(find.byKey(const Key('rotate-key-action')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(rotations, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(rotations, 1);
  });
}
