import 'dart:convert';

const kProductUnits = ['pcs', 'kg', 'g', 'L', 'mL', 'm', 'ft', 'box', 'dozen', 'pair'];

/// A single variant of a product (e.g. Size: M) with its own price, stock and SKU.
class ProductVariant {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String sku;
  final String barcodeNo;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    this.stock = 0,
    this.sku = '',
    this.barcodeNo = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'stock': stock,
    'sku': sku,
    'barcode_no': barcodeNo,
  };

  static ProductVariant fromMap(Map<String, dynamic> m) => ProductVariant(
    id: (m['id'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    price: (m['price'] as num?)?.toDouble() ?? 0.0,
    stock: (m['stock'] as num?)?.toInt() ?? 0,
    sku: (m['sku'] ?? '').toString(),
    barcodeNo: (m['barcode_no'] ?? '').toString(),
  );

  ProductVariant copyWith({String? name, double? price, int? stock, String? sku, String? barcodeNo}) =>
      ProductVariant(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        sku: sku ?? this.sku,
        barcodeNo: barcodeNo ?? this.barcodeNo,
      );
}

/// Encode/decode a variants list to a JSON string (used for both SQLite and cloud).
String encodeVariants(List<ProductVariant> variants) =>
    jsonEncode(variants.map((v) => v.toMap()).toList());

List<ProductVariant> decodeVariants(dynamic raw) {
  if (raw == null) return const [];
  try {
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((m) => ProductVariant.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
  } catch (_) {}
  return const [];
}

class Product {
  final String id;
  final String name;
  final double price;
  final double buyingPrice;
  final double taxPercent;
  final String category;
  final String emoji;
  final String sku;
  final int stock;
  final String description;
  final String unit;
  final String barcodeNo;
  final String supplier;
  final DateTime? purchaseDate;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.buyingPrice = 0.0,
    this.taxPercent = 0.0,
    required this.category,
    required this.emoji,
    required this.sku,
    required this.stock,
    this.description = '',
    this.unit = 'pcs',
    this.barcodeNo = '',
    this.supplier = '',
    this.purchaseDate,
    this.variants = const [],
  });

  bool get hasVariants => variants.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'buying_price': buyingPrice,
    'tax_percent': taxPercent,
    'category': category,
    'emoji': emoji,
    'sku': sku,
    'stock': stock,
    'description': description,
    'unit': unit,
    'barcode_no': barcodeNo,
    'supplier': supplier,
    'purchase_date': purchaseDate?.toIso8601String(),
    'variants': encodeVariants(variants),
    'synced': 0,
  };

  static Product fromMap(Map<String, dynamic> m) => Product(
    id: m['id'] as String,
    name: m['name'] as String,
    price: (m['price'] as num).toDouble(),
    buyingPrice: (m['buying_price'] as num?)?.toDouble() ?? 0.0,
    taxPercent: (m['tax_percent'] as num?)?.toDouble() ?? 0.0,
    category: m['category'] as String,
    emoji: m['emoji'] as String,
    sku: m['sku'] as String,
    stock: m['stock'] as int,
    description: (m['description'] as String?) ?? '',
    unit: (m['unit'] as String?) ?? 'pcs',
    barcodeNo: (m['barcode_no'] as String?) ?? '',
    supplier: (m['supplier'] as String?) ?? '',
    purchaseDate: (m['purchase_date'] as String?)?.isNotEmpty == true
        ? DateTime.tryParse(m['purchase_date'] as String)
        : null,
    variants: decodeVariants(m['variants']),
  );

  Product copyWith({int? stock, String? barcodeNo, String? supplier, DateTime? purchaseDate, List<ProductVariant>? variants}) => Product(
    id: id, name: name, price: price, buyingPrice: buyingPrice,
    taxPercent: taxPercent, category: category,
    emoji: emoji, sku: sku, stock: stock ?? this.stock,
    description: description, unit: unit,
    barcodeNo: barcodeNo ?? this.barcodeNo,
    supplier: supplier ?? this.supplier,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    variants: variants ?? this.variants,
  );
}

class CartItem {
  final Product product;
  int quantity;
  final ProductVariant? variant;

  CartItem({required this.product, this.quantity = 1, this.variant});

  double get unitPrice => variant?.price ?? product.price;
  double get total => unitPrice * quantity;

  /// Unique key for a cart line. Two variants of the same product are distinct
  /// lines; a base (variant-less) product keeps its plain product id, so
  /// existing non-variant behaviour is unchanged.
  String get lineId => variant == null ? product.id : '${product.id}::${variant!.id}';

  /// Stock and SKU reflect the variant when one is selected.
  int get availableStock => variant?.stock ?? product.stock;
  String get displaySku => variant?.sku ?? product.sku;
}
