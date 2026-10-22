/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : draft_repository_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Encrypted draft round trip, UOM/price preservation, clearing
 *               on an empty cart, malformed JSON tolerance, and controller
 *               restoration of customer and payment state.
 * </pre>
 */

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/models/cart_draft.dart';
import 'package:ipos/data/models/cart_line.dart';
import 'package:ipos/data/models/catalog_part.dart';
import 'package:ipos/data/models/customer_option.dart';
import 'package:ipos/data/repositories/checkout_repository.dart';
import 'package:ipos/data/repositories/draft_repository.dart';
import 'package:ipos/features/register/checkout_controller.dart';

CartDraft _draft() {
  final part = CatalogPart(
    id: 'part-1',
    sku: 'SKU-1',
    oemNumber: 'OEM-1',
    partName: 'Brake Pad',
    brand: 'ACME',
    retailPriceCents: 12500,
    tradePriceCents: 11000,
    coreFeeCents: 500,
    baseUnit: 'EA',
    updatedAt: DateTime.utc(2026, 10, 20),
    uomOptions: const [UomOption(label: 'BOX', factor: 12)],
  );
  return CartDraft(
    lines: [
      CartLine(
        part: part,
        quantity: 2,
        uom: const UomOption(label: 'BOX', factor: 12),
      ),
    ],
    customerId: 'customer-1',
    paymentMethod: 'card',
    updatedAt: DateTime.utc(2026, 10, 22, 10, 15),
  );
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('round-trips lines, UOM, customer, and payment method', () async {
    final repository = DraftRepository(database);
    await repository.save('user-1', _draft());

    final loaded = await repository.load('user-1');

    expect(loaded, isNotNull);
    expect(loaded!.customerId, 'customer-1');
    expect(loaded.paymentMethod, 'card');
    expect(loaded.updatedAt, DateTime.utc(2026, 10, 22, 10, 15));
    final line = loaded.lines.single;
    expect(line.part.partName, 'Brake Pad');
    expect(line.part.retailPriceCents, 12500);
    expect(line.part.coreFeeCents, 500);
    expect(line.part.uomOptions.single.factor, 12);
    expect(line.uom.label, 'BOX');
    expect(line.quantity, 2);
  });

  test('empty draft clears the stored row', () async {
    final repository = DraftRepository(database);
    await repository.save('user-1', _draft());
    await repository.save(
      'user-1',
      CartDraft(
        lines: const <CartLine>[],
        paymentMethod: 'cash',
        updatedAt: DateTime.utc(2026, 10, 22),
      ),
    );

    expect(await repository.load('user-1'), isNull);
  });

  test('malformed JSON is treated as no draft', () async {
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            settingKey: DraftRepository.keyFor('user-1'),
            settingValue: jsonEncode(<String, Object?>{'lines': 'broken'}),
            updatedAt: DateTime.utc(2026, 10, 22),
          ),
        );

    expect(await DraftRepository(database).load('user-1'), isNull);
  });

  test('controller restores lines, customer, and payment method', () {
    final controller = CheckoutController(
      repository: CheckoutRepository(database),
    );
    addTearDown(controller.dispose);
    const customer = CustomerOption(id: 'customer-1', displayName: 'ACME');

    controller.restoreDraft(_draft(), customer: customer);

    expect(controller.lines.single.part.sku, 'SKU-1');
    expect(controller.itemCount, 2);
    expect(controller.selectedCustomer, customer);
    expect(controller.paymentMethod, PaymentMethod.card);

    controller.resetSession();
    expect(controller.lines, isEmpty);
    expect(controller.selectedCustomer, isNull);
    expect(controller.paymentMethod, PaymentMethod.cash);
  });
}
