/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.test.data
 * - File      : offline_ledger_test.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Integration tests for the offline ledger against an in-memory
 *               Drift database. Covers YMM catalog search, soft-delete filtering,
 *               transactional exact SKU/OEM lookup, integer VAT totals, invoice
 *               line snapshots, stock movements, daily invoice sequencing, and
 *               full rollback when a sale line cannot be persisted.
 * </pre>
 */

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwarehouse/data/database/app_database.dart';
import 'package:iwarehouse/data/models/cart_line.dart';
import 'package:iwarehouse/data/models/catalog_part.dart';
import 'package:iwarehouse/data/repositories/catalog_repository.dart';
import 'package:iwarehouse/data/repositories/checkout_repository.dart';

void main() {
  late AppDatabase database;
  late CatalogRepository catalog;
  late CheckoutRepository checkout;

  final seedTime = DateTime.utc(2026, 10, 22, 8);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(database);
    checkout = CheckoutRepository(database);

    await database
        .into(database.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: 'vehicle-active',
            make: 'Toyota',
            model: 'Hilux',
            year: 2018,
            updatedAt: seedTime,
          ),
        );
    await database
        .into(database.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: 'vehicle-deleted',
            make: 'Toyota',
            model: 'Hilux',
            year: 2018,
            updatedAt: seedTime,
            isDeleted: const Value(true),
          ),
        );

    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            id: 'part-active',
            sku: 'SKU-100',
            oemNumber: const Value('OEM-100'),
            partName: 'Brake Pad Front',
            brand: const Value('Aisin'),
            retailPrice: 12500,
            updatedAt: seedTime,
          ),
        );
    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            id: 'part-deleted',
            sku: 'SKU-DELETED',
            partName: 'Retired Pad',
            retailPrice: 9000,
            updatedAt: seedTime,
            isDeleted: const Value(true),
          ),
        );
    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            id: 'part-no-fit',
            sku: 'SKU-NOFIT',
            partName: 'Filter Element',
            retailPrice: 4500,
            updatedAt: seedTime,
          ),
        );

    await database
        .into(database.productCompatibility)
        .insert(
          ProductCompatibilityCompanion.insert(
            id: 'fit-active',
            productId: 'part-active',
            vehicleId: 'vehicle-active',
            updatedAt: seedTime,
          ),
        );
    await database
        .into(database.productCompatibility)
        .insert(
          ProductCompatibilityCompanion.insert(
            id: 'fit-deleted-vehicle',
            productId: 'part-active',
            vehicleId: 'vehicle-deleted',
            updatedAt: seedTime,
          ),
        );
    await database
        .into(database.productCompatibility)
        .insert(
          ProductCompatibilityCompanion.insert(
            id: 'fit-deleted-product',
            productId: 'part-deleted',
            vehicleId: 'vehicle-active',
            updatedAt: seedTime,
          ),
        );
    await database
        .into(database.productCompatibility)
        .insert(
          ProductCompatibilityCompanion.insert(
            id: 'fit-soft-deleted',
            productId: 'part-no-fit',
            vehicleId: 'vehicle-active',
            updatedAt: seedTime,
            isDeleted: const Value(true),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('YMM filters return only active products with active fitment', () async {
    final results = await catalog.searchCatalog(
      make: 'Toyota',
      model: 'Hilux',
      year: 2018,
    );

    expect(results.map((part) => part.id), ['part-active']);
    expect(results.single.partName, 'Brake Pad Front');
    expect(results.single.retailPriceCents, 12500);
  });

  test('YMM cascades exclude soft-deleted vehicles', () async {
    expect(await catalog.listMakes(), ['Toyota']);
    expect(await catalog.listModels(make: 'Toyota'), ['Hilux']);
    expect(await catalog.listYears(make: 'Toyota', model: 'Hilux'), [2018]);
  });

  test('exact lookup is case-insensitive and excludes deleted rows', () async {
    final bySku = await catalog.findCompatibleByNumber(
      vehicleId: 'vehicle-active',
      partNumber: ' sku-100 ',
    );
    final byOem = await catalog.findCompatibleByNumber(
      vehicleId: 'vehicle-active',
      partNumber: 'oem-100',
    );
    final deletedProduct = await catalog.findCompatibleByNumber(
      vehicleId: 'vehicle-active',
      partNumber: 'SKU-DELETED',
    );
    final deletedFitment = await catalog.findCompatibleByNumber(
      vehicleId: 'vehicle-active',
      partNumber: 'SKU-NOFIT',
    );
    final deletedVehicle = await catalog.findCompatibleByNumber(
      vehicleId: 'vehicle-deleted',
      partNumber: 'SKU-100',
    );

    expect(bySku.single.id, 'part-active');
    expect(byOem.single.id, 'part-active');
    expect(deletedProduct, isEmpty);
    expect(deletedFitment, isEmpty);
    expect(deletedVehicle, isEmpty);
  });

  test('checkout snapshots lines, tax, invoice sequence, and stock', () async {
    final part = CatalogPart(
      id: 'part-active',
      sku: 'SKU-100',
      oemNumber: 'OEM-100',
      partName: 'Brake Pad Front',
      brand: 'Aisin',
      retailPriceCents: 12500,
      updatedAt: seedTime,
    );

    final result = await checkout.commitSale(
      lines: [CartLine(part: part, quantity: 2)],
      customer: null,
      taxRateBps: 1800,
      paymentMethod: 'CASH',
    );

    expect(result.subtotalCents, 25000);
    expect(result.taxCents, 4500);
    expect(result.totalCents, 29500);
    expect(result.invoiceNumber, startsWith('INV-'));
    expect(result.invoiceNumber, endsWith('00001'));

    final invoices = await database.select(database.invoices).get();
    final lines = await database.select(database.invoiceLines).get();
    final movements = await database.select(database.stockLedger).get();

    expect(invoices, hasLength(1));
    expect(invoices.single.id, result.invoiceId);
    expect(invoices.single.paymentMethod, 'cash');
    expect(invoices.single.status, 'completed');
    expect(invoices.single.isSynced, isFalse);

    expect(lines, hasLength(1));
    expect(lines.single.skuSnapshot, 'SKU-100');
    expect(lines.single.partNameSnapshot, 'Brake Pad Front');
    expect(lines.single.unitPriceCents, 12500);
    expect(lines.single.quantity, 2);
    expect(lines.single.lineTotalCents, 25000);
    expect(lines.single.taxRateBps, 1800);

    expect(movements, hasLength(1));
    expect(movements.single.qtyDelta, -2);
    expect(movements.single.binLocation, 'FRONT');
    expect(movements.single.isSynced, isFalse);

    final second = await checkout.commitSale(
      lines: [CartLine(part: part, quantity: 1)],
      customer: null,
      taxRateBps: 1800,
      paymentMethod: 'card',
    );
    expect(second.invoiceNumber, endsWith('00002'));
    expect(second.totalCents, 14750);
  });

  test('a failing line rolls back the whole invoice transaction', () async {
    final ghost = CatalogPart(
      id: 'missing-product',
      sku: 'GHOST-1',
      partName: 'Missing Part',
      retailPriceCents: 1000,
      updatedAt: seedTime,
    );

    await expectLater(
      checkout.commitSale(
        lines: [CartLine(part: ghost, quantity: 1)],
        customer: null,
        taxRateBps: 1800,
        paymentMethod: 'cash',
      ),
      throwsA(anything),
    );

    expect(await database.select(database.invoices).get(), isEmpty);
    expect(await database.select(database.invoiceLines).get(), isEmpty);
    expect(await database.select(database.stockLedger).get(), isEmpty);
  });
}
