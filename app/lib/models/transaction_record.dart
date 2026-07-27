import 'dart:convert';

class TransactionItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String description;

  /// Which variant of the product was sold, if any. Stored inside the
  /// transaction's `items` JSON, so adding it needs no DB/cloud schema change.
  final String? variantId;

  const TransactionItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.description = '',
    this.variantId,
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'price': price,
    'quantity': quantity,
    'description': description,
    'variantId': variantId,
  };

  factory TransactionItem.fromMap(Map<String, dynamic> m) => TransactionItem(
    productId: m['productId'] as String,
    productName: m['productName'] as String,
    price: (m['price'] as num).toDouble(),
    quantity: m['quantity'] as int,
    description: (m['description'] as String?) ?? '',
    variantId: m['variantId'] as String?,
  );
}

class TransactionRecord {
  final String id;
  final String? customerName;
  final String? customerPhone;
  final List<TransactionItem> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final String paymentMethod;
  final DateTime createdAt;
  final bool synced;
  final String? invoiceNumber;

  const TransactionRecord({
    required this.id,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    this.synced = false,
    this.invoiceNumber,
  });


  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_name': customerName ?? '',
    'customer_phone': customerPhone ?? '',
    'items': jsonEncode(items.map((i) => i.toMap()).toList()),
    'subtotal': subtotal,
    'discount_amount': discountAmount,
    'tax_amount': taxAmount,
    'total': total,
    'payment_method': paymentMethod,
    'created_at': createdAt.toIso8601String(),
    'synced': synced ? 1 : 0,
    'invoice_number': invoiceNumber,
  };

  factory TransactionRecord.fromMap(Map<String, dynamic> m) {
    final rawItems = jsonDecode(m['items'] as String) as List;
    return TransactionRecord(
      id: m['id'] as String,
      customerName: m['customer_name'] as String?,
      customerPhone: m['customer_phone'] as String?,
      items: rawItems.map((i) => TransactionItem.fromMap(i as Map<String, dynamic>)).toList(),
      subtotal: (m['subtotal'] as num).toDouble(),
      discountAmount: (m['discount_amount'] as num).toDouble(),
      taxAmount: (m['tax_amount'] as num).toDouble(),
      total: (m['total'] as num).toDouble(),
      paymentMethod: m['payment_method'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      synced: (m['synced'] as int) == 1,
      invoiceNumber: m['invoice_number']?.toString(),
    );
  }
}
