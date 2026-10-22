/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : cart_draft.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Serializable snapshot of an in-progress counter sale. The full
 *               catalog projection and selected UOM travel with each line so a
 *               draft can be restored offline without re-reading master data,
 *               and prices remain exactly what the cashier quoted. One draft is
 *               stored per operator in the encrypted settings registry.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import 'cart_line.dart';
import 'catalog_part.dart';

/// Restorable cart state persisted between sessions.
@immutable
class CartDraft {
  const CartDraft({
    required this.lines,
    required this.paymentMethod,
    required this.updatedAt,
    this.customerId,
  });

  final List<CartLine> lines;
  final String? customerId;
  final String paymentMethod;
  final DateTime updatedAt;

  bool get isEmpty => lines.isEmpty;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': 1,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'customer_id': customerId,
      'payment_method': paymentMethod,
      'lines': lines
          .map(
            (line) => <String, Object?>{
              'quantity': line.quantity,
              'uom': <String, Object?>{
                'label': line.uom.label,
                'factor': line.uom.factor,
              },
              'part': _partToJson(line.part),
            },
          )
          .toList(growable: false),
    };
  }

  factory CartDraft.fromJson(Map<String, Object?> json) {
    final rawLines = json['lines'];
    if (rawLines is! List) {
      throw const FormatException('Draft has no line list.');
    }
    final lines = <CartLine>[];
    for (final raw in rawLines) {
      if (raw is! Map) {
        throw const FormatException('Draft line is not an object.');
      }
      final line = Map<String, Object?>.from(raw);
      final part = line['part'];
      if (part is! Map) {
        throw const FormatException('Draft line has no product.');
      }
      final uom = line['uom'];
      final uomMap = uom is Map
          ? Map<String, Object?>.from(uom)
          : const <String, Object?>{};
      final quantity = _int(line['quantity']);
      if (quantity < 1) {
        throw const FormatException('Draft line has an invalid quantity.');
      }
      lines.add(
        CartLine(
          part: _partFromJson(Map<String, Object?>.from(part)),
          quantity: quantity,
          uom: UomOption(
            label: uomMap['label']?.toString() ?? 'EA',
            factor: _int(uomMap['factor'], fallback: 1),
          ),
        ),
      );
    }
    return CartDraft(
      lines: lines,
      customerId: _nullableText(json['customer_id']),
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  static Map<String, Object?> _partToJson(CatalogPart part) {
    return <String, Object?>{
      'id': part.id,
      'sku': part.sku,
      'oem_number': part.oemNumber,
      'part_name': part.partName,
      'brand': part.brand,
      'retail_price': part.retailPriceCents,
      'trade_price': part.tradePriceCents,
      'core_fee_cents': part.coreFeeCents,
      'base_unit': part.baseUnit,
      'updated_at': part.updatedAt.toUtc().toIso8601String(),
      'uom_options': part.uomOptions
          .map(
            (option) => <String, Object?>{
              'label': option.label,
              'factor': option.factor,
            },
          )
          .toList(growable: false),
    };
  }

  static CatalogPart _partFromJson(Map<String, Object?> json) {
    final rawOptions = json['uom_options'];
    final options = <UomOption>[];
    if (rawOptions is List) {
      for (final raw in rawOptions) {
        if (raw is Map) {
          final option = Map<String, Object?>.from(raw);
          options.add(
            UomOption(
              label: option['label']?.toString() ?? 'EA',
              factor: _int(option['factor'], fallback: 1),
            ),
          );
        }
      }
    }
    return CatalogPart(
      id: _text(json['id']),
      sku: _text(json['sku']),
      oemNumber: _nullableText(json['oem_number']),
      partName: _text(json['part_name']),
      brand: _nullableText(json['brand']),
      retailPriceCents: _int(json['retail_price']),
      tradePriceCents: _nullableInt(json['trade_price']),
      coreFeeCents: _int(json['core_fee_cents']),
      baseUnit: json['base_unit']?.toString() ?? 'EA',
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      uomOptions: options,
    );
  }

  static String _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const FormatException('Draft product is missing an identifier.');
    }
    return text;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _nullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
