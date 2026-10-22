/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.test.data
 * - File      : keyed_memory_repository_test.dart
 * - Date      : 2026. 10. 23.
 * - User      : NTAGANIRA H.
 * - Desc      : Exercises the production repositories against a keyed
 *               in-memory SQLCipher database. Proves settings, drafts, RBAC,
 *               customers, catalog search, checkout, outbox, notifications,
 *               and the hash-chained audit trail all work without a file and
 *               without dropping to raw SQLite for business reads.
 * </pre>
 */

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipos/data/database/app_database.dart';
import 'package:ipos/data/models/cart_draft.dart';
import 'package:ipos/data/models/cart_line.dart';
import 'package:ipos/data/models/customer_account.dart';
import 'package:ipos/data/repositories/audit_repository.dart';
import 'package:ipos/data/repositories/auth_repository.dart';
import 'package:ipos/data/repositories/catalog_repository.dart';
import 'package:ipos/data/repositories/checkout_repository.dart';
import 'package:ipos/data/repositories/customer_repository.dart';
import 'package:ipos/data/repositories/draft_repository.dart';
import 'package:ipos/data/repositories/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute("PRAGMA key = \"x'$key'\";");
          raw.execute('PRAGMA cipher_compatibility = 4;');
          raw.execute('PRAGMA foreign_keys = ON;');
          raw.select('SELECT count(*) FROM sqlite_master;');
        },
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('repositories read and write through keyed in-memory storage', () async {
    final cipherVersion = await database
        .customSelect('PRAGMA cipher_version')
        .getSingleOrNull();
    expect(cipherVersion, isNotNull);
    expect(
      cipherVersion!.data.values.first.toString(),
      isNotEmpty,
      reason: 'the in-memory connection must still be SQLCipher',
    );

    final auth = AuthRepository(database);
    final bootstrap = await auth.ensureBootstrap();
    expect(bootstrap.createdAdministrator, isTrue);
    final admin = await auth.authenticate(
      userId: AuthRepository.defaultAdminId,
      pin: AuthRepository.defaultAdminPin,
    );
    expect(admin, isNotNull);
    expect(admin!.mustChangePin, isTrue);

    final settingsRepository = SettingsRepository(database);
    final initial = await settingsRepository.load();
    expect(initial.deviceId, isNotEmpty);
    final saved = initial.copyWith(
      storeName: 'Keyed Memory Parts',
      taxRateBps: 1850,
      scannerMinLength: 6,
      scannerTimeoutMs: 55,
      emailPassword: 'smtp-secret-value',
      syncToken: 'sync-secret-value',
    );
    await settingsRepository.save(saved);
    final reloaded = await SettingsRepository(database).load();
    expect(reloaded.storeName, 'Keyed Memory Parts');
    expect(reloaded.taxRateBps, 1850);
    expect(reloaded.scannerMinLength, 6);
    expect(reloaded.scannerTimeoutMs, 55);
    expect(reloaded.deviceId, initial.deviceId);
    expect(reloaded.emailPassword, 'smtp-secret-value');

    final customerRepository = CustomerRepository(database);
    final customerId = await customerRepository.create(
      const CustomerDraft(
        displayName: 'Keyed Account',
        phone: '0788000111',
        balanceCents: 2500,
      ),
    );
    final customers = await customerRepository.list(term: 'Keyed');
    expect(customers.single.id, customerId);
    expect(customers.single.balanceCents, 2500);

    await database.customStatement('''
        INSERT INTO products (
          id, sku, part_name, retail_price, core_fee_cents, base_unit,
          updated_at, is_synced, is_deleted
        ) VALUES ('p1', 'BRK-1', 'Brake pad', 5000, 1000, 'EA', 1700000000, 0, 0)
      ''');

    final catalog = CatalogRepository(database);
    final parts = await catalog.searchCatalog(term: 'BRK-1');
    expect(parts.single.sku, 'BRK-1');

    final draftRepository = DraftRepository(database);
    final draft = CartDraft(
      lines: [CartLine(part: parts.single, quantity: 2)],
      customerId: customerId,
      paymentMethod: 'cash',
      updatedAt: DateTime.utc(2026, 10, 23),
    );
    await draftRepository.save(admin.id, draft);
    final restored = await draftRepository.load(admin.id);
    expect(restored, isNotNull);
    expect(restored!.lines.single.part.sku, 'BRK-1');
    expect(restored.lines.single.quantity, 2);
    expect(restored.customerId, customerId);
    await draftRepository.clear(admin.id);
    expect(await draftRepository.load(admin.id), isNull);

    final checkout = CheckoutRepository(database);
    final options = await checkout.activeCustomers();
    expect(options.single.id, customerId);
    final result = await checkout.commitSale(
      lines: [CartLine(part: parts.single, quantity: 1)],
      customer: options.single,
      taxRateBps: reloaded.taxRateBps,
      paymentMethod: 'Cash',
    );
    expect(result.invoiceNumber, matches(RegExp(r'^INV-\d{8}-\d{5}$')));
    expect(result.subtotalCents, 5000);
    expect(result.taxCents, 925);
    expect(result.coreFeeCents, 1000);
    expect(result.totalCents, 6925);

    final invoice = await database
        .customSelect(
          'SELECT * FROM invoices WHERE id = ?',
          variables: [Variable.withString(result.invoiceId)],
        )
        .getSingle();
    expect(invoice.read<String>('payment_method'), 'cash');
    expect(invoice.read<int>('total_cents'), 6925);

    final lineCount = await database
        .customSelect('SELECT COUNT(*) AS c FROM invoice_lines')
        .getSingle();
    expect(lineCount.read<int>('c'), 1);
    final movementCount = await database
        .customSelect('SELECT COUNT(*) AS c FROM stock_ledger')
        .getSingle();
    expect(movementCount.read<int>('c'), 1);
    final outboxCount = await database
        .customSelect('SELECT COUNT(*) AS c FROM sync_outbox')
        .getSingle();
    expect(outboxCount.read<int>('c'), greaterThan(0));
    final notificationCount = await database
        .customSelect('SELECT COUNT(*) AS c FROM app_notifications')
        .getSingle();
    expect(notificationCount.read<int>('c'), greaterThan(0));

    final settingsAudit = await database.customSelect('''
          SELECT before_json, after_json FROM audit_events
          WHERE event_type = 'settings.updated'
        ''').getSingle();
    final auditJson =
        '${settingsAudit.readNullable<String>('before_json')}'
        '${settingsAudit.readNullable<String>('after_json')}';
    expect(auditJson, isNot(contains('smtp-secret-value')));
    expect(auditJson, isNot(contains('sync-secret-value')));

    final verification = await AuditRepository(database).verifyChain();
    expect(verification.isValid, isTrue);
    expect(verification.checkedEvents, greaterThanOrEqualTo(4));
  });
}
