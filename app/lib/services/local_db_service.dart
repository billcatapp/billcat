import 'dart:io';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/dealer.dart';
import '../models/dealer_purchase.dart';
import '../models/product.dart';
import '../models/transaction_record.dart';

class LocalDbService {
  static Database? _db;
  static String? _currentUserId;

  /// The user whose local DB is currently open (null before any init).
  static String? get currentUserId => _currentUserId;

  static Future<void> initForUser(String userId) async {
    if (_currentUserId == userId && _db != null) return;
    await _db?.close();
    _db = null;
    _currentUserId = userId;
    _db = await _open(userId);
  }

  static Future<Database> get db async {
    _db ??= await _open(_currentUserId ?? 'shared');
    return _db!;
  }

  static Future<String> _appSupportPath() async {
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory('$home/Library/Application Support/BillCat');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  static Future<Database> _open(String userId) async {
    final dbPath = await _appSupportPath();
    return openDatabase(
      join(dbPath, 'billcat_$userId.db'),
      version: 18,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          try { await db.execute('ALTER TABLE products ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
        }
        if (oldVersion < 5) {
          try { await db.execute('ALTER TABLE products ADD COLUMN buying_price REAL NOT NULL DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE products ADD COLUMN tax_percent REAL NOT NULL DEFAULT 0'); } catch (_) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS categories (
                name TEXT PRIMARY KEY,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 8) {
          try { await db.execute("ALTER TABLE products ADD COLUMN description TEXT NOT NULL DEFAULT ''"); } catch (_) {}
        }
        if (oldVersion < 9) {
          try { await db.execute('ALTER TABLE transactions ADD COLUMN invoice_number INTEGER'); } catch (_) {}
        }
        if (oldVersion < 10) {
          try { await db.execute("ALTER TABLE customers ADD COLUMN address TEXT NOT NULL DEFAULT ''"); } catch (_) {}
        }
        if (oldVersion < 11) {
          try { await db.execute("ALTER TABLE products ADD COLUMN unit TEXT NOT NULL DEFAULT 'pcs'"); } catch (_) {}
        }
        if (oldVersion < 12) {
          try { await db.execute("ALTER TABLE products ADD COLUMN barcode_no TEXT NOT NULL DEFAULT ''"); } catch (_) {}
        }
        if (oldVersion < 13) {
          try { await db.execute("ALTER TABLE customers ADD COLUMN credit_balance REAL NOT NULL DEFAULT 0"); } catch (_) {}
        }
        if (oldVersion < 14) {
          try { await db.execute("ALTER TABLE products ADD COLUMN variants TEXT NOT NULL DEFAULT '[]'"); } catch (_) {}
        }
        if (oldVersion < 15) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS dealers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT,
                company TEXT NOT NULL DEFAULT '',
                total_purchased REAL NOT NULL DEFAULT 0,
                balance_payable REAL NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 16) {
          try { await db.execute("ALTER TABLE products ADD COLUMN supplier TEXT NOT NULL DEFAULT ''"); } catch (_) {}
          try { await db.execute("ALTER TABLE products ADD COLUMN purchase_date TEXT"); } catch (_) {}
        }
        if (oldVersion < 17) {
          // invoice_number was declared INTEGER, so SQLite's numeric affinity
          // mangled text bill numbers: "12E456" became Infinity, "123E45"
          // became 1.23e+47, leading zeros vanished. Rebuild the column as
          // TEXT (affinity is per-column and can only change by rebuild).
          try {
            await db.execute('ALTER TABLE transactions RENAME TO _tx_old');
            await db.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                customer_name TEXT,
                customer_phone TEXT,
                items TEXT NOT NULL,
                subtotal REAL NOT NULL,
                discount_amount REAL NOT NULL,
                tax_amount REAL NOT NULL,
                total REAL NOT NULL,
                payment_method TEXT NOT NULL,
                created_at TEXT NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0,
                invoice_number TEXT
              )
            ''');
            await db.execute('''
              INSERT INTO transactions
                (id, customer_name, customer_phone, items, subtotal,
                 discount_amount, tax_amount, total, payment_method,
                 created_at, synced, invoice_number)
              SELECT id, customer_name, customer_phone, items, subtotal,
                 discount_amount, tax_amount, total, payment_method,
                 created_at, synced,
                 CASE
                   WHEN invoice_number IS NULL THEN NULL
                   -- Values already destroyed by the old affinity can't be
                   -- recovered; drop them so the app falls back to the id
                   -- slice and a later cloud pull can supply the real one.
                   WHEN CAST(invoice_number AS TEXT) IN ('Inf', '-Inf') THEN NULL
                   ELSE CAST(invoice_number AS TEXT)
                 END
              FROM _tx_old
            ''');
            await db.execute('DROP TABLE _tx_old');
          } catch (_) {}
        }
        if (oldVersion < 18) {
          try { await db.execute(_dealerPurchasesDdl); } catch (_) {}
        }
      },
      onCreate: (db, _) => _createTables(db),
    );
  }

  /// Permanent per-purchase ledger for dealers. Shared by _createTables and the
  /// v18 migration so a fresh install and an upgrade get an identical table.
  static const String _dealerPurchasesDdl = '''
      CREATE TABLE IF NOT EXISTS dealer_purchases (
        id TEXT PRIMARY KEY,
        dealer_id TEXT NOT NULL,
        dealer_name TEXT NOT NULL DEFAULT '',
        product_id TEXT NOT NULL DEFAULT '',
        product_name TEXT NOT NULL DEFAULT '',
        qty INTEGER NOT NULL DEFAULT 0,
        unit_cost REAL NOT NULL DEFAULT 0,
        amount REAL NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'product',
        purchase_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''';

  static Future<void> _createTables(Database db) async {
    await db.execute(_dealerPurchasesDdl);
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        buying_price REAL NOT NULL DEFAULT 0,
        tax_percent REAL NOT NULL DEFAULT 0,
        category TEXT NOT NULL,
        emoji TEXT NOT NULL,
        sku TEXT NOT NULL,
        stock INTEGER NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT 'pcs',
        barcode_no TEXT NOT NULL DEFAULT '',
        supplier TEXT NOT NULL DEFAULT '',
        purchase_date TEXT,
        variants TEXT NOT NULL DEFAULT '[]',
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        customer_name TEXT,
        customer_phone TEXT,
        items TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount_amount REAL NOT NULL,
        tax_amount REAL NOT NULL,
        total REAL NOT NULL,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        invoice_number TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT NOT NULL DEFAULT '',
        credit_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        name TEXT PRIMARY KEY,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE dealers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        company TEXT NOT NULL DEFAULT '',
        total_purchased REAL NOT NULL DEFAULT 0,
        balance_payable REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  static Future<Map<String, String>> getSettings() async {
    final database = await db;
    final rows = await database.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  static Future<void> saveSettings(Map<String, String> settings) async {
    final database = await db;
    final batch = database.batch();
    for (final e in settings.entries) {
      batch.insert('settings', {'key': e.key, 'value': e.value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── Invoice ID ────────────────────────────────────────────────────────────

  static String generateInvoiceId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = math.Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Categories ────────────────────────────────────────────────────────────

  static Future<List<String>> getCategories() async {
    final database = await db;
    final rows = await database.query('categories', orderBy: 'name ASC');
    return rows.map((r) => r['name'] as String).toList();
  }

  static Future<void> saveCategory(String name) async {
    final database = await db;
    await database.insert('categories', {'name': name, 'synced': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> renameCategory(String oldName, String newName) async {
    final database = await db;
    await database.delete('categories', where: 'name = ?', whereArgs: [oldName]);
    await database.insert('categories', {'name': newName, 'synced': 0},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteCategory(String name) async {
    final database = await db;
    await database.delete('categories', where: 'name = ?', whereArgs: [name]);
  }

  static Future<List<String>> getUnsyncedCategories() async {
    final database = await db;
    final rows = await database.query('categories', where: 'synced = 0');
    return rows.map((r) => r['name'] as String).toList();
  }

  static Future<void> markCategorySynced(String name) async {
    final database = await db;
    await database.update('categories', {'synced': 1},
        where: 'name = ?', whereArgs: [name]);
  }

  static Future<void> insertCategoriesSynced(List<String> names) async {
    final database = await db;
    final batch = database.batch();
    for (final name in names) {
      batch.insert('categories', {'name': name, 'synced': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Clear all local data (call on logout) ─────────────────────────────────

  static Future<void> clearAll() async {
    final database = await db;
    await database.delete('products');
    await database.delete('transactions');
    await database.delete('customers');
    await database.delete('categories');
  }

  // ── Products ──────────────────────────────────────────────────────────────

  static Future<List<Product>> getProducts() async {
    final database = await db;
    final rows = await database.query('products',
        where: 'deleted = 0', orderBy: 'name ASC');
    return rows.map(Product.fromMap).toList();
  }

  static Future<void> insertProduct(Product product) async {
    final database = await db;
    await database.insert('products', product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> insertProductsSynced(List<Product> products) async {
    final database = await db;
    final batch = database.batch();
    for (final p in products) {
      final map = p.toMap();
      map['synced'] = 1;
      map['deleted'] = 0;
      // ignore = don't overwrite locally-deleted products
      batch.insert('products', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> updateProductStock(String id, int newStock) async {
    final database = await db;
    await database.update('products', {'stock': newStock},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<String> copyImageToAppDir(String sourcePath) async {
    final base = await _appSupportPath();
    final dir = Directory(join(base, 'product_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = sourcePath.split('.').last.toLowerCase();
    final dest = join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.$ext');
    await File(sourcePath).copy(dest);
    return dest;
  }

  static Future<void> updateProduct(Product p) async {
    final database = await db;
    // Use the full map so supplier, purchase_date and variants persist too —
    // a hand-picked column list silently dropped them on edit. toMap() sets
    // synced: 0, marking the row dirty for the next cloud push.
    await database.update('products', p.toMap(),
        where: 'id = ?', whereArgs: [p.id]);
  }

  static Future<String> getNextBarcodeNo() async {
    final database = await db;
    final rows = await database.rawQuery(
      "SELECT MAX(CAST(barcode_no AS INTEGER)) as m FROM products WHERE barcode_no != ''");
    final maxVal = rows.first['m'];
    // EAN-13: 12-digit input (200 prefix + 9-digit sequence), library adds check digit
    final next = (maxVal == null ? 200000000000 : (maxVal as int)) + 1;
    return next.toString().padLeft(12, '0');
  }

  static Future<void> assignMissingBarcodeNos() async {
    final database = await db;
    // Only assign to products with a truly empty barcode_no — never overwrite existing
    final rows = await database.query('products',
      columns: ['id'], where: "barcode_no = '' OR barcode_no IS NULL");
    for (final row in rows) {
      final next = await getNextBarcodeNo();
      await database.update('products', {'barcode_no': next},
        where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  static Future<void> deleteProduct(String id) async {
    final database = await db;
    // Soft-delete: mark for cloud removal, hidden from UI immediately
    await database.update('products', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Product>> getUnsyncedProducts() async {
    final database = await db;
    final rows = await database.query('products',
        where: 'synced = 0 AND deleted = 0', whereArgs: []);
    return rows.map(Product.fromMap).toList();
  }

  // Products marked deleted locally but not yet removed from Supabase
  static Future<List<String>> getPendingDeleteProductIds() async {
    final database = await db;
    final rows = await database.query('products',
        columns: ['id'], where: 'deleted = 1 AND synced = 0');
    return rows.map((r) => r['id'] as String).toList();
  }

  // Call after confirming Supabase deletion — hard-deletes the local row
  static Future<void> purgeDeletedProduct(String id) async {
    final database = await db;
    await database.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> markProductSynced(String id) async {
    final database = await db;
    await database.update('products', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  /// Records a return/exchange transaction. Unlike [insertTransaction],
  /// items with NEGATIVE quantities are returns and their stock is added
  /// back; positive quantities (exchange items) deduct stock with the same
  /// floor-at-zero rule as a sale. Kept separate so the sale path's stock
  /// math stays untouched.
  static Future<void> insertReturnTransaction(TransactionRecord t) async {
    final database = await db;
    await database.insert(
      'transactions',
      t.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    for (final item in t.items) {
      if (item.productId.isEmpty) continue; // custom line, nothing to stock
      final rows = await database.query(
        'products',
        where: 'id = ?',
        whereArgs: [item.productId],
        limit: 1,
      );
      if (rows.isEmpty) continue;
      final row = rows.first;

      // Variants live as JSON on the product row (same shape the sale path
      // uses): adjust that variant and keep base stock = sum of variants.
      if (item.variantId != null) {
        final variants = decodeVariants(row['variants']);
        final idx = variants.indexWhere((v) => v.id == item.variantId);
        if (idx != -1) {
          final v = variants[idx];
          variants[idx] = v.copyWith(stock: _restocked(v.stock, item.quantity));
          final sum = variants.fold<int>(0, (s, v) => s + v.stock);
          await database.update(
            'products',
            {'variants': encodeVariants(variants), 'stock': sum, 'synced': 0},
            where: 'id = ?',
            whereArgs: [item.productId],
          );
          continue;
        }
      }

      final current = row['stock'] as int;
      await database.update(
        'products',
        {'stock': _restocked(current, item.quantity), 'synced': 0},
        where: 'id = ?',
        whereArgs: [item.productId],
      );
    }
  }

  /// Stock after a return line. Negative quantity = goods coming back, so
  /// stock rises. Positive quantity = an exchange item leaving the shop, so
  /// stock falls but never below zero (matching the sale path).
  static int _restocked(int current, int quantity) => quantity < 0
      ? current - quantity
      : (current - quantity) < 0
          ? 0
          : current - quantity;

  static Future<void> insertTransaction(TransactionRecord t) async {
    final database = await db;
    await database.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Deduct stock for each sold item and mark product unsynced for cloud push.
    for (final item in t.items) {
      final rows = await database.query('products',
          where: 'id = ?', whereArgs: [item.productId], limit: 1);
      if (rows.isEmpty) continue;
      final row = rows.first;

      // Variant sale: deduct that variant's stock and keep the base product
      // stock equal to the sum of its variants.
      if (item.variantId != null) {
        final variants = decodeVariants(row['variants']);
        final idx = variants.indexWhere((v) => v.id == item.variantId);
        if (idx != -1) {
          final v = variants[idx];
          variants[idx] = v.copyWith(stock: (v.stock - item.quantity).clamp(0, v.stock));
          final sum = variants.fold<int>(0, (s, v) => s + v.stock);
          await database.update(
            'products',
            {'variants': encodeVariants(variants), 'stock': sum, 'synced': 0},
            where: 'id = ?',
            whereArgs: [item.productId],
          );
          continue;
        }
      }

      // Plain product (or variant no longer present): deduct the base stock.
      final current = row['stock'] as int;
      final updated = (current - item.quantity).clamp(0, current);
      await database.update(
        'products',
        {'stock': updated, 'synced': 0},
        where: 'id = ?',
        whereArgs: [item.productId],
      );
    }
    if (t.customerName != null && t.customerName!.isNotEmpty) {
      await upsertCustomerByPhone(name: t.customerName!, phone: t.customerPhone);
    }
  }

  static Future<void> insertTransactionsSynced(List<TransactionRecord> txs) async {
    final database = await db;
    final batch = database.batch();
    for (final t in txs) {
      final map = t.toMap();
      map['synced'] = 1;
      batch.insert('transactions', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<TransactionRecord>> getTransactions() async {
    final database = await db;
    final rows = await database.query('transactions', orderBy: 'created_at DESC');
    return rows.map(TransactionRecord.fromMap).toList();
  }

  static Future<List<TransactionRecord>> getTransactionsForDate(DateTime date) async {
    final database = await db;
    final prefix = '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    final rows = await database.query('transactions',
        where: "created_at LIKE ?", whereArgs: ['$prefix%'],
        orderBy: 'created_at DESC');
    return rows.map(TransactionRecord.fromMap).toList();
  }

  static Future<List<TransactionRecord>> getTransactionsForRange(
      DateTime from, DateTime to) async {
    final database = await db;
    final f = from.toIso8601String().substring(0, 10);
    final t = to.toIso8601String().substring(0, 10);
    final rows = await database.rawQuery(
      "SELECT * FROM transactions WHERE substr(created_at,1,10) >= ? AND substr(created_at,1,10) <= ? ORDER BY created_at DESC",
      [f, t],
    );
    return rows.map(TransactionRecord.fromMap).toList();
  }

  static Future<List<TransactionRecord>> getUnsynced() async {
    final database = await db;
    final rows = await database.query('transactions',
        where: 'synced = ?', whereArgs: [0], orderBy: 'created_at ASC');
    return rows.map(TransactionRecord.fromMap).toList();
  }

  static Future<void> markSynced(String id) async {
    final database = await db;
    await database.update('transactions', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteTransaction(String id) async {
    final database = await db;
    await database.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Removes synced transactions that no longer exist in Supabase (cloud is source of truth for deletes)
  static Future<void> reconcileTransactionsWithCloud(Set<String> cloudIds) async {
    if (cloudIds.isEmpty) return;
    final database = await db;
    final rows = await database.query('transactions', columns: ['id'], where: 'synced = 1');
    for (final row in rows) {
      final id = row['id'] as String;
      if (!cloudIds.contains(id)) {
        await database.delete('transactions', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  static Future<int> unsyncedCount() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM transactions WHERE synced = 0');
    return (result.first['count'] as int?) ?? 0;
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  static Future<void> upsertCustomerByPhone({
    required String name,
    String? phone,
    String? address,
  }) async {
    final database = await db;
    if (phone != null && phone.isNotEmpty) {
      final existing = await database.query('customers',
          where: 'phone = ?', whereArgs: [phone], limit: 1);
      if (existing.isNotEmpty) {
        await database.update('customers',
            {'name': name, 'address': address ?? '', 'synced': 0},
            where: 'phone = ?', whereArgs: [phone]);
        return;
      }
    }
    await database.insert('customers', {
      'id': const Uuid().v4(),
      'name': name,
      'phone': phone ?? '',
      'address': address ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> insertCustomersSynced(List<Customer> customers) async {
    final database = await db;
    final batch = database.batch();
    for (final c in customers) {
      final map = c.toMap();
      map['synced'] = 1;
      batch.insert('customers', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Customer>> getCustomers() async {
    final database = await db;
    final rows = await database.query('customers', orderBy: 'name ASC');
    return rows.map(Customer.fromMap).toList();
  }

  static Future<List<Customer>> getUnsyncedCustomers() async {
    final database = await db;
    final rows = await database.query('customers',
        where: 'synced = ?', whereArgs: [0]);
    return rows.map(Customer.fromMap).toList();
  }

  static Future<void> markCustomerSynced(String id) async {
    final database = await db;
    await database.update('customers', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteCustomer(String id) async {
    final database = await db;
    await database.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  static Future<double> getCustomerCredit(String phone) async {
    final database = await db;
    final rows = await database.query('customers',
        columns: ['credit_balance'], where: 'phone = ?', whereArgs: [phone]);
    if (rows.isEmpty) return 0;
    return (rows.first['credit_balance'] as num?)?.toDouble() ?? 0;
  }

  static Future<void> addCreditToCustomer(String phone, double amount) async {
    final database = await db;
    await database.rawUpdate(
      'UPDATE customers SET credit_balance = credit_balance + ?, synced = 0 WHERE phone = ?',
      [amount, phone],
    );
  }

  /// Outstanding credit (udhaar) for a customer, 0 when unknown.
  static Future<double> creditBalanceForPhone(String phone) async {
    if (phone.trim().isEmpty) return 0;
    final database = await db;
    final rows = await database.query(
      'customers',
      columns: ['credit_balance'],
      where: 'phone = ?',
      whereArgs: [phone.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['credit_balance'] as num?)?.toDouble() ?? 0;
  }

  static Future<List<TransactionRecord>> getTransactionsByCustomer(String name, String? phone) async {
    final database = await db;
    List<Map<String, dynamic>> rows;
    if (phone != null && phone.isNotEmpty) {
      rows = await database.rawQuery(
        "SELECT * FROM transactions WHERE customer_name = ? OR customer_phone = ? ORDER BY created_at DESC",
        [name, phone],
      );
    } else {
      rows = await database.query('transactions',
          where: 'customer_name = ?', whereArgs: [name],
          orderBy: 'created_at DESC');
    }
    return rows.map(TransactionRecord.fromMap).toList();
  }

  // ── Dealers (suppliers) ────────────────────────────────────────────────────

  static Future<List<Dealer>> getDealers() async {
    final database = await db;
    final rows = await database.query('dealers', orderBy: 'name ASC');
    return rows.map(Dealer.fromMap).toList();
  }

  static Future<void> saveDealer(Dealer d) async {
    final database = await db;
    final map = d.toMap();
    map['synced'] = 0;
    await database.insert('dealers', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteDealer(String id) async {
    final database = await db;
    await database.delete('dealers', where: 'id = ?', whereArgs: [id]);
  }

  /// Record a purchase from a dealer: adds to total purchased and to the
  /// amount owed. If [paidNow] > 0, that much is settled immediately.
  static Future<void> recordDealerPurchase(String id, double amount, double paidNow) async {
    final database = await db;
    await database.rawUpdate(
      'UPDATE dealers SET total_purchased = total_purchased + ?, '
      'balance_payable = balance_payable + ?, synced = 0 WHERE id = ?',
      [amount, amount - paidNow, id],
    );
  }

  /// Record a payment made to a dealer, reducing the amount owed.
  static Future<void> recordDealerPayment(String id, double amount) async {
    final database = await db;
    await database.rawUpdate(
      'UPDATE dealers SET balance_payable = balance_payable - ?, synced = 0 WHERE id = ?',
      [amount, id],
    );
  }

  // ── Dealer purchase ledger ─────────────────────────────────────────────────

  /// Appends a purchase line. Never updates an existing row: buying the same
  /// product again must add to the history, not replace what came before.
  static Future<void> insertDealerPurchase(DealerPurchase p) async {
    final database = await db;
    final map = p.toMap();
    map['synced'] = 0;
    await database.insert('dealer_purchases', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Purchase history for one dealer, newest first.
  static Future<List<DealerPurchase>> getDealerPurchases(String dealerId) async {
    final database = await db;
    final rows = await database.query('dealer_purchases',
        where: 'dealer_id = ?', whereArgs: [dealerId], orderBy: 'purchase_date DESC');
    return rows.map(DealerPurchase.fromMap).toList();
  }

  static Future<void> deleteDealerPurchasesFor(String dealerId) async {
    final database = await db;
    await database
        .delete('dealer_purchases', where: 'dealer_id = ?', whereArgs: [dealerId]);
  }

  static Future<List<DealerPurchase>> getUnsyncedDealerPurchases() async {
    final database = await db;
    final rows = await database
        .query('dealer_purchases', where: 'synced = ?', whereArgs: [0]);
    return rows.map(DealerPurchase.fromMap).toList();
  }

  static Future<void> markDealerPurchaseSynced(String id) async {
    final database = await db;
    await database
        .update('dealer_purchases', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> insertDealerPurchasesSynced(List<DealerPurchase> items) async {
    final database = await db;
    final batch = database.batch();
    for (final p in items) {
      final map = p.toMap();
      map['synced'] = 1;
      batch.insert('dealer_purchases', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Dealer>> getUnsyncedDealers() async {
    final database = await db;
    final rows = await database.query('dealers', where: 'synced = ?', whereArgs: [0]);
    return rows.map(Dealer.fromMap).toList();
  }

  static Future<void> markDealerSynced(String id) async {
    final database = await db;
    await database.update('dealers', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> insertDealersSynced(List<Dealer> dealers) async {
    final database = await db;
    final batch = database.batch();
    for (final d in dealers) {
      final map = d.toMap();
      map['synced'] = 1;
      batch.insert('dealers', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
