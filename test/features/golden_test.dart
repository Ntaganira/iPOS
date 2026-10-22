/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.features
 * - File      : golden_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Golden snapshots for the populated checkout panel and the
 *               receipt preview dialog. Roboto and Material Icons are loaded
 *               from test fixtures so text metrics match production rather
 *               than the Ahem test font. Baselines are generated on Windows;
 *               rerun `flutter test --update-goldens` on the target runner if
 *               Skia metrics differ.
 * </pre>
 */

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/printing/esc_pos_printer.dart';
import 'package:ipos/core/printing/receipt_paper.dart';
import 'package:ipos/core/theme/app_theme.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/models/catalog_part.dart';
import 'package:ipos/data/repositories/checkout_repository.dart';
import 'package:ipos/features/register/checkout_controller.dart';
import 'package:ipos/features/register/widgets/checkout_panel.dart';
import 'package:ipos/features/register/widgets/receipt_print_dialog.dart';
import 'package:ipos/l10n/generated/app_localizations.dart';
import 'package:ipos/l10n/rw_localizations.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(File(file).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

ReceiptDocument _document() {
  return ReceiptDocument(
    storeName: 'iPOS Parts Counter',
    invoiceNumber: 'INV-20261022-0001',
    issuedAt: DateTime.utc(2026, 10, 22, 9, 30),
    lines: const [
      CheckoutLineSnapshot(
        sku: 'SKU-100',
        partName: 'Brake Pad Front',
        quantity: 2,
        uomLabel: 'EA',
        unitPriceCents: 12500,
        lineTotalCents: 25000,
        coreFeeCents: 0,
      ),
    ],
    subtotalCents: 25000,
    taxCents: 4500,
    coreFeeCents: 0,
    totalCents: 29500,
    paymentMethod: 'cash',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final goldenSkip = !Platform.isWindows;

  setUpAll(() async {
    await _loadFont('Roboto', const [
      'test/fixtures/fonts/roboto-regular.ttf',
      'test/fixtures/fonts/roboto-medium.ttf',
      'test/fixtures/fonts/roboto-bold.ttf',
    ]);
    await _loadFont('MaterialIcons', const [
      'test/fixtures/fonts/materialicons-regular.otf',
    ]);
    await _loadFont('RobotoMono', const [
      'assets/fonts/RobotoMono-Regular.ttf',
    ]);
  });

  testWidgets('checkout panel golden', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final controller = CheckoutController(
      repository: CheckoutRepository(database),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.addPart(
      CatalogPart(
        id: 'part-1',
        sku: 'SKU-100',
        oemNumber: 'OEM-100',
        partName: 'Brake Pad Front',
        brand: 'Aisin',
        retailPriceCents: 12500,
        updatedAt: DateTime.utc(2026, 10, 22, 8),
      ),
    );

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
              child: CheckoutPanel(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CheckoutPanel),
      matchesGoldenFile('goldens/checkout_panel.png'),
    );
  }, skip: goldenSkip);

  testWidgets('receipt preview golden', (tester) async {
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
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showDialog<ReceiptPaperSize>(
                  context: context,
                  builder: (_) => ReceiptPrintDialog(document: _document()),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile('goldens/receipt_preview.png'),
    );
  }, skip: goldenSkip);
}
