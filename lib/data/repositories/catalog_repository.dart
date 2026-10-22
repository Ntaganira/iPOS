/**
 * <pre>
 * - Project   : iWarehouse - Glass Warehouse &amp; Mobile POS (ERP-Lite)
 * - Package   : com.ntaganira.heritier.iWarehouse.data.repositories
 * - File      : catalog_repository.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Offline catalog access and fitment queries. Provides cascading
 *               YMM lists, a bounded escaped search across SKU/OEM/description,
 *               and the production exact-number lookup used by scanners. The
 *               lookup runs in an explicit transaction, filters soft-deleted
 *               products and fitment edges, and is supported by partial
 *               (vehicle_id, product_id) and SKU/OEM indexes.
 * </pre>
 */

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/catalog_part.dart';

/// Query gateway for the register catalog.
class CatalogRepository {
  CatalogRepository(this._database);

  final AppDatabase _database;

  /// Projection shared by all catalog reads. Column aliases are stable and map
  /// one-to-one to [CatalogPart].
  static const String _productColumns = '''
    p.id AS id,
    p.sku AS sku,
    p.oem_number AS oem_number,
    p.part_name AS part_name,
    p.brand AS brand,
    p.retail_price AS retail_price,
    p.trade_price AS trade_price,
    p.updated_at AS updated_at
  ''';

  /// Distinct makes for the first YMM dropdown.
  Future<List<String>> listMakes() async {
    final rows = await _database
        .customSelect('''
          SELECT DISTINCT make
          FROM vehicles
          WHERE is_deleted = 0 AND make <> ''
          ORDER BY make COLLATE NOCASE
        ''')
        .get();

    return rows
        .map((row) => row.read<String>('make'))
        .toList(growable: false);
  }

  /// Models available for a make. Returns an empty list for a null/blank make
  /// so the UI can safely cascade without issuing a full-table scan.
  Future<List<String>> listModels({required String make}) async {
    if (make.trim().isEmpty) {
      return const <String>[];
    }

    final rows = await _database.customSelect(
      '''
        SELECT DISTINCT model
        FROM vehicles
        WHERE is_deleted = 0
          AND make = ?
          AND model <> ''
        ORDER BY model COLLATE NOCASE
      ''',
      variables: [Variable.withString(make)],
    ).get();

    return rows
        .map((row) => row.read<String>('model'))
        .toList(growable: false);
  }

  /// Model years available for a make/model pair, newest first.
  Future<List<int>> listYears({
    required String make,
    required String model,
  }) async {
    if (make.trim().isEmpty || model.trim().isEmpty) {
      return const <int>[];
    }

    final rows = await _database.customSelect(
      '''
        SELECT DISTINCT year
        FROM vehicles
        WHERE is_deleted = 0
          AND make = ?
          AND model = ?
        ORDER BY year DESC
      ''',
      variables: [Variable.withString(make), Variable.withString(model)],
    ).get();

    return rows.map((row) => row.read<int>('year')).toList(growable: false);
  }

  /// Bounded catalog search used by the register.
  ///
  /// All fragments are parameterized. `%`, `_`, and `\` in operator input are
  /// escaped so a pasted SKU cannot accidentally become a full-table wildcard.
  /// A YMM filter is applied through an EXISTS fitment probe, which avoids
  /// duplicate product rows without forcing a DISTINCT projection. Exact
  /// SKU/OEM matches are ranked first for scanner and Enter-key flows.
  Future<List<CatalogPart>> searchCatalog({
    String? term,
    String? make,
    String? model,
    int? year,
    int limit = 200,
  }) async {
    final normalizedTerm = term?.trim() ?? '';
    final conditions = <String>['p.is_deleted = 0'];
    final variables = <Variable<Object>>[];

    final hasVehicleFilter =
        (make != null && make.trim().isNotEmpty) ||
        (model != null && model.trim().isNotEmpty) ||
        (year != null);

    if (hasVehicleFilter) {
      // EXISTS avoids duplicate product rows from multiple matching fitment
      // edges, so the order-by can rank exact SKU/OEM hits without wrapping the
      // projection in DISTINCT (SQLite forbids DISTINCT ordering by columns
      // that are not in the select list).
      final vehicleConditions = <String>[
        'pc.product_id = p.id',
        'pc.is_deleted = 0',
        'v.id = pc.vehicle_id',
        'v.is_deleted = 0',
      ];

      if (make != null && make.trim().isNotEmpty) {
        vehicleConditions.add('v.make = ?');
        variables.add(Variable.withString(make.trim()));
      }
      if (model != null && model.trim().isNotEmpty) {
        vehicleConditions.add('v.model = ?');
        variables.add(Variable.withString(model.trim()));
      }
      if (year != null) {
        vehicleConditions.add('v.year = ?');
        variables.add(Variable.withInt(year));
      }

      conditions.add('''
        EXISTS (
          SELECT 1
          FROM product_compatibility pc
          INNER JOIN vehicles v ON v.id = pc.vehicle_id
          WHERE ${vehicleConditions.join(' AND ')}
        )
      ''');
    }

    if (normalizedTerm.isNotEmpty) {
      final pattern = '%${_escapeLike(normalizedTerm)}%';
      conditions.add(
        "(p.sku LIKE ? ESCAPE '\\' "
        "OR p.oem_number LIKE ? ESCAPE '\\' "
        "OR p.part_name LIKE ? ESCAPE '\\')",
      );
      variables
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern));
    }

    final orderVariables = <Variable<Object>>[];
    var orderBy = 'p.part_name COLLATE NOCASE ASC';
    if (normalizedTerm.isNotEmpty) {
      // Rank exact scanner/operator matches ahead of partial description hits.
      orderBy =
          '''
          CASE
            WHEN p.sku = ? COLLATE NOCASE
              OR p.oem_number = ? COLLATE NOCASE
            THEN 0 ELSE 1
          END,
          p.part_name COLLATE NOCASE ASC
          ''';
      orderVariables
        ..add(Variable.withString(normalizedTerm))
        ..add(Variable.withString(normalizedTerm));
    }

    final safeLimit = limit.clamp(1, 500).toInt();
    final sql = '''
      SELECT $_productColumns
      FROM products p
      WHERE ${conditions.join(' AND ')}
      ORDER BY $orderBy
      LIMIT ?
    ''';

    final rows = await _database
        .customSelect(
          sql,
          variables: <Variable<Object>>[
            ...variables,
            ...orderVariables,
            Variable.withInt(safeLimit),
          ],
        )
        .get();

    return rows.map(_mapPart).toList(growable: false);
  }

  /// Exact aftermarket SKU or OEM cross-reference lookup for a single vehicle.
  ///
  /// This is the transactional path used by barcode scanners and keyboard
  /// submissions. Running the vehicle existence check and fitment lookup in one
  /// transaction gives a consistent snapshot even if a sync pull is applying
  /// catalog changes concurrently. Soft-deleted products and soft-deleted
  /// fitment edges are excluded on both sides of the join.
  ///
  /// Plan shape on SQLite:
  /// 1. Seek `product_compatibility` by partial index
  ///    `(vehicle_id, product_id) WHERE is_deleted = 0`.
  /// 2. Join `products` by UUID primary key.
  /// 3. Apply the exact case-insensitive identifier predicate and limit.
  Future<List<CatalogPart>> findCompatibleByNumber({
    required String vehicleId,
    required String partNumber,
  }) async {
    final normalizedVehicleId = vehicleId.trim();
    final normalizedPartNumber = partNumber.trim();
    if (normalizedVehicleId.isEmpty || normalizedPartNumber.isEmpty) {
      return const <CatalogPart>[];
    }

    return _database.transaction(() async {
      final vehicle = await _database
          .customSelect(
            '''
              SELECT 1 AS found
              FROM vehicles
              WHERE id = ? AND is_deleted = 0
              LIMIT 1
            ''',
            variables: [Variable.withString(normalizedVehicleId)],
          )
          .getSingleOrNull();

      if (vehicle == null) {
        return const <CatalogPart>[];
      }

      final rows = await _database
          .customSelect(
            '''
              SELECT DISTINCT $_productColumns
              FROM products p
              INNER JOIN product_compatibility pc
                ON pc.product_id = p.id
               AND pc.vehicle_id = ?
               AND pc.is_deleted = 0
              WHERE p.is_deleted = 0
                AND (
                  p.sku = ? COLLATE NOCASE
                  OR p.oem_number = ? COLLATE NOCASE
                )
              ORDER BY p.part_name COLLATE NOCASE
              LIMIT 50
            ''',
            variables: [
              Variable.withString(normalizedVehicleId),
              Variable.withString(normalizedPartNumber),
              Variable.withString(normalizedPartNumber),
            ],
          )
          .get();

      return rows.map(_mapPart).toList(growable: false);
    });
  }

  /// Escapes SQLite LIKE metacharacters. The repository always supplies an
  /// explicit `ESCAPE '\'` clause alongside these patterns.
  String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  /// Maps the stable SQL projection into the UI-facing immutable model.
  CatalogPart _mapPart(QueryRow row) {
    final updatedAtSeconds = row.read<int>('updated_at');
    return CatalogPart(
      id: row.read<String>('id'),
      sku: row.read<String>('sku'),
      oemNumber: row.readNullable<String>('oem_number'),
      partName: row.read<String>('part_name'),
      brand: row.readNullable<String>('brand'),
      retailPriceCents: row.read<int>('retail_price'),
      tradePriceCents: row.readNullable<int>('trade_price'),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updatedAtSeconds * 1000,
        isUtc: true,
      ),
    );
  }
}
