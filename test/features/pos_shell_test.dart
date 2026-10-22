/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.features
 * - File      : pos_shell_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Responsive smoke tests for the register shell. Pumps the real
 *               controllers, in-memory ledger, responsive rail, catalog table,
 *               checkout panel, and checkout end drawer at desktop, tablet, and
 *               phone sizes, failing on any RenderFlex overflow or framework
 *               exception.
 * </pre>
 */

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/theme/app_theme.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/repositories/catalog_repository.dart';
import 'package:ipos/data/repositories/checkout_repository.dart';
import 'package:ipos/features/register/catalog_controller.dart';
import 'package:ipos/features/register/checkout_controller.dart';
import 'package:ipos/features/shell/pos_shell.dart';

void main() {
  late AppDatabase database;
  late CatalogController catalogController;
  late CheckoutController checkoutController;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final seedTime = DateTime.utc(2026, 10, 22, 8);

    await database
        .into(database.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: 'vehicle-1',
            make: 'Toyota',
            model: 'Hilux',
            year: 2018,
            updatedAt: seedTime,
          ),
        );
    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            id: 'part-1',
            sku: 'SKU-100',
            oemNumber: const Value('OEM-100'),
            partName: 'Brake Pad Front',
            brand: const Value('Aisin'),
            retailPrice: 12500,
            updatedAt: seedTime,
          ),
        );
    await database
        .into(database.productCompatibility)
        .insert(
          ProductCompatibilityCompanion.insert(
            id: 'fit-1',
            productId: 'part-1',
            vehicleId: 'vehicle-1',
            updatedAt: seedTime,
          ),
        );
    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'customer-1',
            displayName: 'Kigali Motor Works',
            phone: const Value('+250788000000'),
            updatedAt: seedTime,
          ),
        );

    catalogController = CatalogController(
      repository: CatalogRepository(database),
      searchDebounce: Duration.zero,
    );
    checkoutController = CheckoutController(
      repository: CheckoutRepository(database),
    );

    await catalogController.initialize();
    await checkoutController.initialize();
  });

  tearDown(() async {
    catalogController.dispose();
    checkoutController.dispose();
    await database.close();
  });

  Widget buildApp() {
    return MaterialApp(
      theme: AppTheme.dark,
      home: PosShell(
        catalogController: catalogController,
        checkoutController: checkoutController,
        isDarkMode: true,
        onToggleTheme: () {},
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('register renders without overflow across target sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const sizes = <Size>[
      Size(390, 844),
      Size(844, 390),
      Size(800, 600),
      Size(1024, 700),
      Size(1280, 800),
      Size(1920, 1080),
    ];

    for (final size in sizes) {
      await pumpAt(tester, size);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected layout exception at ${size.width}x${size.height}',
      );
      expect(find.text('Front Counter'), findsOneWidget);
    }
  });

  testWidgets('checkout opens as a drawer on tablet widths without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAt(tester, const Size(800, 600));
    expect(find.text('Cart'), findsOneWidget);

    await tester.tap(find.text('Cart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(tester.takeException(), isNull);
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('CUSTOMER ACCOUNT'), findsOneWidget);
  });

  testWidgets('inline checkout is present on desktop widths', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAt(tester, const Size(1280, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Cart'), findsNothing);
  });
}
