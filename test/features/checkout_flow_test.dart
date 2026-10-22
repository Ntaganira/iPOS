/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.features
 * - File      : checkout_flow_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Interaction tests for cart mutation and receipt flows. Drives
 *               the real checkout panel and controllers against an in-memory
 *               ledger, then verifies the paper chooser hands the committed or
 *               proforma document to the printer callback.
 * </pre>
 */

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/printing/esc_pos_printer.dart';
import 'package:ipos/core/printing/receipt_paper.dart';
import 'package:ipos/core/theme/app_theme.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/models/catalog_part.dart';
import 'package:ipos/data/repositories/checkout_repository.dart';
import 'package:ipos/features/register/checkout_controller.dart';
import 'package:ipos/features/register/widgets/checkout_panel.dart';
import 'package:ipos/l10n/generated/app_localizations.dart';
import 'package:ipos/l10n/rw_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late CheckoutController controller;
  late CatalogPart part;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final seedTime = DateTime.utc(2026, 10, 22, 8);
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
    part = CatalogPart(
      id: 'part-1',
      sku: 'SKU-100',
      oemNumber: 'OEM-100',
      partName: 'Brake Pad Front',
      brand: 'Aisin',
      retailPriceCents: 12500,
      updatedAt: seedTime,
    );
    controller = CheckoutController(repository: CheckoutRepository(database));
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    Future<void> Function(ReceiptDocument, ReceiptPaperSize)? onPrint,
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: iposLocalizationsDelegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 460,
              height: 820,
              child: CheckoutPanel(controller: controller, onPrint: onPrint),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('stepper and remove controls mutate the cart', (tester) async {
    controller.addPart(part);
    await pumpPanel(tester);

    expect(find.text('Brake Pad Front'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(controller.itemCount, 2);
    expect(controller.totalCents, 29500);

    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pump();
    expect(controller.itemCount, 1);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(controller.lines, isEmpty);
    expect(find.text('Brake Pad Front'), findsNothing);
  });

  testWidgets('committed sale prints the previewed thermal receipt', (
    tester,
  ) async {
    final printed = <(ReceiptDocument, ReceiptPaperSize)>[];
    controller.addPart(part);
    await pumpPanel(
      tester,
      onPrint: (document, paper) async => printed.add((document, paper)),
    );

    await tester.tap(find.text('Charge'));
    await tester.pumpAndSettle();
    expect(find.text('Sale completed'), findsOneWidget);

    await tester.tap(find.text('Print receipt'));
    await tester.pumpAndSettle();
    expect(find.text('Print preview'), findsOneWidget);

    await tester.tap(find.text('58 mm mini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();

    expect(printed, hasLength(1));
    final (document, paper) = printed.single;
    expect(paper, ReceiptPaperSize.mm58);
    expect(document.kind, ReceiptKind.sale);
    expect(document.totalCents, 14750);
    expect(controller.lines, isEmpty);
  });

  testWidgets('proforma preview prints without writing an invoice', (
    tester,
  ) async {
    final printed = <(ReceiptDocument, ReceiptPaperSize)>[];
    controller.addPart(part);
    await pumpPanel(
      tester,
      onPrint: (document, paper) async => printed.add((document, paper)),
    );

    await tester.tap(find.text('Proforma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A4 invoice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();

    expect(printed, hasLength(1));
    final (document, paper) = printed.single;
    expect(paper, ReceiptPaperSize.a4);
    expect(document.kind, ReceiptKind.proforma);
    expect(document.invoiceNumber, startsWith('PRO-'));
    expect(controller.itemCount, 1);
    expect(await database.select(database.invoices).get(), isEmpty);
  });
}
