/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.register
 * - File      : checkout_controller.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Right-hand checkout state: customer selection, active cart,
 *               integer VAT math, payment method, submission lock, and atomic
 *               sale completion. The controller never lets a second charge
 *               start while one is in flight, clears the cart only after a
 *               successful commit, and surfaces a non-destructive error state
 *               when the transactional repository rolls back.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import '../../core/utils/money.dart';
import '../../data/models/cart_line.dart';
import '../../data/models/catalog_part.dart';
import '../../data/models/customer_option.dart';
import '../../data/repositories/checkout_repository.dart';

/// Payment triggers supported by the initial offline register.
enum PaymentMethod {
  cash('Cash', 'cash'),
  card('Card', 'card'),
  mobile('Mobile', 'mobile');

  const PaymentMethod(this.label, this.wireValue);

  final String label;

  /// Stable lowercase token persisted on invoices and understood by sync.
  final String wireValue;
}

/// Owns the active cart and the local checkout lifecycle.
class CheckoutController extends ChangeNotifier {
  CheckoutController({required CheckoutRepository repository})
    : _repository = repository;

  /// Rwanda VAT for the initial deployment. Persisted per invoice and per line.
  static const int taxRateBps = 1800;

  final CheckoutRepository _repository;

  final List<CartLine> _lines = <CartLine>[];
  final List<CustomerOption> _customers = <CustomerOption>[];

  CustomerOption? _selectedCustomer;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _loadingCustomers = false;
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  List<CartLine> get lines => List<CartLine>.unmodifiable(_lines);
  List<CustomerOption> get customers =>
      List<CustomerOption>.unmodifiable(_customers);
  CustomerOption? get selectedCustomer => _selectedCustomer;
  PaymentMethod get paymentMethod => _paymentMethod;
  bool get loadingCustomers => _loadingCustomers;
  bool get submitting => _submitting;
  String? get error => _error;

  int get itemCount =>
      _lines.fold<int>(0, (sum, line) => sum + line.quantity);

  int get subtotalCents =>
      _lines.fold<int>(0, (sum, line) => sum + line.lineSubtotalCents);

  int get taxCents =>
      Money.taxCents(subtotalCents: subtotalCents, rateBps: taxRateBps);

  int get totalCents => subtotalCents + taxCents;

  bool get canCheckout => _lines.isNotEmpty && !_submitting;

  /// Loads trade accounts for the checkout selector. Failure is non-fatal:
  /// walk-in sales remain possible with a null customer selection.
  Future<void> initialize() async {
    _loadingCustomers = true;
    _error = null;
    _safeNotify();

    try {
      final customers = await _repository.activeCustomers();
      if (_disposed) {
        return;
      }
      _customers
        ..clear()
        ..addAll(customers);
    } catch (error, stackTrace) {
      if (_disposed) {
        return;
      }
      _error = 'Customer accounts could not be loaded. Walk-in sale is ready.';
      debugPrint('Customer list failed: $error\n$stackTrace');
    } finally {
      if (!_disposed) {
        _loadingCustomers = false;
        _safeNotify();
      }
    }
  }

  /// Adds a catalog part or increments its existing line. Mutations are frozen
  /// while a commit is in flight so a late add cannot be silently cleared when
  /// the successfully charged cart resets.
  void addPart(CatalogPart part) {
    if (_submitting) {
      return;
    }
    final index = _lines.indexWhere((line) => line.part.id == part.id);
    if (index == -1) {
      _lines.add(CartLine(part: part, quantity: 1));
    } else {
      _lines[index] = _lines[index].copyWith(
        quantity: _lines[index].quantity + 1,
      );
    }
    _error = null;
    _safeNotify();
  }

  /// Increments one cart line.
  void incrementLine(String productId) {
    if (_submitting) {
      return;
    }
    final index = _lines.indexWhere((line) => line.part.id == productId);
    if (index == -1) {
      return;
    }
    _lines[index] = _lines[index].copyWith(
      quantity: _lines[index].quantity + 1,
    );
    _safeNotify();
  }

  /// Decrements one cart line, removing it when the quantity reaches zero.
  void decrementLine(String productId) {
    if (_submitting) {
      return;
    }
    final index = _lines.indexWhere((line) => line.part.id == productId);
    if (index == -1) {
      return;
    }
    if (_lines[index].quantity <= 1) {
      _lines.removeAt(index);
    } else {
      _lines[index] = _lines[index].copyWith(
        quantity: _lines[index].quantity - 1,
      );
    }
    _safeNotify();
  }

  /// Removes an entire line.
  void removeLine(String productId) {
    if (_submitting) {
      return;
    }
    final previousLength = _lines.length;
    _lines.removeWhere((line) => line.part.id == productId);
    if (_lines.length != previousLength) {
      _safeNotify();
    }
  }

  void clearCart() {
    if (_submitting || _lines.isEmpty) {
      return;
    }
    _lines.clear();
    _error = null;
    _safeNotify();
  }

  void selectCustomer(CustomerOption? customer) {
    if (_submitting || _selectedCustomer == customer) {
      return;
    }
    _selectedCustomer = customer;
    _safeNotify();
  }

  void setPaymentMethod(PaymentMethod method) {
    if (_submitting || _paymentMethod == method) {
      return;
    }
    _paymentMethod = method;
    _safeNotify();
  }

  /// Commits the sale locally. Returns null when validation or persistence
  /// fails; in that case the cart is preserved and [error] explains the state.
  Future<CheckoutResult?> completeSale() async {
    if (!canCheckout) {
      return null;
    }

    _submitting = true;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.commitSale(
        lines: List<CartLine>.unmodifiable(_lines),
        customer: _selectedCustomer,
        taxRateBps: taxRateBps,
        paymentMethod: _paymentMethod.wireValue,
      );

      if (_disposed) {
        return result;
      }

      _lines.clear();
      _selectedCustomer = null;
      _paymentMethod = PaymentMethod.cash;
      return result;
    } catch (error, stackTrace) {
      if (!_disposed) {
        _error =
            'Sale was not completed. Nothing was written; the cart is intact.';
        debugPrint('Checkout transaction failed: $error\n$stackTrace');
      }
      return null;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
