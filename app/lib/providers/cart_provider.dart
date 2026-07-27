import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/transaction_record.dart';
import '../services/local_db_service.dart';
import '../services/connectivity_service.dart';

enum DiscountType { percent, fixed }
enum PaymentMethod { cash, card, upi, hybrid }

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String customerName = '';
  String customerPhone = '';
  double discountValue = 0;
  DiscountType discountType = DiscountType.percent;
  PaymentMethod paymentMethod = PaymentMethod.cash;
  double taxRate = 0.0;

  void setTaxRate(double rate) {
    taxRate = rate;
    notifyListeners();
  }

  List<CartItem> get items => _items;
  int get itemCount => _items.fold(0, (s, i) => s + i.quantity);

  double get subtotal => _items.fold(0, (s, i) => s + i.total);

  double get discountAmount {
    if (discountType == DiscountType.percent) {
      return subtotal * (discountValue / 100);
    }
    return discountValue.clamp(0, subtotal);
  }

  double get taxAmount => (subtotal - discountAmount) * (taxRate / 100);
  double get total => subtotal - discountAmount + taxAmount;

  /// Total quantity of a product across all its variant lines (used by the
  /// product card badge and stock display).
  int quantityInCart(String productId) =>
      _items.where((e) => e.product.id == productId).fold(0, (s, e) => s + e.quantity);

  /// Quantity in cart for one specific variant of a product.
  int quantityInCartForVariant(String productId, String variantId) {
    final i = _items.indexWhere((e) => e.product.id == productId && e.variant?.id == variantId);
    return i >= 0 ? _items[i].quantity : 0;
  }

  void addProduct(Product product, {ProductVariant? variant}) {
    final item = CartItem(product: product, variant: variant);
    final i = _items.indexWhere((e) => e.lineId == item.lineId);
    if (i >= 0) {
      _items[i].quantity++;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void increment(String lineId, {int stock = 999999}) {
    final i = _items.indexWhere((e) => e.lineId == lineId);
    if (i >= 0 && _items[i].quantity < stock) { _items[i].quantity++; notifyListeners(); }
  }

  void decrement(String lineId) {
    final i = _items.indexWhere((e) => e.lineId == lineId);
    if (i >= 0) {
      if (_items[i].quantity > 1) {
        _items[i].quantity--;
      } else {
        _items.removeAt(i);
      }
      notifyListeners();
    }
  }

  void setQuantity(String lineId, int qty, {int stock = 999999}) {
    final i = _items.indexWhere((e) => e.lineId == lineId);
    if (i >= 0) {
      _items[i].quantity = qty.clamp(1, stock);
      notifyListeners();
    }
  }

  void removeItem(String lineId) {
    _items.removeWhere((e) => e.lineId == lineId);
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod m) {
    paymentMethod = m;
    notifyListeners();
  }

  void applyDiscount(double value, DiscountType type) {
    discountValue = value;
    discountType = type;
    notifyListeners();
  }

  Future<void> checkout({String? invoiceNumber, String? transactionId}) async {
    final record = TransactionRecord(
      id: transactionId ?? const Uuid().v4(),
      customerName: customerName.isEmpty ? null : customerName,
      customerPhone: customerPhone.isEmpty ? null : customerPhone,
      items: _items.map((i) => TransactionItem(
        productId: i.product.id,
        productName: i.variant != null ? '${i.product.name} (${i.variant!.name})' : i.product.name,
        price: i.unitPrice,
        quantity: i.quantity,
        description: i.product.description,
        variantId: i.variant?.id,
      )).toList(),
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      total: total,
      paymentMethod: paymentMethod.name,
      createdAt: DateTime.now(),
      synced: false,
      invoiceNumber: invoiceNumber,
    );
    await LocalDbService.insertTransaction(record);
    await ConnectivityService.instance.refreshUnsyncedCount();
    clearCart();
    if (ConnectivityService.instance.isOnline) {
      ConnectivityService.instance.syncNow();
    }
  }

  void clearCart() {
    _items.clear();
    customerName = '';
    customerPhone = '';
    discountValue = 0;
    notifyListeners();
  }
}
