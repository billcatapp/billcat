/// One purchase made from a dealer — a permanent ledger line.
///
/// The product name and unit cost are COPIED in rather than looked up later,
/// so the history stays truthful after the product is renamed, repriced or
/// deleted. Buying the same item again writes a new row; nothing is ever
/// overwritten.
class DealerPurchase {
  final String id;
  final String dealerId;
  final String dealerName; // denormalised: survives a dealer rename
  final String productId;
  final String productName;
  final int qty;
  final double unitCost;
  final double amount; // qty * unitCost at the time of purchase
  final String source; // 'product' = entered via Add Product, 'manual' = Record Purchase
  final DateTime purchaseDate;
  final DateTime createdAt;
  final bool synced;

  const DealerPurchase({
    required this.id,
    required this.dealerId,
    this.dealerName = '',
    this.productId = '',
    this.productName = '',
    this.qty = 0,
    this.unitCost = 0,
    required this.amount,
    this.source = 'product',
    required this.purchaseDate,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'dealer_id': dealerId,
        'dealer_name': dealerName,
        'product_id': productId,
        'product_name': productName,
        'qty': qty,
        'unit_cost': unitCost,
        'amount': amount,
        'source': source,
        'purchase_date': purchaseDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'synced': synced ? 1 : 0,
      };

  static DealerPurchase fromMap(Map<String, dynamic> m) => DealerPurchase(
        id: m['id'] as String,
        dealerId: (m['dealer_id'] as String?) ?? '',
        dealerName: (m['dealer_name'] as String?) ?? '',
        productId: (m['product_id'] as String?) ?? '',
        productName: (m['product_name'] as String?) ?? '',
        qty: (m['qty'] as num?)?.toInt() ?? 0,
        unitCost: (m['unit_cost'] as num?)?.toDouble() ?? 0,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        source: (m['source'] as String?) ?? 'product',
        purchaseDate: DateTime.parse(m['purchase_date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        synced: (m['synced'] as int? ?? 0) == 1,
      );
}
