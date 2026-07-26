import 'dart:io';
import 'package:billcat/models/transaction_record.dart';
import 'package:billcat/services/escpos_receipt.dart';

void main() {
  final tx = TransactionRecord(
    id: 'abc123def456', customerName: 'Test Customer', customerPhone: '9876543210',
    items: const [
      TransactionItem(productId: '1', productName: 'Sample Product A', price: 250, quantity: 2),
      TransactionItem(productId: '2', productName: 'Long Product Name To Test Wrapping On Narrow Paper', price: 180, quantity: 1),
    ],
    subtotal: 680, discountAmount: 20, taxAmount: 102, total: 762,
    paymentMethod: 'cash', createdAt: DateTime(2026, 7, 26, 20, 5), invoiceNumber: 'AE8AA6',
  );
  for (final cfg in [(32, false, '58mm no-cut'), (48, true, '80mm cut')]) {
    final bytes = EscPosReceipt(cols: cfg.$1, cut: cfg.$2).build(tx,
      storeName: 'BillCat Store', storeAddress: '123 Market Road, Chennai',
      storePhone: '9659394812', storeGstin: '33ABCDE1234F1Z5',
      receiptFooter: 'Goods once sold are not returnable.', taxLabel: 'GST',
      taxRate: '5', currencySymbol: '₹', docType: 'Invoice');
    File('/tmp/escpos_${cfg.$1}.bin').writeAsBytesSync(bytes);
    stdout.write('${cfg.$3}: ${bytes.length} bytes, cutcmd=${bytes.length>=2 && bytes[bytes.length-3]==0x1d}\n');
  }
}
