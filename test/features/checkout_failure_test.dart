/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.features
 * - File      : checkout_failure_test.dart
 * - Date      : 2026. 10. 23.
 * - User      : NTAGANIRA H.
 * - Desc      : Proves a failed charge never loses the cart, disk and key
 *               failures are classified for actionable operator messages, and
 *               a transient SQLITE_BUSY is retried exactly once before the
 *               operator sees an error.
 * </pre>
 */

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/core/storage/storage_failure.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/models/cart_line.dart';
import 'package:ipos/data/models/catalog_part.dart';
import 'package:ipos/data/models/customer_option.dart';
import 'package:ipos/data/repositories/checkout_repository.dart';
import 'package:ipos/features/register/checkout_controller.dart';

class _ScriptedCheckoutRepository extends CheckoutRepository {
  _ScriptedCheckoutRepository(super.database, this.failures);

  final List<Object> failures;
  int calls = 0;

  @override
  Future<CheckoutResult> commitSale({
    required List<CartLine> lines,
    required CustomerOption? customer,
    required int taxRateBps,
    required String paymentMethod,
  }) async {
    calls++;
    if (calls <= failures.length) {
      throw failures[calls - 1];
    }
    return CheckoutResult(
      invoiceId: 'invoice-$calls',
      invoiceNumber: 'INV-TEST-${calls.toString().padLeft(5, '0')}',
      subtotalCents: 5000,
      taxCents: 900,
      coreFeeCents: 0,
      totalCents: 5900,
      paymentMethod: paymentMethod,
      issuedAt: DateTime.utc(2026, 10, 23),
      lines: const <CheckoutLineSnapshot>[],
    );
  }
}

final _part = CatalogPart(
  id: 'part-1',
  sku: 'BRK-1',
  partName: 'Brake pad',
  retailPriceCents: 5000,
  updatedAt: DateTime.utc(2026, 10, 23),
);

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  CheckoutController buildController(List<Object> failures) {
    final controller = CheckoutController(
      repository: _ScriptedCheckoutRepository(database, failures),
      busyRetryDelay: Duration.zero,
    );
    addTearDown(controller.dispose);
    controller.addPart(_part);
    return controller;
  }

  test('disk-full failure keeps the cart and reports storage status', () async {
    final controller = buildController([Exception('database or disk is full')]);

    final result = await controller.completeSale();

    expect(result, isNull);
    expect(controller.failure, StorageFailure.diskFull);
    expect(controller.error, contains('Storage is full'));
    expect(controller.lines.single.part.sku, 'BRK-1');
    expect(controller.submitting, isFalse);
  });

  test(
    'lost vault key is never reported as a generic checkout error',
    () async {
      final controller = buildController([Exception('file is not a database')]);

      expect(await controller.completeSale(), isNull);
      expect(controller.failure, StorageFailure.keyLost);
      expect(controller.error, contains('vault key'));
      expect(controller.lines, hasLength(1));
    },
  );

  test('a busy ledger is retried once and then completes', () async {
    final repository = _ScriptedCheckoutRepository(database, [
      Exception('database is locked'),
    ]);
    final controller = CheckoutController(
      repository: repository,
      busyRetryDelay: Duration.zero,
    );
    addTearDown(controller.dispose);
    controller.addPart(_part);

    final result = await controller.completeSale();

    expect(result, isNotNull);
    expect(repository.calls, 2);
    expect(controller.failure, isNull);
    expect(controller.lines, isEmpty);
  });

  test('unknown failures preserve the cart with a safe message', () async {
    final controller = buildController([StateError('unexpected')]);

    expect(await controller.completeSale(), isNull);
    expect(controller.failure, StorageFailure.unknown);
    expect(controller.error, contains('Nothing was written'));
    expect(controller.lines, hasLength(1));
  });
}
