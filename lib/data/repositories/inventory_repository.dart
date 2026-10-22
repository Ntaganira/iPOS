/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.repositories
 * - File      : inventory_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Product master and stock administration. Every mutation writes
 *               the business row, its sync-outbox revision, and an audit event
 *               in one transaction. Stock is append-only through the ledger;
 *               product edits use soft-delete tombstones. UOM conversions are
 *               validated against the product base unit so split-pack stock
 *               deductions remain exact.
 * </pre>
 */

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/catalog_part.dart';
import '../models/inventory_product.dart';
import 'audit_repository.dart';

/// Inventory administration gateway.
class InventoryRepository {
  InventoryRepository(this._database, {AuditActor? Function()? actorProvider})
    : _audit = AuditRepository(_database, actorProvider: actorProvider),
      _uuid = Uuid();

  final AppDatabase _database;
  final AuditRepository _audit;
  final Uuid _uuid;

  Future<List<InventoryProduct>> listProducts({
    String? term,
    int limit = 500,
  }) async {
    final normalized = term?.trim() ?? '';
    final variables = <Variable<Object>>[];
    var filter = 'p.is_deleted = 0';
    if (normalized.isNotEmpty) {
      final pattern = '%${_escapeLike(normalized)}%';
      filter +=
          " AND (p.sku LIKE ? ESCAPE '\\' "
          "OR p.oem_number LIKE ? ESCAPE '\\' "
          "OR p.part_name LIKE ? ESCAPE '\\' "
          "OR p.brand LIKE ? ESCAPE '\\')";
      variables
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern));
    }
    variables.add(Variable.withInt(limit.clamp(1, 1000).toInt()));

    final rows = await _database.customSelect('''
            SELECT p.id, p.sku, p.oem_number, p.part_name, p.brand,
                   p.retail_price, p.trade_price, p.core_fee_cents,
                   p.base_unit, p.updated_at,
                   COALESCE((
                     SELECT SUM(l.qty_delta)
                     FROM stock_ledger l
                     WHERE l.product_id = p.id
                   ), 0) AS stock_on_hand
            FROM products p
            WHERE $filter
            ORDER BY p.part_name COLLATE NOCASE
            LIMIT ?
          ''', variables: variables).get();

    final products = rows.map(_mapProduct).toList(growable: false);
    return _withUom(products);
  }

  Future<InventoryProduct?> findProduct(String productId) async {
    final row = await _database
        .customSelect(
          '''
            SELECT p.id, p.sku, p.oem_number, p.part_name, p.brand,
                   p.retail_price, p.trade_price, p.core_fee_cents,
                   p.base_unit, p.updated_at,
                   COALESCE((
                     SELECT SUM(l.qty_delta)
                     FROM stock_ledger l
                     WHERE l.product_id = p.id
                   ), 0) AS stock_on_hand
            FROM products p
            WHERE p.id = ? AND p.is_deleted = 0
          ''',
          variables: [Variable.withString(productId)],
        )
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    final hydrated = await _withUom([_mapProduct(row)]);
    return hydrated.single;
  }

  Future<String> createProduct(ProductDraft draft) async {
    final normalized = _normalizeDraft(draft);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      final duplicate = await _database
          .customSelect(
            '''
              SELECT 1 AS found FROM products
              WHERE sku = ? COLLATE NOCASE AND is_deleted = 0
              LIMIT 1
            ''',
            variables: [Variable.withString(normalized.sku)],
          )
          .getSingleOrNull();
      if (duplicate != null) {
        throw StateError(
          'A product with SKU ${normalized.sku} already exists.',
        );
      }

      await _database
          .into(_database.products)
          .insert(
            ProductsCompanion.insert(
              id: id,
              sku: normalized.sku,
              oemNumber: Value(normalized.oemNumber),
              partName: normalized.partName,
              brand: Value(normalized.brand),
              retailPrice: normalized.retailPriceCents,
              tradePrice: Value(normalized.tradePriceCents),
              coreFeeCents: Value(normalized.coreFeeCents),
              baseUnit: Value(normalized.baseUnit),
              updatedAt: now,
            ),
          );

      await _enqueueProduct(id, normalized, now, operation: 'upsert');
      await _audit.append(
        eventType: 'inventory.product_created',
        action: 'create',
        entityType: 'product',
        entityId: id,
        message: 'Product ${normalized.sku} created.',
        after: _draftSnapshot(normalized),
      );
    });
    return id;
  }

  Future<void> updateProduct(String productId, ProductDraft draft) async {
    final normalized = _normalizeDraft(draft);
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      final duplicate = await _database
          .customSelect(
            '''
              SELECT 1 AS found FROM products
              WHERE sku = ? COLLATE NOCASE
                AND is_deleted = 0
                AND id <> ?
              LIMIT 1
            ''',
            variables: [
              Variable.withString(normalized.sku),
              Variable.withString(productId),
            ],
          )
          .getSingleOrNull();
      if (duplicate != null) {
        throw StateError(
          'A product with SKU ${normalized.sku} already exists.',
        );
      }

      final existing = await (_database.select(
        _database.products,
      )..where((table) => table.id.equals(productId))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Product not found.');
      }

      final changed =
          await (_database.update(
            _database.products,
          )..where((table) => table.id.equals(productId))).write(
            ProductsCompanion(
              sku: Value(normalized.sku),
              oemNumber: Value(normalized.oemNumber),
              partName: Value(normalized.partName),
              brand: Value(normalized.brand),
              retailPrice: Value(normalized.retailPriceCents),
              tradePrice: Value(normalized.tradePriceCents),
              coreFeeCents: Value(normalized.coreFeeCents),
              baseUnit: Value(normalized.baseUnit),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );
      if (changed == 0) {
        throw StateError('Product not found.');
      }

      await _enqueueProduct(productId, normalized, now, operation: 'upsert');
      await _audit.append(
        eventType: 'inventory.product_updated',
        action: 'update',
        entityType: 'product',
        entityId: productId,
        message: 'Product ${existing.sku} updated.',
        before: _productSnapshot(existing),
        after: _draftSnapshot(normalized),
      );
    });
  }

  Future<void> softDeleteProduct(String productId) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      final product = await (_database.select(
        _database.products,
      )..where((table) => table.id.equals(productId))).getSingleOrNull();
      if (product == null) {
        return;
      }

      await (_database.update(
        _database.products,
      )..where((table) => table.id.equals(productId))).write(
        ProductsCompanion(
          isDeleted: const Value(true),
          isSynced: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _enqueue(
        entityType: 'product',
        entityId: productId,
        operation: 'delete',
        payload: <String, Object?>{
          'id': productId,
          'updated_at': now.toIso8601String(),
          'is_deleted': true,
        },
        now: now,
      );
      await _audit.append(
        eventType: 'inventory.product_deleted',
        action: 'delete',
        entityType: 'product',
        entityId: productId,
        message: 'Product ${product.sku} tombstoned.',
        before: _productSnapshot(product),
        after: const <String, Object?>{'is_deleted': true},
      );
    });
  }

  Future<void> adjustStock({
    required String productId,
    required int qtyDelta,
    required String reason,
    String binLocation = 'BACK',
  }) async {
    if (qtyDelta == 0) {
      throw ArgumentError.value(qtyDelta, 'qtyDelta', 'Must not be zero.');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A reason is required.');
    }

    final now = DateTime.now().toUtc();
    final movementId = _uuid.v4();
    await _database.transaction(() async {
      final stockRow = await _database
          .customSelect(
            '''
              SELECT COALESCE(SUM(qty_delta), 0) AS on_hand
              FROM stock_ledger
              WHERE product_id = ?
            ''',
            variables: [Variable.withString(productId)],
          )
          .getSingle();
      final onHandBefore = stockRow.read<int>('on_hand');

      await _database
          .into(_database.stockLedger)
          .insert(
            StockLedgerCompanion.insert(
              id: movementId,
              productId: productId,
              binLocation: binLocation,
              qtyDelta: qtyDelta,
              referenceType: const Value('adjustment'),
              updatedAt: now,
            ),
          );
      await _enqueue(
        entityType: 'stock_ledger',
        entityId: movementId,
        operation: 'upsert',
        payload: <String, Object?>{
          'id': movementId,
          'product_id': productId,
          'bin_location': binLocation,
          'qty_delta': qtyDelta,
          'reference_type': 'adjustment',
          'updated_at': now.toIso8601String(),
        },
        now: now,
      );
      await _audit.append(
        eventType: 'inventory.stock_adjusted',
        action: 'update',
        entityType: 'product',
        entityId: productId,
        message: 'Stock adjusted by $qtyDelta ($normalizedReason).',
        before: <String, Object?>{'on_hand': onHandBefore},
        after: <String, Object?>{'on_hand': onHandBefore + qtyDelta},
        payload: <String, Object?>{
          'qty_delta': qtyDelta,
          'reason': normalizedReason,
          'bin_location': binLocation,
          'movement_id': movementId,
        },
      );
    });
  }

  Future<void> saveUom({
    required String productId,
    required String fromUnit,
    required int factor,
  }) async {
    final label = fromUnit.trim().toUpperCase();
    if (label.isEmpty || label.length > 16) {
      throw ArgumentError.value(fromUnit, 'fromUnit', 'Invalid unit label.');
    }
    if (factor < 2) {
      throw ArgumentError.value(factor, 'factor', 'Factor must be at least 2.');
    }

    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      final product = await (_database.select(
        _database.products,
      )..where((table) => table.id.equals(productId))).getSingleOrNull();
      if (product == null) {
        throw StateError('Product not found.');
      }
      if (label == product.baseUnit.toUpperCase()) {
        throw ArgumentError('A conversion cannot target the base unit.');
      }

      final existing = await _database
          .customSelect(
            '''
              SELECT id FROM uom_conversions
              WHERE product_id = ? AND from_unit = ? AND to_unit = ?
              LIMIT 1
            ''',
            variables: [
              Variable.withString(productId),
              Variable.withString(label),
              Variable.withString(product.baseUnit),
            ],
          )
          .getSingleOrNull();
      final id = existing?.read<String>('id') ?? _uuid.v4();
      final previousFactor = existing == null
          ? null
          : await _database
                .customSelect(
                  'SELECT factor FROM uom_conversions WHERE id = ?',
                  variables: [Variable.withString(id)],
                )
                .getSingle()
                .then((row) => row.read<int>('factor'));

      await _database
          .into(_database.uomConversions)
          .insertOnConflictUpdate(
            UomConversionsCompanion.insert(
              id: id,
              productId: productId,
              fromUnit: label,
              toUnit: product.baseUnit,
              factor: factor,
              updatedAt: now,
            ),
          );
      await _enqueue(
        entityType: 'uom_conversion',
        entityId: id,
        operation: 'upsert',
        payload: <String, Object?>{
          'id': id,
          'product_id': productId,
          'from_unit': label,
          'to_unit': product.baseUnit,
          'factor': factor,
          'updated_at': now.toIso8601String(),
          'is_deleted': false,
        },
        now: now,
      );
      await _audit.append(
        eventType: 'inventory.uom_saved',
        action: previousFactor == null ? 'create' : 'update',
        entityType: 'product',
        entityId: productId,
        message: 'Selling unit $label = $factor ${product.baseUnit}.',
        before: previousFactor == null
            ? null
            : <String, Object?>{'from_unit': label, 'factor': previousFactor},
        after: <String, Object?>{
          'from_unit': label,
          'to_unit': product.baseUnit,
          'factor': factor,
        },
      );
    });
  }

  Future<void> removeUom(String uomId) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      final uom = await (_database.select(
        _database.uomConversions,
      )..where((table) => table.id.equals(uomId))).getSingleOrNull();
      if (uom == null) {
        return;
      }
      await (_database.update(
        _database.uomConversions,
      )..where((table) => table.id.equals(uomId))).write(
        UomConversionsCompanion(
          isDeleted: const Value(true),
          isSynced: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _enqueue(
        entityType: 'uom_conversion',
        entityId: uomId,
        operation: 'delete',
        payload: <String, Object?>{
          'id': uomId,
          'updated_at': now.toIso8601String(),
          'is_deleted': true,
        },
        now: now,
      );
      await _audit.append(
        eventType: 'inventory.uom_removed',
        action: 'delete',
        entityType: 'product',
        entityId: uom.productId,
        message: 'Selling unit ${uom.fromUnit} removed.',
        before: <String, Object?>{
          'from_unit': uom.fromUnit,
          'to_unit': uom.toUnit,
          'factor': uom.factor,
        },
        after: const <String, Object?>{'is_deleted': true},
      );
    });
  }

  /// Resolves a selling unit by product and label, then tombstones it. Returns
  /// false when no active conversion matches.
  Future<bool> removeUomByProductAndLabel({
    required String productId,
    required String label,
  }) async {
    final row = await _database
        .customSelect(
          '''
            SELECT id FROM uom_conversions
            WHERE product_id = ? AND from_unit = ? AND is_deleted = 0
            LIMIT 1
          ''',
          variables: [
            Variable.withString(productId),
            Variable.withString(label.trim().toUpperCase()),
          ],
        )
        .getSingleOrNull();
    if (row == null) {
      return false;
    }
    await removeUom(row.read<String>('id'));
    return true;
  }

  Future<List<StockMovement>> listMovements(
    String productId, {
    int limit = 100,
  }) async {
    final rows = await _database
        .customSelect(
          '''
            SELECT id, qty_delta, bin_location, reference_type, reference_id,
                   updated_at
            FROM stock_ledger
            WHERE product_id = ?
            ORDER BY updated_at DESC
            LIMIT ?
          ''',
          variables: [
            Variable.withString(productId),
            Variable.withInt(limit.clamp(1, 500).toInt()),
          ],
        )
        .get();

    return rows
        .map(
          (row) => StockMovement(
            id: row.read<String>('id'),
            qtyDelta: row.read<int>('qty_delta'),
            binLocation: row.read<String>('bin_location'),
            referenceType: row.read<String>('reference_type'),
            referenceId: row.readNullable<String>('reference_id'),
            occurredAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('updated_at') * 1000,
              isUtc: true,
            ),
          ),
        )
        .toList(growable: false);
  }

  ProductDraft _normalizeDraft(ProductDraft draft) {
    final sku = draft.sku.trim().toUpperCase();
    final name = draft.partName.trim();
    final baseUnit = draft.baseUnit.trim().toUpperCase();
    if (sku.isEmpty) {
      throw ArgumentError.value(draft.sku, 'sku', 'SKU is required.');
    }
    if (name.isEmpty) {
      throw ArgumentError.value(
        draft.partName,
        'partName',
        'Description is required.',
      );
    }
    if (draft.retailPriceCents < 0 || draft.coreFeeCents < 0) {
      throw ArgumentError('Prices and core fees cannot be negative.');
    }
    if (baseUnit.isEmpty || baseUnit.length > 16) {
      throw ArgumentError.value(
        draft.baseUnit,
        'baseUnit',
        'Base unit is required.',
      );
    }
    return ProductDraft(
      sku: sku,
      partName: name,
      retailPriceCents: draft.retailPriceCents,
      oemNumber: _blankToNull(draft.oemNumber),
      brand: _blankToNull(draft.brand),
      tradePriceCents: draft.tradePriceCents,
      coreFeeCents: draft.coreFeeCents,
      baseUnit: baseUnit,
    );
  }

  Future<void> _enqueueProduct(
    String productId,
    ProductDraft draft,
    DateTime now, {
    required String operation,
  }) {
    return _enqueue(
      entityType: 'product',
      entityId: productId,
      operation: operation,
      payload: <String, Object?>{
        'id': productId,
        'sku': draft.sku,
        'oem_number': draft.oemNumber,
        'part_name': draft.partName,
        'brand': draft.brand,
        'retail_price': draft.retailPriceCents,
        'trade_price': draft.tradePriceCents,
        'core_fee_cents': draft.coreFeeCents,
        'base_unit': draft.baseUnit,
        'updated_at': now.toIso8601String(),
        'is_deleted': false,
      },
      now: now,
    );
  }

  Future<void> _enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    required DateTime now,
  }) async {
    await _database
        .into(_database.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payloadJson: jsonEncode(payload),
            occurredAt: now,
          ),
        );
  }

  InventoryProduct _mapProduct(QueryRow row) {
    return InventoryProduct(
      id: row.read<String>('id'),
      sku: row.read<String>('sku'),
      oemNumber: row.readNullable<String>('oem_number'),
      partName: row.read<String>('part_name'),
      brand: row.readNullable<String>('brand'),
      retailPriceCents: row.read<int>('retail_price'),
      tradePriceCents: row.readNullable<int>('trade_price'),
      coreFeeCents: row.read<int>('core_fee_cents'),
      baseUnit: row.read<String>('base_unit'),
      stockOnHand: row.read<int>('stock_on_hand'),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at') * 1000,
        isUtc: true,
      ),
    );
  }

  Future<List<InventoryProduct>> _withUom(
    List<InventoryProduct> products,
  ) async {
    if (products.isEmpty) {
      return products;
    }
    final placeholders = List<String>.filled(products.length, '?').join(', ');
    final rows = await _database.customSelect(
      '''
        SELECT id, product_id, from_unit, factor
        FROM uom_conversions
        WHERE is_deleted = 0 AND product_id IN ($placeholders)
        ORDER BY factor ASC
      ''',
      variables: products
          .map((product) => Variable.withString(product.id))
          .toList(growable: false),
    ).get();

    final byProduct = <String, List<UomOption>>{};
    for (final row in rows) {
      byProduct
          .putIfAbsent(row.read<String>('product_id'), () => <UomOption>[])
          .add(
            UomOption(
              label: row.read<String>('from_unit'),
              factor: row.read<int>('factor'),
            ),
          );
    }

    return products
        .map(
          (product) => InventoryProduct(
            id: product.id,
            sku: product.sku,
            oemNumber: product.oemNumber,
            partName: product.partName,
            brand: product.brand,
            retailPriceCents: product.retailPriceCents,
            tradePriceCents: product.tradePriceCents,
            coreFeeCents: product.coreFeeCents,
            baseUnit: product.baseUnit,
            stockOnHand: product.stockOnHand,
            updatedAt: product.updatedAt,
            uomOptions: byProduct[product.id] ?? const <UomOption>[],
          ),
        )
        .toList(growable: false);
  }

  Map<String, Object?> _productSnapshot(ProductRow product) {
    return <String, Object?>{
      'sku': product.sku,
      'oem_number': product.oemNumber,
      'part_name': product.partName,
      'brand': product.brand,
      'retail_price_cents': product.retailPrice,
      'trade_price_cents': product.tradePrice,
      'core_fee_cents': product.coreFeeCents,
      'base_unit': product.baseUnit,
      'is_deleted': product.isDeleted,
    };
  }

  Map<String, Object?> _draftSnapshot(ProductDraft draft) {
    return <String, Object?>{
      'sku': draft.sku,
      'oem_number': draft.oemNumber,
      'part_name': draft.partName,
      'brand': draft.brand,
      'retail_price_cents': draft.retailPriceCents,
      'trade_price_cents': draft.tradePriceCents,
      'core_fee_cents': draft.coreFeeCents,
      'base_unit': draft.baseUnit,
      'is_deleted': false,
    };
  }

  String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
