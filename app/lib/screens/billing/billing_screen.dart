import 'dart:async';
import 'dart:convert' as dart_convert;
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:math' show max, Random;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/customer.dart';
import '../../models/dealer.dart';
import '../../models/product.dart';
import '../../models/transaction_record.dart';
import '../../providers/cart_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/escpos_receipt.dart';
import '../../services/label_printer_service.dart';
import '../../services/local_db_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/update_service.dart';
import 'package:printing/printing.dart' show Printer, Printing, PdfPreview;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart' as bc;
import '../../services/receipt_printer.dart';
import '../../services/whatsapp_service.dart' as _wa;
import '../auth/login_screen.dart';

const _defaultProducts = <Product>[];


// ── Currency data ────────────────────────────────────────────────────────────

typedef _Currency = ({String flag, String code, String name, String symbol});

const List<_Currency> _currencies = [
  (flag: '🇮🇳', code: 'INR', name: 'Indian Rupee',           symbol: '₹'),
  (flag: '🇺🇸', code: 'USD', name: 'US Dollar',               symbol: '\$'),
  (flag: '🇪🇺', code: 'EUR', name: 'Euro',                    symbol: '€'),
  (flag: '🇬🇧', code: 'GBP', name: 'British Pound',           symbol: '£'),
  (flag: '🇯🇵', code: 'JPY', name: 'Japanese Yen',            symbol: '¥'),
  (flag: '🇨🇳', code: 'CNY', name: 'Chinese Yuan',            symbol: '¥'),
  (flag: '🇦🇺', code: 'AUD', name: 'Australian Dollar',       symbol: 'A\$'),
  (flag: '🇨🇦', code: 'CAD', name: 'Canadian Dollar',         symbol: 'C\$'),
  (flag: '🇨🇭', code: 'CHF', name: 'Swiss Franc',             symbol: 'Fr'),
  (flag: '🇸🇬', code: 'SGD', name: 'Singapore Dollar',        symbol: 'S\$'),
  (flag: '🇭🇰', code: 'HKD', name: 'Hong Kong Dollar',        symbol: 'HK\$'),
  (flag: '🇳🇿', code: 'NZD', name: 'New Zealand Dollar',      symbol: 'NZ\$'),
  (flag: '🇰🇷', code: 'KRW', name: 'South Korean Won',        symbol: '₩'),
  (flag: '🇳🇴', code: 'NOK', name: 'Norwegian Krone',         symbol: 'kr'),
  (flag: '🇸🇪', code: 'SEK', name: 'Swedish Krona',           symbol: 'kr'),
  (flag: '🇩🇰', code: 'DKK', name: 'Danish Krone',            symbol: 'kr'),
  (flag: '🇲🇽', code: 'MXN', name: 'Mexican Peso',            symbol: 'MX\$'),
  (flag: '🇿🇦', code: 'ZAR', name: 'South African Rand',      symbol: 'R'),
  (flag: '🇧🇷', code: 'BRL', name: 'Brazilian Real',          symbol: 'R\$'),
  (flag: '🇦🇪', code: 'AED', name: 'UAE Dirham',              symbol: 'د.إ'),
  (flag: '🇸🇦', code: 'SAR', name: 'Saudi Riyal',             symbol: '﷼'),
  (flag: '🇹🇭', code: 'THB', name: 'Thai Baht',               symbol: '฿'),
  (flag: '🇮🇩', code: 'IDR', name: 'Indonesian Rupiah',       symbol: 'Rp'),
  (flag: '🇲🇾', code: 'MYR', name: 'Malaysian Ringgit',       symbol: 'RM'),
  (flag: '🇵🇭', code: 'PHP', name: 'Philippine Peso',         symbol: '₱'),
  (flag: '🇵🇰', code: 'PKR', name: 'Pakistani Rupee',         symbol: '₨'),
  (flag: '🇧🇩', code: 'BDT', name: 'Bangladeshi Taka',        symbol: '৳'),
  (flag: '🇱🇰', code: 'LKR', name: 'Sri Lankan Rupee',        symbol: '₨'),
  (flag: '🇳🇵', code: 'NPR', name: 'Nepalese Rupee',          symbol: '₨'),
  (flag: '🇹🇷', code: 'TRY', name: 'Turkish Lira',            symbol: '₺'),
  (flag: '🇷🇺', code: 'RUB', name: 'Russian Ruble',           symbol: '₽'),
  (flag: '🇵🇱', code: 'PLN', name: 'Polish Zloty',            symbol: 'zł'),
  (flag: '🇨🇿', code: 'CZK', name: 'Czech Koruna',            symbol: 'Kč'),
  (flag: '🇭🇺', code: 'HUF', name: 'Hungarian Forint',        symbol: 'Ft'),
  (flag: '🇷🇴', code: 'RON', name: 'Romanian Leu',            symbol: 'lei'),
  (flag: '🇺🇦', code: 'UAH', name: 'Ukrainian Hryvnia',       symbol: '₴'),
  (flag: '🇮🇱', code: 'ILS', name: 'Israeli New Shekel',      symbol: '₪'),
  (flag: '🇰🇼', code: 'KWD', name: 'Kuwaiti Dinar',           symbol: 'KD'),
  (flag: '🇧🇭', code: 'BHD', name: 'Bahraini Dinar',          symbol: 'BD'),
  (flag: '🇶🇦', code: 'QAR', name: 'Qatari Riyal',            symbol: 'QR'),
  (flag: '🇴🇲', code: 'OMR', name: 'Omani Rial',              symbol: 'OMR'),
  (flag: '🇯🇴', code: 'JOD', name: 'Jordanian Dinar',         symbol: 'JD'),
  (flag: '🇪🇬', code: 'EGP', name: 'Egyptian Pound',          symbol: 'E£'),
  (flag: '🇳🇬', code: 'NGN', name: 'Nigerian Naira',          symbol: '₦'),
  (flag: '🇰🇪', code: 'KES', name: 'Kenyan Shilling',         symbol: 'KSh'),
  (flag: '🇬🇭', code: 'GHS', name: 'Ghanaian Cedi',           symbol: '₵'),
  (flag: '🇹🇿', code: 'TZS', name: 'Tanzanian Shilling',      symbol: 'TSh'),
  (flag: '🇺🇬', code: 'UGX', name: 'Ugandan Shilling',        symbol: 'USh'),
  (flag: '🇪🇹', code: 'ETB', name: 'Ethiopian Birr',          symbol: 'Br'),
  (flag: '🇦🇷', code: 'ARS', name: 'Argentine Peso',          symbol: 'AR\$'),
  (flag: '🇨🇱', code: 'CLP', name: 'Chilean Peso',            symbol: 'CL\$'),
  (flag: '🇨🇴', code: 'COP', name: 'Colombian Peso',          symbol: 'CO\$'),
  (flag: '🇵🇪', code: 'PEN', name: 'Peruvian Sol',            symbol: 'S/'),
  (flag: '🇻🇳', code: 'VND', name: 'Vietnamese Dong',         symbol: '₫'),
  (flag: '🇹🇼', code: 'TWD', name: 'Taiwan Dollar',           symbol: 'NT\$'),
  (flag: '🇮🇷', code: 'IRR', name: 'Iranian Rial',            symbol: '﷼'),
  (flag: '🇲🇦', code: 'MAD', name: 'Moroccan Dirham',         symbol: 'MAD'),
  (flag: '🇩🇿', code: 'DZD', name: 'Algerian Dinar',          symbol: 'دج'),
  (flag: '🇹🇳', code: 'TND', name: 'Tunisian Dinar',          symbol: 'DT'),
  (flag: '🇮🇸', code: 'ISK', name: 'Icelandic Króna',         symbol: 'kr'),
  (flag: '🇭🇷', code: 'HRK', name: 'Croatian Kuna',           symbol: 'kn'),
  (flag: '🇷🇸', code: 'RSD', name: 'Serbian Dinar',           symbol: 'din'),
  (flag: '🇧🇬', code: 'BGN', name: 'Bulgarian Lev',           symbol: 'лв'),
  (flag: '🇲🇲', code: 'MMK', name: 'Myanmar Kyat',            symbol: 'K'),
  (flag: '🇰🇭', code: 'KHR', name: 'Cambodian Riel',          symbol: '៛'),
  (flag: '🇱🇦', code: 'LAK', name: 'Lao Kip',                 symbol: '₭'),
  (flag: '🇲🇳', code: 'MNT', name: 'Mongolian Tugrik',        symbol: '₮'),
  (flag: '🇦🇲', code: 'AMD', name: 'Armenian Dram',           symbol: '֏'),
  (flag: '🇬🇪', code: 'GEL', name: 'Georgian Lari',           symbol: '₾'),
  (flag: '🇦🇿', code: 'AZN', name: 'Azerbaijani Manat',       symbol: '₼'),
  (flag: '🇰🇿', code: 'KZT', name: 'Kazakhstani Tenge',       symbol: '₸'),
  (flag: '🇺🇿', code: 'UZS', name: 'Uzbekistani Sum',         symbol: 'лв'),
  (flag: '🇹🇲', code: 'TMT', name: 'Turkmenistani Manat',     symbol: 'T'),
  (flag: '🇧🇾', code: 'BYN', name: 'Belarusian Ruble',        symbol: 'Br'),
  (flag: '🇲🇩', code: 'MDL', name: 'Moldovan Leu',            symbol: 'L'),
  (flag: '🇦🇱', code: 'ALL', name: 'Albanian Lek',            symbol: 'L'),
  (flag: '🇲🇰', code: 'MKD', name: 'Macedonian Denar',        symbol: 'ден'),
  (flag: '🇧🇦', code: 'BAM', name: 'Bosnia Mark',             symbol: 'KM'),
  (flag: '🇲🇹', code: 'MTL', name: 'Maltese Lira',            symbol: 'Lm'),
  (flag: '🇵🇦', code: 'PAB', name: 'Panamanian Balboa',       symbol: 'B/.'),
  (flag: '🇨🇷', code: 'CRC', name: 'Costa Rican Colón',       symbol: '₡'),
  (flag: '🇬🇹', code: 'GTQ', name: 'Guatemalan Quetzal',      symbol: 'Q'),
  (flag: '🇧🇴', code: 'BOB', name: 'Bolivian Boliviano',      symbol: 'Bs.'),
  (flag: '🇵🇾', code: 'PYG', name: 'Paraguayan Guaraní',      symbol: '₲'),
  (flag: '🇺🇾', code: 'UYU', name: 'Uruguayan Peso',          symbol: 'UY\$'),
  (flag: '🇪🇨', code: 'USD', name: 'Ecuadorian (USD)',         symbol: '\$'),
  (flag: '🇨🇺', code: 'CUP', name: 'Cuban Peso',              symbol: '₱'),
  (flag: '🇩🇴', code: 'DOP', name: 'Dominican Peso',          symbol: 'RD\$'),
  (flag: '🇯🇲', code: 'JMD', name: 'Jamaican Dollar',         symbol: 'J\$'),
  (flag: '🇹🇹', code: 'TTD', name: 'Trinidad Dollar',         symbol: 'TT\$'),
  (flag: '🇧🇧', code: 'BBD', name: 'Barbadian Dollar',        symbol: 'Bds\$'),
  (flag: '🇫🇯', code: 'FJD', name: 'Fijian Dollar',           symbol: 'FJ\$'),
  (flag: '🇵🇬', code: 'PGK', name: 'Papua New Guinea Kina',   symbol: 'K'),
];

/// The one true bill number shown anywhere in the app: the invoice number
/// assigned at checkout when there is one, otherwise a short slice of the
/// transaction id. Receipts, reports, dialogs and searches must all use
/// this so a customer's printed number always matches what staff see.
String billNo(TransactionRecord t) =>
    (t.invoiceNumber?.isNotEmpty == true)
        ? t.invoiceNumber!
        : t.id.substring(0, 6).toUpperCase();

/// Money with Indian-style comma grouping: 1234567.5 → "₹12,34,567.50".
/// Top-level so the product/cart card widgets can use it too.
String fmtMoney(String symbol, double v, {int decimals = 2}) {
  final neg = v < 0;
  final parts = v.abs().toStringAsFixed(decimals).split('.');
  var intPart = parts[0];
  if (intPart.length > 3) {
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final grouped = rest.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
    intPart = '$grouped,$last3';
  }
  final dec = parts.length > 1 ? '.${parts[1]}' : '';
  return '${neg ? '-' : ''}$symbol$intPart$dec';
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Product> _products = List.from(_defaultProducts);
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  int _selectedTab = 1;
  String _scanBuffer = '';
  String _inventorySearchQuery = '';
  String _inventoryCategoryFilter = 'All';
  double _rightPanelWidth = 375;

  // Reports state
  String _reportView    = 'Sales';
  String _utilitiesView = 'Quotation';

  // ── Quotation screen state ──────────────────────────────────────────────
  final List<_QuoteLine> _quoteLines = [];
  final TextEditingController _quoteCustomerCtrl = TextEditingController();
  final TextEditingController _quotePhoneCtrl = TextEditingController();
  bool _quoteApplyTax = true;
  String? _quoteNumber;
  String _salesSearchQuery = '';
  String _customerSearchQuery = '';
  bool _showCreditOnly = false;
  String _dealerSearchQuery = '';
  bool _showPayableOnly = false;
  List<Dealer> _reportDealers = [];
  List<Customer> _reportCustomers = [];
  List<Customer> _savedCustomers = [];
  List<Customer> _nameAcOptions = [];
  List<Customer> _phoneAcOptions = [];
  bool _acSkipRefocus = false;
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerNameFocus = FocusNode();
  final _customerPhoneFocus = FocusNode();
  final _addCustomerFocus = FocusNode();
  final _discountFocus = FocusNode();

  // Dynamic categories (user can add more)
  List<String> _userCategories = [];

  // Dashboard state (real data)
  double _dashSales = 0;
  int    _dashTxCount = 0;
  int    _dashItemsSold = 0;
  double _dashAvgOrder = 0;
  double _dashYestSales = 0;
  int    _dashYestTxCount = 0;
  int    _dashYestItems = 0;
  double _dashYestAvg = 0;
  double _dashWeekSales = 0;
  double _dashMonthSales = 0;
  double _dashYearSales = 0;

  // Per-period additional metrics
  int    _dashWeekTxCount = 0;  int _dashWeekItems = 0;  double _dashWeekAvg = 0;
  int    _dashMonthTxCount = 0; int _dashMonthItems = 0; double _dashMonthAvg = 0;
  int    _dashYearTxCount = 0;  int _dashYearItems = 0;  double _dashYearAvg = 0;

  // Profit per period
  double _dashProfitToday = 0;
  double _dashProfitWeek  = 0;
  double _dashProfitMonth = 0;
  double _dashProfitYear  = 0;

  // Period selector
  String _dashPeriod = 'Today';

  // Chart bars per period
  List<(String, double)> _chartBarsToday = [];
  List<(String, double)> _chartBarsWeek  = [];
  List<(String, double)> _chartBarsMonth = [];
  List<(String, double)> _chartBarsYear  = [];

  // Same-day last week (for "No data yesterday" comparison)
  double _dashLastWeekSameDaySales = 0;

  // Top sold products per period: (name, qty, revenue)
  List<(String, int, double)> _topProductsToday = [];
  List<(String, int, double)> _topProductsWeek  = [];
  List<(String, int, double)> _topProductsMonth = [];
  List<(String, int, double)> _topProductsYear  = [];
  List<(String, double, Color)> _dashCategories = [];
  List<TransactionRecord> _dashRecentTx = [];

  // Sales report period
  String _reportSalesPeriod = 'This Week';
  List<TransactionRecord> _txListToday = [];
  List<TransactionRecord> _txListWeek  = [];
  List<TransactionRecord> _txListMonth = [];

  // Settings state
  String _storeName = 'BillCat Store';
  String _storeAddress = '';
  String _storePhone = '';
  String _storeEmail = '';
  String _storeGstin = '';
  String _logoPath = '';
  String _logoUrl  = '';
  String _receiptFooter = 'Thank you for your purchase!';
  String _taxLabel = 'GST';
  String _taxRateDisplay = '0';
  String _currencySymbol = '₹';
  String _currencyCode = 'INR';
  String _dialCode = '+91'; // default India
  String _invoiceLayout = 'Classic';
  String _printOrientation = 'Portrait';
  String _storeTerms = 'Payment due within 30 days. Goods once sold will not be taken back.';
  String _storeUpiId = '';
  String _branchNumber = '01';

  // Printer state
  String _selectedPrinter = 'System Default';
  Printer? _activePrinter;
  String _paperSize = 'A4';
  bool _autoPrint = false;
  // Thermal (ESC/POS) options — printers without a cutter set this false.
  bool _thermalAutoCut = true;

  // Print bill dialog last-used settings
  String _lastPrintDocType = 'Invoice';
  bool _lastPrintToPrinter = false;
  bool _lastPrintWhatsApp = false;

  // Focuses the VARIANT box so a freshly added variant can be renamed in place.
  final FocusNode _variantNameFocus = FocusNode();

  // Product whose variants are currently expanded inline in the billing grid.
  String? _expandedVariantProductId;

  // Grid entries: normally all products; while a product's variants are
  // expanded, the grid shows that product followed by its variant cards.
  List<Object> get _displayGridItems {
    final expandedId = _expandedVariantProductId;
    if (expandedId != null) {
      final parent = _filteredProducts.cast<Product?>().firstWhere(
            (p) => p!.id == expandedId,
            orElse: () => null,
          );
      if (parent != null && parent.variants.isNotEmpty) {
        return <Object>[parent, ...parent.variants.map((v) => (parent, v))];
      }
    }
    return List<Object>.from(_filteredProducts);
  }

  // Current queued invoice number
  String _queuedInvoiceNo = '';
  String _queuedTransactionId = '';

  // Barcode print last-used settings
  double _barcodeLabelW = 58;
  double _barcodeLabelH = 30;
  int _barcodePerRow = 1;
  String _barcodePrinter = 'System Default';

  // Bulk barcode print view
  Map<String, int> _bulkPrintQtys = {};
  Map<String, bool> _bulkPrintSelected = {};
  List<String> _bulkPrinters = ['System Default'];


  // Top toast
  String _toastMessage = '';
  bool _toastVisible = false;
  bool _toastIsError = false;

  // Update banner
  UpdateInfo? _updateInfo;
  bool _updateDismissed = false;
  bool _isCheckingUpdate = false;
  String _currentVersion = '';
  double? _downloadProgress; // null=idle, 0–1=downloading, 1.0=done
  String _downloadedPath = '';

  // Owner / Staff access
  bool   _ownerLockEnabled = false;
  bool   _isOwnerMode      = false;
  String _ownerPasscode    = '';

  // Settings panel
  bool _showSettings = false;
  bool _isPrinting = false;
  Timer? _printSafetyTimer;
  bool _addingCustomProduct = false;
  final _customNameCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customNameFocus = FocusNode();
  final _customPriceFocus = FocusNode();
  int _customQty = 1;
  String _settingsPage = 'General';
  String _editStoreName = 'BillCat Store';
  String _editStoreAddress = '';
  String _editLogoPath = '';
  String _editLogoUrl  = '';
  String _editReceiptFooter = 'Thank you for your purchase!';
  String _editTaxLabel = 'VAT';
  String _editTaxRate = '0';
  String _editCurrencyCode = 'INR';
  String _editCurrencySymbol = '₹';
  String _editDialCode = '+91';
  String _editPaperSize = 'A4';
  bool _editAutoPrint = false;
  String _editStorePhone = '';
  String _editStoreEmail = '';
  String _editStoreGstin = '';
  String _editInvoiceLayout = 'Classic';
  String _editPrintOrientation = 'Portrait';
  String _editPrinterTab = 'Regular';
  int _previewRevision = 0;
  String _editStoreTerms = 'Payment due within 30 days. Goods once sold will not be taken back.';
  String _editStoreUpiId = '';
  String _editBranchNumber = '01';

  // WhatsApp Meta Cloud API
  String _waPhoneNumberId = '';
  String _waAccessToken = '';
  String _editWaPhoneNumberId = '';
  String _editWaAccessToken = '';


  List<Product> get _filteredProducts {
    return _products.where((p) {
      final matchCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _cleanupCupsOptions();
    _loadSettingsFromStorage();
    _loadProducts();
    _loadDashboardData();
    _loadSavedCustomers();
    ConnectivityService.instance.addListener(_onSyncComplete);
    _checkForUpdate();
    _loadCurrentVersion();
    ReceiptPrinter.preWarm();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTaxRate());
    // Keep the scan/search bar focused when idle so a barcode scanner works
    // without clicking, and focus returns to it after each add.
    _searchFocus.addListener(_keepSearchFocusedWhenIdle);
  }

  void _keepSearchFocusedWhenIdle() {
    if (_searchFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedTab != 1 || _showSettings) return;          // only idle Billing screen
      if (ModalRoute.of(context)?.isCurrent == false) return;  // a dialog is open
      final pf = FocusManager.instance.primaryFocus;
      // Only reclaim focus if nothing meaningful grabbed it (e.g. tapped empty
      // space). Never steal from customer name/phone, discount, qty edits, etc.
      final somethingElseFocused = pf != null && pf.hasPrimaryFocus && pf != _searchFocus;
      if (!somethingElseFocused) _searchFocus.requestFocus();
    });
  }

  // Removes corrupted BillCat-specific CUPS options written by older app versions.
  // Those lpoptions entries caused Printers & Scanners in System Settings to freeze.
  Future<void> _cleanupCupsOptions() async {
    try {
      final file = File('${Platform.environment['HOME']}/.cups/lpoptions');
      if (!file.existsSync()) return;
      final lines = file.readAsLinesSync();
      final cleaned = lines.map((line) {
        // Remove BillCat_* media and PageSize options from any line
        var l = line.replaceAll(RegExp(r'\s*media=BillCat_\S+'), '');
        l = l.replaceAll(RegExp(r'\s*PageSize=Custom\.\d+x\d+'), '');
        return l.trim();
      }).where((l) => l.isNotEmpty).toList();
      if (cleaned.join('\n') != lines.join('\n')) {
        file.writeAsStringSync('${cleaned.join('\n')}\n');
      }
    } catch (_) {}
  }

  Future<void> _loadSettingsFromStorage() async {
    LabelPrinterService.load(); // device-local label-printer profile (not synced)
    final s = await LocalDbService.getSettings();
    if (!mounted) return;
    setState(() {
      _storeName = s['store_name'] ?? _storeName;
      _storeAddress = s['store_address'] ?? _storeAddress;
      _storePhone = s['store_phone'] ?? _storePhone;
      _storeEmail = s['store_email'] ?? _storeEmail;
      _storeGstin = s['store_gstin'] ?? _storeGstin;
      _receiptFooter = s['receipt_footer'] ?? _receiptFooter;
      _taxLabel = s['tax_label'] ?? _taxLabel;
      _taxRateDisplay = s['tax_rate'] ?? _taxRateDisplay;
      _currencyCode = s['currency_code'] ?? _currencyCode;
      _currencySymbol = s['currency_symbol'] ?? _currencySymbol;
      _dialCode = s['dial_code'] ?? _dialCode;
      _paperSize = s['paper_size'] ?? _paperSize;
      _selectedPrinter = s['selected_printer'] ?? _selectedPrinter;
      // Label size falls back to the (legacy) synced value for migration; the
      // printer NAME is device-local only — never inherited from another device.
      _barcodeLabelW = double.tryParse(s['barcode_label_w'] ?? '') ?? _barcodeLabelW;
      _barcodeLabelH = double.tryParse(s['barcode_label_h'] ?? '') ?? _barcodeLabelH;
      _barcodePerRow = int.tryParse(s['barcode_per_row'] ?? '') ?? _barcodePerRow;
      _printOrientation = s['print_orientation'] ?? _printOrientation;
      final savedLayout = s['invoice_layout'] ?? _invoiceLayout;
      const _validLayouts = ['Classic','Simple','Modern','GST','Landscape','Theme 1','Theme 2','Theme 3','Theme 4','Theme 5'];
      _invoiceLayout = _validLayouts.contains(savedLayout) ? savedLayout : 'Classic';
      _storeTerms = s['store_terms'] ?? _storeTerms;
      _logoPath = s['logo_path'] ?? _logoPath;
      // Prefer local setting; fall back to auth user metadata logo_url
      final metaLogoUrl = Supabase.instance.client.auth.currentUser
          ?.userMetadata?['logo_url'] as String? ?? '';
      _logoUrl = (s['logo_url']?.isNotEmpty == true ? s['logo_url']! : metaLogoUrl);
      _autoPrint = (s['auto_print'] ?? '0') == '1';
      _thermalAutoCut = (s['thermal_auto_cut'] ?? '1') == '1';
      final savedPrintDocType = s['print_doc_type'] ?? _lastPrintDocType;
      _lastPrintDocType = savedPrintDocType == 'Quotation' ? 'Quotation' : 'Invoice';
      _lastPrintToPrinter = (s['print_to_printer'] ?? '0') == '1';
      _lastPrintWhatsApp = (s['print_via_whatsapp'] ?? '0') == '1';
      _storeUpiId = s['store_upi_id'] ?? _storeUpiId;
      _branchNumber = s['branch_number'] ?? _branchNumber;
      _ownerPasscode    = s['owner_passcode'] ?? '';
      _ownerLockEnabled = (s['owner_lock_enabled'] ?? '0') == '1';
      _waPhoneNumberId = s['wa_phone_number_id'] ?? '';
      _waAccessToken = s['wa_access_token'] ?? '';
      _editWaPhoneNumberId = _waPhoneNumberId;
      _editWaAccessToken = _waAccessToken;
    });
    // Device-local barcode config (printer name + label size) — overrides the
    // synced values so each machine keeps its own printer without clashing.
    final bc = await LabelPrinterService.loadBarcodeSettings();
    if (mounted && bc.isNotEmpty) {
      setState(() {
        _barcodeLabelW = (bc['labelW'] as num?)?.toDouble() ?? _barcodeLabelW;
        _barcodeLabelH = (bc['labelH'] as num?)?.toDouble() ?? _barcodeLabelH;
        _barcodePerRow = (bc['perRow'] as num?)?.toInt() ?? _barcodePerRow;
        _barcodePrinter = (bc['printer'] as String?) ?? _barcodePrinter;
      });
    }
    _syncTaxRate();
    _restoreActivePrinter();
    _refreshQueuedInvoiceNo();
  }

  void _refreshQueuedInvoiceNo() {
    final prefix = _storeName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final p = prefix.length >= 3 ? prefix.substring(0, 3) : prefix.padRight(3, 'X');
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final rand = List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
    final txId = Uuid().v4();
    if (mounted) setState(() {
      _queuedInvoiceNo = '$p-$rand';
      _queuedTransactionId = txId;
    });
  }

  Future<void> _restoreActivePrinter() async {
    if (_selectedPrinter == 'PDF Export' || _selectedPrinter == 'System Default') return;
    try {
      final printers = await Printing.listPrinters();
      final match = printers.where((p) => p.name == _selectedPrinter).toList();
      if (match.isNotEmpty && mounted) setState(() => _activePrinter = match.first);
    } catch (_) {}
  }

  void _syncTaxRate() {
    final cart = context.read<CartProvider>();
    cart.setTaxRate(double.tryParse(_taxRateDisplay) ?? 0.0);
  }

  Future<void> _loadSavedCustomers() async {
    final customers = await LocalDbService.getCustomers();
    if (mounted) setState(() => _savedCustomers = customers);
  }

  Future<void> _loadCurrentVersion() async {
    final v = await UpdateService.currentVersion();
    if (mounted) setState(() => _currentVersion = v);
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await UpdateService.checkForUpdate();
      if (mounted && info != null) setState(() => _updateInfo = info);
    } catch (_) {}
  }

  Future<void> _manualCheckForUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() { _isCheckingUpdate = true; _updateDismissed = false; });
    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;
      if (info != null) {
        setState(() { _updateInfo = info; _isCheckingUpdate = false; });
      } else {
        setState(() { _updateInfo = null; _isCheckingUpdate = false; });
        if (mounted) {
          _showToast('BillCat is up to date (v${_currentVersion.isNotEmpty ? _currentVersion : '1.0.0'})');
        }
      }
    } on UpdateCheckError catch (e) {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
        _showToast(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  Future<void> _installUpdate() async {
    final info = _updateInfo;
    if (info == null || _downloadProgress != null) return;
    setState(() { _downloadProgress = 0.0; _downloadedPath = ''; });
    try {
      await UpdateService.installUpdate(
        info.downloadUrl,
        (p) { if (mounted) setState(() => _downloadProgress = p); },
      );
    } on UpdateCheckError catch (e) {
      if (mounted) {
        setState(() => _downloadProgress = null);
        _showToast(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) setState(() => _downloadProgress = null);
    }
  }

  Future<void> _loadProducts() async {
    await LocalDbService.assignMissingBarcodeNos();
    final local = await LocalDbService.getProducts();
    final savedCats = await LocalDbService.getCategories();
    if (mounted) setState(() {
      _products = local;
      final seen = <String>{};
      // Merge: categories from DB table + categories from products
      final fromProducts = local
          .map((p) => p.category)
          .where((c) => c.isNotEmpty)
          .toSet();
      _userCategories = [
        ...savedCats,
        ...fromProducts.where((c) => !savedCats.contains(c)),
      ].where((c) => seen.add(c)).toList();
    });
  }

  Future<void> _loadDashboardData() async {
    final today     = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    // Week: Mon–today
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    // Month: 1st of current month
    final monthStart = DateTime(today.year, today.month, 1);
    // Year: Jan 1
    final yearStart  = DateTime(today.year, 1, 1);

    final lastWeekSameDay = today.subtract(const Duration(days: 7));

    final results = await Future.wait([
      LocalDbService.getTransactionsForDate(today),
      LocalDbService.getTransactionsForDate(yesterday),
      LocalDbService.getTransactionsForRange(weekStart, today),
      LocalDbService.getTransactionsForRange(monthStart, today),
      LocalDbService.getTransactionsForRange(yearStart, today),
      LocalDbService.getTransactionsForDate(lastWeekSameDay),
    ]);

    final todayTx          = results[0];
    final yesterdayTx      = results[1];
    final weekTx           = results[2];
    final monthTx          = results[3];
    final yearTx           = results[4];
    final lastWeekSameDayTx = results[5];

    final products = await LocalDbService.getProducts();
    final catMap          = {for (final p in products) p.id: p.category};
    final buyingPriceMap  = {for (final p in products) p.id: p.buyingPrice};

    // Refund/exchange documents adjust revenue (their totals are negative),
    // but they are not additional *sales*: counting them inflated the
    // transaction count and dragged average order value down, and their
    // negative lines could push Items Sold below zero.
    bool isReturnDoc(TransactionRecord t) =>
        t.paymentMethod.toLowerCase() == 'refund' ||
        t.paymentMethod.toLowerCase().startsWith('exchange-') ||
        (t.invoiceNumber ?? '').startsWith('R-');

    double sales = 0, ySales = 0;
    int txCount = todayTx.where((t) => !isReturnDoc(t)).length,
        yTxCount = yesterdayTx.where((t) => !isReturnDoc(t)).length;
    int items = 0, yItems = 0;
    final catRevenue = <String, double>{};

    for (final t in todayTx) {
      sales += t.total;
      for (final i in t.items) {
        // Returned units reduce the count; exchange units still count as sold.
        items += i.quantity;
        final cat = catMap[i.productId] ?? 'Other';
        catRevenue[cat] = (catRevenue[cat] ?? 0) + i.total;
      }
    }
    for (final t in yesterdayTx) {
      ySales += t.total;
      for (final i in t.items) yItems += i.quantity;
    }

    double weekSales           = weekTx.fold(0.0,           (s, t) => s + t.total);
    double monthSales          = monthTx.fold(0.0,          (s, t) => s + t.total);
    double yearSales           = yearTx.fold(0.0,           (s, t) => s + t.total);
    double lastWeekSameDaySales = lastWeekSameDayTx.fold(0.0, (s, t) => s + t.total);

    int weekItems = 0, monthItems = 0, yearItems = 0;
    for (final t in weekTx)  { for (final i in t.items) weekItems  += i.quantity; }
    for (final t in monthTx) { for (final i in t.items) monthItems += i.quantity; }
    for (final t in yearTx)  { for (final i in t.items) yearItems  += i.quantity; }

    // ── Profit per period ─────────────────────────────────────────────────────
    double calcProfit(List<TransactionRecord> txs) {
      double profit = 0;
      for (final t in txs) {
        double cogs = 0;
        for (final i in t.items) {
          cogs += (buyingPriceMap[i.productId] ?? 0.0) * i.quantity;
        }
        profit += t.total - cogs;
      }
      return profit;
    }
    final profitToday = calcProfit(todayTx);
    final profitWeek  = calcProfit(weekTx);
    final profitMonth = calcProfit(monthTx);
    final profitYear  = calcProfit(yearTx);

    // ── Chart bars ────────────────────────────────────────────────────────────
    // Today: 8 three-hour slots
    final tSlotLabels = ['12a','3a','6a','9a','12p','3p','6p','9p'];
    final tSlotMap = {for (final l in tSlotLabels) l: 0.0};
    for (final t in todayTx) { final l = tSlotLabels[t.createdAt.hour ~/ 3]; tSlotMap[l] = tSlotMap[l]! + t.total; }
    final chartToday = tSlotLabels.map((l) => (l, tSlotMap[l]!)).toList();

    // Week: Mon–Sun
    const wLabels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final wMap = {for (final l in wLabels) l: 0.0};
    for (final t in weekTx) { final l = wLabels[t.createdAt.weekday - 1]; wMap[l] = wMap[l]! + t.total; }
    final chartWeek = wLabels.map((l) => (l, wMap[l]!)).toList();

    // Month: weeks W1–W5
    const mLabels = ['W1','W2','W3','W4','W5'];
    final mMap = {for (final l in mLabels) l: 0.0};
    for (final t in monthTx) { final l = 'W${((t.createdAt.day - 1) ~/ 7) + 1}'; mMap[l] = (mMap[l] ?? 0) + t.total; }
    final chartMonth = mLabels.map((l) => (l, mMap[l]!)).toList();

    // Year: Jan–Dec
    final yMap = {for (int i = 1; i <= 12; i++) _monthName(i): 0.0};
    for (final t in yearTx) { final l = _monthName(t.createdAt.month); yMap[l] = yMap[l]! + t.total; }
    final chartYear = List.generate(12, (i) => (_monthName(i + 1), yMap[_monthName(i + 1)]!));

    // ── Top sold products ─────────────────────────────────────────────────────
    List<(String, int, double)> _topOf(List<TransactionRecord> txs) {
      final map = <String, (int, double)>{};
      for (final t in txs) {
        for (final item in t.items) {
          final e = map[item.productName] ?? (0, 0.0);
          map[item.productName] = (e.$1 + item.quantity, e.$2 + item.total);
        }
      }
      final sorted = map.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
      return sorted.take(5).map((e) => (e.key, e.value.$1, e.value.$2)).toList();
    }
    final topToday = _topOf(todayTx);
    final topWeek  = _topOf(weekTx);
    final topMonth = _topOf(monthTx);
    final topYear  = _topOf(yearTx);

    const catColors = [
      Color(0xFF1B2B4B), Color(0xFF3B82F6), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEF4444),
    ];
    final sortedCats = catRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dashCats = sortedCats.take(5).toList().asMap().entries.map((e) =>
      (e.value.key, e.value.value, catColors[e.key % catColors.length])).toList();

    // ── Payment breakdown ─────────────────────────────────────────────────────
    const payColors = {
      'cash':   Color(0xFF10B981),
      'card':   Color(0xFF3B82F6),
      'upi':    Color(0xFF8B5CF6),
      'hybrid': Color(0xFFF59E0B),
    };
    if (!mounted) return;
    setState(() {
      _dashSales      = sales;
      _dashTxCount    = txCount;
      _dashItemsSold  = items;
      _dashAvgOrder   = txCount > 0 ? sales / txCount : 0;
      _dashYestSales  = ySales;
      _dashYestTxCount = yTxCount;
      _dashYestItems  = yItems;
      _dashYestAvg    = yTxCount > 0 ? ySales / yTxCount : 0;
      _dashWeekSales  = weekSales;
      _dashMonthSales = monthSales;
      _dashYearSales  = yearSales;
      _dashWeekTxCount  = weekTx.length;  _dashWeekItems  = weekItems;  _dashWeekAvg  = weekTx.isNotEmpty  ? weekSales  / weekTx.length  : 0;
      _dashMonthTxCount = monthTx.length; _dashMonthItems = monthItems; _dashMonthAvg = monthTx.isNotEmpty ? monthSales / monthTx.length : 0;
      _dashYearTxCount  = yearTx.length;  _dashYearItems  = yearItems;  _dashYearAvg  = yearTx.isNotEmpty  ? yearSales  / yearTx.length  : 0;
      _chartBarsToday = chartToday;
      _chartBarsWeek  = chartWeek;
      _chartBarsMonth = chartMonth;
      _chartBarsYear  = chartYear;
      _dashLastWeekSameDaySales = lastWeekSameDaySales;
      _topProductsToday = topToday;
      _topProductsWeek  = topWeek;
      _topProductsMonth = topMonth;
      _topProductsYear  = topYear;
      _dashCategories = dashCats;
      _dashRecentTx   = todayTx.take(5).toList();
      _txListToday = todayTx;
      _txListWeek  = weekTx;
      _txListMonth = monthTx;
      _dashProfitToday = profitToday;
      _dashProfitWeek  = profitWeek;
      _dashProfitMonth = profitMonth;
      _dashProfitYear  = profitYear;
    });
  }

  void _onSyncComplete() {
    _loadProducts();
    _loadDashboardData();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _printSafetyTimer?.cancel();
    ConnectivityService.instance.removeListener(_onSyncComplete);
    _searchController.dispose();
    _searchFocus.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    for (final l in _quoteLines) {
      l.dispose();
    }
    _quoteCustomerCtrl.dispose();
    _quotePhoneCtrl.dispose();
    _customerNameFocus.dispose();
    _customerPhoneFocus.dispose();
    _addCustomerFocus.dispose();
    _discountFocus.dispose();
    _customNameCtrl.dispose();
    _customPriceCtrl.dispose();
    _customNameFocus.dispose();
    _customPriceFocus.dispose();
    _variantNameFocus.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    setState(() {
      _toastMessage = message;
      _toastIsError = isError;
      _toastVisible = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _showSettings
              ? _buildSettingsPanel()
              : Column(
                  key: const ValueKey('main'),
                  children: [
                    _buildTopBar(),
                    _buildUpdateBanner(),
                    Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildDashboardView(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLeftPanel(),
                      _buildResizeDivider(),
                      _buildRightPanel(),
                    ],
                  ),
                  _buildInventoryView(),
                  _buildReportsView(),
                  _buildUtilitiesView(),
                ],
              ),
            ),
                    _buildBottomBar(),
                  ],
                ),
        ),
            // ── Top toast ──
            _buildToast(),
            // ── Print loading overlay ──
            if (_isPrinting)
              _buildPrintingOverlay(),
          ],
        ),
    );
  }

  Widget _buildPrintingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Preparing\nReceipt...',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D1D1F),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Toast ────────────────────────────────────────────────────────────────

  Widget _buildToast() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: _toastVisible ? Curves.easeOutBack : Curves.easeIn,
      top: _toastVisible ? 24 : -80,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: _toastVisible ? 1.0 : 0.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _toastIsError
                  ? const Color(0xFFB71C1C)
                  : const Color(0xFF1D1D1F),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _toastIsError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                  color: _toastIsError ? Colors.red[200] : const Color(0xFF4CAF50),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _toastMessage,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Update Banner ────────────────────────────────────────────────────────────

  Widget _buildUpdateBanner() {
    if (_updateInfo == null || _updateDismissed) return const SizedBox.shrink();
    final info = _updateInfo!;
    final isDownloading = _downloadProgress != null && _downloadProgress! < 1.0;
    final isDone = _downloadProgress != null && _downloadProgress! >= 1.0;
    final bannerColor = info.mandatory ? AppColors.error : const Color(0xFF1565C0);

    return Material(
      color: bannerColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update_alt_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isDownloading
                        ? 'Installing BillCat ${info.version}...'
                        : 'BillCat ${info.version} is available'
                            '${info.releaseNotes.isNotEmpty ? ' — ${info.releaseNotes}' : ''}',
                    style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                if (!isDownloading && !isDone)
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _installUpdate,
                    child: const Text('Install Update',
                        style: TextStyle(fontSize: 12)),
                  ),
                if (!info.mandatory && !isDownloading) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => setState(() {
                      _updateDismissed = true;
                      _downloadProgress = null;
                    }),
                    tooltip: 'Dismiss',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${((_downloadProgress ?? 0) * 100).toInt()}%',
                    style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Logo
          Image.asset('assets/images/billcat_icon.png', height: 100),
          const SizedBox(width: 20),
          // Nav tabs
          if (!_ownerLockEnabled || _isOwnerMode) ...[
            _navTab('Dashboard', 0),
            const SizedBox(width: 4),
          ],
          _navTab('Billing', 1),
          const SizedBox(width: 4),
          _navTab('Inventory', 2),
          if (!_ownerLockEnabled || _isOwnerMode) ...[
            const SizedBox(width: 4),
            _reportsDropdownTab(),
            const SizedBox(width: 4),
            _utilitiesDropdownTab(),
          ],
          const Spacer(),
          // Lock icon only shown when staff access control is enabled
          if (_ownerLockEnabled) ...[
            _topBarIconBtn(
              _isOwnerMode ? Icons.lock_open_outlined : Icons.lock_outline_rounded,
              _isOwnerMode ? 'Lock (Staff Mode)' : 'Owner Access',
              _isOwnerMode ? _lockOwnerMode : _showOwnerPasscodeDialog,
            ),
            const SizedBox(width: 8),
          ],
          // Print Barcodes (Inventory tab) or Printer (other tabs)
          if (_selectedTab == 2) ...[
            GestureDetector(
              onTap: () {
                _bulkPrintQtys = { for (final p in _products) p.id: p.stock > 0 ? p.stock : 1 };
                _bulkPrintSelected = {};
                _bulkPrinters = ['System Default'];
                _showBulkPrintDialog();
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.barcode_reader, color: Colors.white, size: 15),
                  const SizedBox(width: 7),
                  Text('Print Barcodes',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ),
          ],
          if (_selectedTab == 1) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showReturnExchangeDialog,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.assignment_return_outlined,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 7),
                  Text('Return/Exchange',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ]),
              ),
            ),
          ],
          if (_selectedTab != 2) ...[
            const SizedBox(width: 8),
            _topBarIconBtn(Icons.print_outlined, 'Printer', _showPrinterDialog),
          ],
          const SizedBox(width: 8),
          _topBarIconBtn(Icons.settings_outlined, 'Settings', _openSettings),
          const SizedBox(width: 16),
          // Profile avatar
          _buildProfileMenu(),
        ],
      ),
    );
  }

  // ── Return / Exchange ─────────────────────────────────────────────────────
  //
  // A return is recorded as a NEW transaction linked to the original by
  // invoice number ("R-<original>"): returned items carry negative
  // quantities (with the original bill's discount baked into their unit
  // price), exchange items are normal positive lines. Reports therefore
  // deduct refunds naturally, and insertReturnTransaction puts returned
  // stock back. No schema changes anywhere.

  /// Status chips for a bill: PAID/CREDIT plus RETURNED/EXCHANGED when a
  /// linked return exists. Returns are matched by their "R-<bill>" invoice
  /// number; a return that also contains positive-quantity lines was an
  /// exchange.
  List<(String, Color)> _billBadges(
      List<TransactionRecord> all, TransactionRecord t) {
    final out = <(String, Color)>[];
    final method = t.paymentMethod.toLowerCase();
    // The row IS a return document: label it by what it did.
    if (method == 'refund' ||
        method.startsWith('exchange-') ||
        (t.invoiceNumber ?? '').startsWith('R-')) {
      final hasExchange = t.items.any((i) => i.quantity > 0);
      out.add(hasExchange
          ? ('EXCHANGE', const Color(0xFF2563EB))
          : ('REFUND', const Color(0xFFDC2626)));
      return out;
    }
    if (method.contains('credit')) {
      out.add(('CREDIT', const Color(0xFFD97706)));
    } else {
      out.add(('PAID', const Color(0xFF16A34A)));
    }
    final retInv = 'r-${_billNumber(t)}'.toLowerCase();
    var returned = false, exchanged = false;
    for (final r in all) {
      if ((r.invoiceNumber ?? '').toLowerCase() != retInv) continue;
      returned = true;
      if (r.items.any((i) => i.quantity > 0)) exchanged = true;
    }
    if (exchanged) out.add(('EXCHANGED', const Color(0xFF2563EB)));
    if (returned && !exchanged) out.add(('RETURNED', const Color(0xFFDC2626)));
    return out;
  }

  /// Small pill used by [_billBadges].
  Widget _badgeChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w800, color: color)),
      );

  /// Indian-style comma grouping: 1234567.5 → "12,34,567.50".
  String _inr(double v) {
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    var intPart = parts[0];
    String grouped;
    if (intPart.length <= 3) {
      grouped = intPart;
    } else {
      final last3 = intPart.substring(intPart.length - 3);
      var rest = intPart.substring(0, intPart.length - 3);
      final buf = <String>[];
      while (rest.length > 2) {
        buf.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) buf.insert(0, rest);
      grouped = '${buf.join(',')},$last3';
    }
    return '${neg ? '-' : ''}$grouped.${parts[1]}';
  }

  /// Display number a bill is known by (matches what receipts print).
  String _billNumber(TransactionRecord t) => billNo(t);

  /// Quantity of [item] already returned against [original] in [all].
  int _alreadyReturned(List<TransactionRecord> all, TransactionRecord original,
      TransactionItem item) {
    final retInv = 'R-${_billNumber(original)}'.toLowerCase();
    var n = 0;
    for (final t in all) {
      if ((t.invoiceNumber ?? '').toLowerCase() != retInv) continue;
      for (final it in t.items) {
        if (it.quantity >= 0) continue;
        // Products are identified by id; two different products can share a
        // name, and matching on name alone made them block each other.
        final sameLine = item.productId.isNotEmpty
            ? (it.productId == item.productId &&
                it.variantId == item.variantId)
            : (it.productName == item.productName &&
                it.variantId == item.variantId);
        if (sameLine) n += -it.quantity;
      }
    }
    return n;
  }

  Future<void> _showReturnExchangeDialog() async {
    final all = await LocalDbService.getTransactions();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    final scanCtrl = TextEditingController();
    final custNameCtrl = TextEditingController();
    final custPhoneCtrl = TextEditingController();
    final scanFocus = FocusNode();
    double creditSettled = 0;
    var topUpMethod = 'cash'; // how a COLLECT difference was paid
    TransactionRecord? bill;
    String? error;
    final returnQty = <int, int>{}; // item index in bill -> qty coming back
    final exchange = <_QuoteLine>[]; // replacement items (name locked)
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        // ── money math ──
        final b = bill;
        double refund = 0, refundTax = 0;
        if (b != null) {
          final discountFactor =
              b.subtotal > 0 ? 1 - (b.discountAmount / b.subtotal) : 1.0;
          final taxRate = b.subtotal - b.discountAmount > 0
              ? b.taxAmount / (b.subtotal - b.discountAmount)
              : 0.0;
          for (var i = 0; i < b.items.length; i++) {
            final qty = returnQty[i] ?? 0;
            if (qty == 0) continue;
            final net = b.items[i].price * discountFactor * qty;
            refund += net;
            refundTax += net * taxRate;
          }
        }
        final currentRate = (double.tryParse(_taxRateDisplay) ?? 0) / 100;
        double exchangeVal = 0;
        for (final l in exchange) {
          exchangeVal += l.total;
        }
        final exchangeTax = exchangeVal * currentRate;
        final net = (exchangeVal + exchangeTax) - (refund + refundTax);
        final anyReturn = returnQty.values.any((v) => v > 0);
        final canConfirm = b != null && (anyReturn || exchange.isNotEmpty);

        Future<void> confirm({required String action}) async {
          if (b == null || saving) return;
          setLocal(() => saving = true);
          final discountFactor =
              b.subtotal > 0 ? 1 - (b.discountAmount / b.subtotal) : 1.0;
          final items = <TransactionItem>[];
          for (var i = 0; i < b.items.length; i++) {
            final qty = returnQty[i] ?? 0;
            if (qty == 0) continue;
            final src = b.items[i];
            items.add(TransactionItem(
              productId: src.productId,
              productName: src.productName,
              // Keep the exact discounted unit price: rounding it here and
              // then multiplying by qty drifted from the total shown on
              // screen (up to a rupee on large lines).
              price: src.price * discountFactor,
              quantity: -qty,
              variantId: src.variantId,
            ));
          }
          for (final l in exchange) {
            if (l.qty <= 0) continue;
            items.add(TransactionItem(
              productId: l.productId ?? '',
              productName: l.name.text.trim(),
              price: l.priceValue,
              quantity: l.qty,
              variantId: l.variantIdRef,
            ));
          }
          final subtotal = items.fold(0.0, (s, i) => s + i.price * i.quantity);
          final tax = exchangeTax - refundTax;
          final tx = TransactionRecord(
            id: const Uuid().v4(),
            invoiceNumber: 'R-${_billNumber(b)}',
            customerName: custNameCtrl.text.trim().isEmpty
                ? b.customerName
                : custNameCtrl.text.trim(),
            customerPhone: custPhoneCtrl.text.trim().isEmpty
                ? b.customerPhone
                : custPhoneCtrl.text.trim(),
            items: items,
            subtotal: double.parse(subtotal.toStringAsFixed(2)),
            discountAmount: 0,
            taxAmount: double.parse(tax.toStringAsFixed(2)),
            total: double.parse((subtotal + tax).toStringAsFixed(2)),
            // 'refund' when money goes out; a collected top-up is a sale of
            // the difference, so it carries the method it was paid with.
            paymentMethod: net > 0 ? 'exchange-$topUpMethod' : 'refund',
            createdAt: DateTime.now(),
          );
          try {
            await LocalDbService.insertReturnTransaction(tx);
            // If this customer owes money (udhaar), a refund should clear the
            // due first instead of paying cash out over an unpaid balance.
            final phone = (custPhoneCtrl.text.trim().isNotEmpty
                    ? custPhoneCtrl.text.trim()
                    : b.customerPhone) ??
                '';
            if (net < 0 && phone.isNotEmpty) {
              final owed = await LocalDbService.creditBalanceForPhone(phone);
              if (owed > 0) {
                final settle = owed < -net ? owed : -net;
                await LocalDbService.addCreditToCustomer(phone, -settle);
                creditSettled = settle;
              }
            }
          } catch (e) {
            // Never leave the dialog stuck on "Saving...": re-enable the
            // buttons and tell the operator, so the return can be retried.
            setLocal(() {
              saving = false;
              error = 'Could not save this return: $e';
            });
            return;
          }
          ConnectivityService.instance.syncNow();
          if (ctx.mounted) Navigator.pop(ctx);
          _loadProducts();
          _loadDashboardData();
          _showToast(net < 0
              ? (creditSettled > 0
                  ? 'Return recorded — $_currencySymbol${_inr(creditSettled)} '
                      'settled against dues, pay '
                      '$_currencySymbol${_inr(-net - creditSettled)}'
                  : 'Return recorded — refund $_currencySymbol${_inr(-net)}')
              : 'Exchange recorded — collect $_currencySymbol${net.toStringAsFixed(2)}');
          if (action == 'close') return; // recorded only, no document
          if (action == 'print') {
            await _printRecord(tx, docType: 'Return', toPrinter: true);
          } else {
            // E-BILL: share the return note as a PDF (WhatsApp/Mail/AirDrop).
            try {
              final bytes = await ReceiptPrinter.buildPdf(
                tx,
                storeName: _storeName, storeAddress: _storeAddress,
                storePhone: _storePhone, storeEmail: _storeEmail,
                storeGstin: _storeGstin, receiptFooter: _receiptFooter,
                taxLabel: _taxLabel, taxRate: _taxRateDisplay,
                currencySymbol: _currencySymbol, paperSize: _paperSize,
                orientation: _printOrientation, layout: _invoiceLayout,
                storeTerms: _storeTerms, logoPath: _logoPath,
                storeUpiId: _storeUpiId, docType: 'Return',
              );
              await Printing.sharePdf(
                  bytes: bytes,
                  filename: 'Return-${tx.invoiceNumber ?? 'note'}.pdf');
            } catch (e) {
              if (mounted) {
                _showToast('Could not create e-bill: $e', isError: true);
              }
            }
          }
        }

        void addExchange(Product p, ProductVariant? v) {
          final avail = v?.stock ?? p.stock;
          if (avail <= 0) {
            _showToast('${v == null ? p.name : '${p.name} · ${v.name}'} is out '
                'of stock — exchange recorded anyway', isError: true);
          }
          setLocal(() => exchange.add(_QuoteLine(
                initialName: v == null ? p.name : '${p.name} · ${v.name}',
                initialPrice: (v?.price ?? p.price).toStringAsFixed(2),
              )
                ..productId = p.id
                ..variantIdRef = v?.id));
        }

        // Barcode scanners type the code and press Enter — exact barcode
        // match adds instantly; a unique name match adds too; anything
        // ambiguous opens the picker pre-filtered by hand.
        void scanAdd(String raw) {
          final s = raw.trim().toLowerCase();
          scanCtrl.clear();
          if (s.isEmpty) return;
          for (final p in _products) {
            if (p.barcodeNo.toLowerCase() == s) {
              // Variant products carry stock/price per variant: adding the
              // base product would price it wrongly and move the wrong stock.
              if (p.variants.isNotEmpty) {
                _pickProductForReturn(ctx, addExchange);
                return;
              }
              addExchange(p, null);
              return;
            }
            for (final v in p.variants) {
              if (v.barcodeNo.toLowerCase() == s) {
                addExchange(p, v);
                return;
              }
            }
          }
          final byName = _products
              .where((p) => p.name.toLowerCase().contains(s))
              .toList();
          if (byName.length == 1 && byName.first.variants.isEmpty) {
            addExchange(byName.first, null);
            return;
          }
          _pickProductForReturn(ctx, addExchange);
        }

        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: 560,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.assignment_return_outlined,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          b == null
                              ? 'Return / Exchange'
                              : 'Return / Exchange — #${_billNumber(b)}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    if (b != null)
                      TextButton(
                        onPressed: () => setLocal(() {
                          bill = null;
                          returnQty.clear();
                        }),
                        child: Text('Change bill',
                            style: GoogleFonts.inter(fontSize: 12)),
                      ),
                    IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 12),
                  // ── bill picker: search or browse recent bills ──
                  if (b == null) ...[
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: GoogleFonts.inter(fontSize: 13),
                      onChanged: (_) => setLocal(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search invoice, customer, phone or item...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Builder(builder: (_) {
                      final q = searchCtrl.text
                          .trim()
                          .replaceAll('#', '')
                          .toLowerCase();
                      // Every document is listed — sales plus the return /
                      // exchange records themselves — so the history is
                      // complete. Tapping a return jumps to the bill it came
                      // from.
                      final sales = all.where((t) {
                        if (q.isEmpty) return true;
                        if ((t.invoiceNumber ?? '')
                            .toLowerCase()
                            .contains(q)) {
                          return true;
                        }
                        if (t.id
                            .replaceAll('-', '')
                            .toLowerCase()
                            .startsWith(q)) {
                          return true;
                        }
                        if ((t.customerName ?? '')
                            .toLowerCase()
                            .contains(q)) {
                          return true;
                        }
                        if ((t.customerPhone ?? '').contains(q)) return true;
                        return t.items.any((i) =>
                            i.productName.toLowerCase().contains(q));
                      }).take(30).toList();
                      if (sales.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No matching bills',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.textMuted)),
                        );
                      }
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 340),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sales.length,
                          itemBuilder: (_, i) {
                            final t = sales[i];
                            return InkWell(
                              onTap: () {
                                final inv = t.invoiceNumber ?? '';
                                // A pure refund can't be returned again, so
                                // it redirects to its original bill. An
                                // EXCHANGE document handed goods to the
                                // customer, so it must be openable itself.
                                final hasOutgoing =
                                    t.items.any((i) => i.quantity > 0);
                                final isReturnDoc = !hasOutgoing &&
                                    (t.paymentMethod.toLowerCase() == 'refund' ||
                                        inv.startsWith('R-'));
                                // A return document can't itself be returned:
                                // open the original bill it was raised against.
                                TransactionRecord? target = t;
                                if (isReturnDoc) {
                                  final origNo =
                                      inv.replaceFirst('R-', '').toLowerCase();
                                  target = null;
                                  for (final o in all) {
                                    if (billNo(o).toLowerCase() == origNo) {
                                      target = o;
                                      break;
                                    }
                                  }
                                  if (target == null) {
                                    _showToast(
                                        'Original bill for this return is not '
                                        'on this device',
                                        isError: true);
                                    return;
                                  }
                                }
                                setLocal(() {
                                  bill = target;
                                  returnQty.clear();
                                  // Exchange lines belong to the bill they
                                  // were added against — never carry them
                                  // onto a different customer's bill.
                                  for (final l in exchange) {
                                    final d = l;
                                    Future.delayed(
                                        const Duration(milliseconds: 400),
                                        d.dispose);
                                  }
                                  exchange.clear();
                                  scanCtrl.clear();
                                  error = null;
                                  custNameCtrl.text = target!.customerName ?? '';
                                  custPhoneCtrl.text = target.customerPhone ?? '';
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 9),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('#${_billNumber(t)}',
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                            '${_fmtDate(t.createdAt)} · ${t.items.length} item${t.items.length == 1 ? '' : 's'}'
                                            '${(t.customerName ?? '').isNotEmpty ? ' · ${t.customerName}' : ''}',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.textMuted)),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 5,
                                          runSpacing: 4,
                                          children: [
                                            for (final badge
                                                in _billBadges(all, t))
                                              _badgeChip(badge.$1, badge.$2),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                      '$_currencySymbol${_inr(t.total)}',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: t.total < 0
                                              ? const Color(0xFFDC2626)
                                              : AppColors.textDark)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 16, color: AppColors.textMuted),
                                ]),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.red)),
                    ),
                  if (b != null) ...[
                    const SizedBox(height: 14),
                    Text('Bill #${_billNumber(b)} · ${_fmtDate(b.createdAt)}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    // Customer details — prefilled from the bill, editable
                    // (walk-in sales often have no name on the original).
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: custNameCtrl,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Customer name',
                            prefixIcon:
                                const Icon(Icons.person_outline, size: 16),
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 190,
                        child: TextField(
                          controller: custPhoneCtrl,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Phone',
                            prefixIcon:
                                const Icon(Icons.phone_outlined, size: 16),
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    // ── returned items ──
                    Text('ITEMS ON THIS BILL',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 230),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (var i = 0; i < b.items.length; i++)
                              Builder(builder: (_) {
                                final it = b.items[i];
                                final maxQty = it.quantity -
                                    _alreadyReturned(all, b, it);
                                final sel = returnQty[i] ?? 0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 8, 8, 8),
                                  decoration: BoxDecoration(
                                    color: sel > 0
                                        ? const Color(0xFFFEF2F2)
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: sel > 0
                                            ? const Color(0xFFFECACA)
                                            : AppColors.border),
                                  ),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(it.productName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text(
                                              '${fmtMoney(_currencySymbol, it.price)} × ${it.quantity}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                    if (maxQty <= 0)
                                      Text('already returned',
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textMuted))
                                    else ...[
                                      if (sel > 0) ...[
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 16),
                                          color: Colors.red,
                                          onPressed: () => setLocal(
                                              () => returnQty[i] = sel - 1),
                                        ),
                                        Text('$sel/$maxQty',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.red)),
                                        const SizedBox(width: 6),
                                      ],
                                      OutlinedButton(
                                        onPressed: sel < maxQty
                                            ? () => setLocal(() =>
                                                returnQty[i] = sel + 1)
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          visualDensity:
                                              VisualDensity.compact,
                                          side: const BorderSide(
                                              color: AppColors.border),
                                        ),
                                        child: Text('RETURN',
                                            style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w800)),
                                      ),
                                      const SizedBox(width: 6),
                                      OutlinedButton(
                                        // Marks the item as coming back and
                                        // jumps to the scan box so the
                                        // replacement can be scanned straight
                                        // away — no extra popup.
                                        onPressed: sel < maxQty
                                            ? () {
                                                setLocal(() =>
                                                    returnQty[i] = sel + 1);
                                                scanFocus.requestFocus();
                                              }
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          visualDensity:
                                              VisualDensity.compact,
                                          side: const BorderSide(
                                              color: AppColors.border),
                                        ),
                                        child: Text('EXCHANGE',
                                            style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w800)),
                                      ),
                                    ],
                                  ]),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('EXCHANGE WITH',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    // ── exchange items: scan or search to add ──
                    TextField(
                      controller: scanCtrl,
                      focusNode: scanFocus,
                      onSubmitted: scanAdd,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Scan barcode or search a product to add...',
                        prefixIcon:
                            const Icon(Icons.qr_code_scanner, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          tooltip: 'Browse products',
                          onPressed: () =>
                              _pickProductForReturn(ctx, addExchange),
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    for (var i = 0; i < exchange.length; i++)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(children: [
                        Expanded(
                            child: Text(exchange[i].name.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600))),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 18),
                          onPressed: exchange[i].qty > 1
                              ? () => setLocal(() => exchange[i].qty--)
                              : null,
                        ),
                        Text('${exchange[i].qty}',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        IconButton(
                          icon:
                              const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: () => setLocal(() => exchange[i].qty++),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                              '$_currencySymbol${_inr(exchange[i].total)}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(fontSize: 13)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 15),
                          onPressed: () => setLocal(() {
                            final l = exchange.removeAt(i);
                            Future.delayed(
                                const Duration(milliseconds: 400), l.dispose);
                          }),
                        ),
                      ])),
                    const SizedBox(height: 14),
                    // ── summary ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                    Row(children: [
                      Text('OLD BILL AMOUNT',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted)),
                      const Spacer(),
                      Text('$_currencySymbol${_inr(b.total)}',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                    if (anyReturn)
                      Row(children: [
                        Text('RETURNING NOW',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted)),
                        const Spacer(),
                        Text(
                            '-$_currencySymbol${_inr(refund + refundTax)}',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red)),
                      ]),
                    if (exchange.isNotEmpty)
                      Row(children: [
                        Text('NEW ITEMS',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted)),
                        const Spacer(),
                        Text(
                            '$_currencySymbol${_inr(exchangeVal + exchangeTax)}',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(
                          net < 0
                              ? 'REFUND TO CUSTOMER'
                              : 'COLLECT FROM CUSTOMER',
                          style: GoogleFonts.manrope(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text(
                          '$_currencySymbol${_inr(net.abs())}',
                          style: GoogleFonts.manrope(
                              fontSize: 17, fontWeight: FontWeight.w800,
                              color: net < 0
                                  ? Colors.red
                                  : AppColors.primary)),
                    ]),
                    ]),
                    ),
                    if (net > 0) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Text('PAID BY',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.textMuted)),
                        const SizedBox(width: 10),
                        for (final m in const ['cash', 'card', 'upi'])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(m.toUpperCase(),
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                              selected: topUpMethod == m,
                              onSelected: (_) =>
                                  setLocal(() => topUpMethod = m),
                            ),
                          ),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canConfirm && !saving
                              ? () => confirm(action: 'print')
                              : null,
                          icon: const Icon(Icons.print_outlined, size: 16),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          label: Text(saving ? 'Saving...' : 'PRINT RECEIPT',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: canConfirm && !saving
                              ? () => confirm(action: 'ebill')
                              : null,
                          icon: const Icon(Icons.ios_share_outlined,
                              size: 16),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          label: Text('E-BILL',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canConfirm && !saving
                            ? () => confirm(action: 'close')
                            : null,
                        icon: const Icon(Icons.check_circle_outline, size: 17),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        label: Text('CLOSE BILL',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
    // The dialog route keeps animating out briefly after the future
    // resolves — disposing controllers immediately crashes that last frame.
    await Future.delayed(const Duration(milliseconds: 400));
    searchCtrl.dispose();
    scanCtrl.dispose();
    custNameCtrl.dispose();
    custPhoneCtrl.dispose();
    scanFocus.dispose();
    for (final l in exchange) {
      l.dispose();
    }
  }

  /// Product (and variant) picker for the exchange list.
  void _pickProductForReturn(BuildContext parentCtx,
      void Function(Product, ProductVariant?) onPick) {
    if (_products.isEmpty) {
      _showToast('No products in inventory to exchange with', isError: true);
      return;
    }
    String query = '';
    // useRootNavigator: false keeps this picker inside the same navigator as
    // the Return/Exchange dialog it opens from, so it reliably appears above
    // it instead of being swallowed by the root route.
    showDialog(
      context: parentCtx,
      useRootNavigator: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final list = _products
            .where(
                (p) => p.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 420,
            height: 460,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setLocal(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final variants = p.variants;
                    if (variants.isEmpty) {
                      return ListTile(
                        dense: true,
                        title: Text(p.name,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        trailing: Text(
                            fmtMoney(_currencySymbol, p.price),
                            style: GoogleFonts.inter(fontSize: 13)),
                        onTap: () {
                          Navigator.pop(ctx);
                          onPick(p, null);
                        },
                      );
                    }
                    return ExpansionTile(
                      dense: true,
                      title: Text(p.name,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      children: [
                        for (final v in variants)
                          ListTile(
                            dense: true,
                            title: Text(v.name,
                                style: GoogleFonts.inter(fontSize: 12)),
                            trailing: Text(
                                fmtMoney(_currencySymbol, v.price),
                                style: GoogleFonts.inter(fontSize: 12)),
                            onTap: () {
                              Navigator.pop(ctx);
                              onPick(p, v);
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _navTab(String label, int index) {
    final selected = _selectedTab == index;
    return _NavHoverTab(
      selected: selected,
      onTap: () {
        setState(() => _selectedTab = index);
        // Returning to Billing → focus the scan bar so scanning works instantly.
        if (index == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedTab == 1 && !_showSettings) _searchFocus.requestFocus();
          });
        }
      },
      label: label,
    );
  }

  Widget _reportsDropdownTab() {
    final selected = _selectedTab == 3;
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      elevation: 4,
      onSelected: (value) {
        setState(() {
          _selectedTab = 3;
          _reportView = value;
        });
        if (value == 'Customers') _loadReportCustomers();
        if (value == 'Dealers') _loadReportDealers();
      },
      itemBuilder: (_) => [
        'Sales', 'Customers', 'Dealers', 'Inventory',
      ].map((v) => PopupMenuItem<String>(
        value: v,
        height: 40,
        child: Row(
          children: [
            Icon(
              switch (v) {
                'Sales'     => Icons.bar_chart_rounded,
                'Customers' => Icons.people_alt_outlined,
                'Dealers'   => Icons.local_shipping_outlined,
                _           => Icons.inventory_2_outlined,
              },
              size: 16,
              color: (selected && _reportView == v) ? AppColors.accentBlue : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Text(v, style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: (selected && _reportView == v) ? FontWeight.w700 : FontWeight.w500,
              color: (selected && _reportView == v) ? AppColors.accentBlue : AppColors.textDark,
            )),
          ],
        ),
      )).toList(),
      child: _DropdownNavHover(
        selected: selected,
        label: selected ? _reportView : 'Reports',
      ),
    );
  }

  Widget _utilitiesDropdownTab() {
    final selected = _selectedTab == 4;
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      elevation: 4,
      onSelected: (value) {
        setState(() {
          _selectedTab = 4;
          _utilitiesView = value;
        });
      },
      itemBuilder: (_) => [
        'Quotation',
      ].map((v) => PopupMenuItem<String>(
        value: v,
        height: 40,
        child: Row(children: [
          Icon(
            switch (v) {
              'Quotation' => Icons.request_quote_outlined,
              _           => Icons.build_outlined,
            },
            size: 16,
            color: (selected && _utilitiesView == v) ? AppColors.accentBlue : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Text(v, style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: (selected && _utilitiesView == v) ? FontWeight.w700 : FontWeight.w500,
            color: (selected && _utilitiesView == v) ? AppColors.accentBlue : AppColors.textDark,
          )),
        ]),
      )).toList(),
      child: _DropdownNavHover(
        selected: selected,
        label: selected ? _utilitiesView : 'Utilities',
      ),
    );
  }

  // ── Left Panel ───────────────────────────────────────────────────────────────

  Widget _buildLeftPanel() {
    return Expanded(
      flex: 62,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            _HoverShadowBox(
              borderRadius: 14,
              child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: AppColors.cardShadow, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      autofocus: true,
                      onChanged: (v) {
                        setState(() => _searchQuery = v);
                        // Auto-add on exact barcode/SKU match (barcode scanner hit)
                        final query = v.trim();
                        if (query.isNotEmpty) {
                          final match = _products.cast<Product?>().firstWhere(
                            (p) => _barcodeMatches(p!.barcodeNo, query) || p.sku.toLowerCase() == query.toLowerCase(), orElse: () => null);
                          if (match != null) {
                            context.read<CartProvider>().addProduct(match);
                            setState(() { _searchQuery = ''; _searchController.clear(); });
                            _showToast('${match.name} added to cart');
                            _searchFocus.unfocus();
                          }
                        }
                      },
                      onSubmitted: (v) {
                        final query = v.trim();
                        if (query.isEmpty) return;
                        // Barcode no match first, then SKU, then name, then partial SKU
                        Product? match = _products.cast<Product?>().firstWhere(
                          (p) => _barcodeMatches(p!.barcodeNo, query), orElse: () => null);
                        match ??= _products.cast<Product?>().firstWhere(
                          (p) => p!.sku.toLowerCase() == query.toLowerCase(), orElse: () => null);
                        match ??= _products.cast<Product?>().firstWhere(
                          (p) => p!.name.toLowerCase() == query.toLowerCase(), orElse: () => null);
                        match ??= _products.cast<Product?>().firstWhere(
                          (p) => p!.sku.toLowerCase().contains(query.toLowerCase()), orElse: () => null);
                        if (match != null) {
                          context.read<CartProvider>().addProduct(match);
                          setState(() { _searchQuery = ''; _searchController.clear(); });
                          _showToast('${match.name} added to cart');
                          _searchFocus.requestFocus(); // keep focus for the next scan
                        } else {
                          _showToast('No product found for "$query"', isError: true);
                        }
                      },
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Scan or type item name...',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                      ),
                    ),
                  ] else
                    const SizedBox(width: 16),
                ],
              ),
            ),
            ), // _HoverShadowBox
            const SizedBox(height: 20),
            // Category chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', ..._userCategories.where((c) => _products.any((p) => p.category == c))].map((cat) {
                  final selected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _CategoryChip(
                      label: cat,
                      selected: selected,
                      onTap: () => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Product grid
            Expanded(
              child: Consumer<CartProvider>(
                builder: (context, cart, _) {
                  final controller = ScrollController();
                  return Scrollbar(
                    controller: controller,
                    thickness: 4,
                    radius: const Radius.circular(4),
                    thumbVisibility: false,
                    child: GridView.builder(
                      controller: controller,
                      padding: const EdgeInsets.only(right: 8),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: _displayGridItems.length,
                      itemBuilder: (_, i) {
                        final item = _displayGridItems[i];
                        if (item is Product) {
                          return _ProductCard(
                            product: item,
                            onTap: () => _onProductTap(cart, item),
                            currencySymbol: _currencySymbol,
                            variantsExpanded: _expandedVariantProductId == item.id,
                            onVariantArrowTap: () => setState(() {
                              _expandedVariantProductId =
                                  _expandedVariantProductId == item.id ? null : item.id;
                            }),
                          );
                        }
                        final pair = item as (Product, ProductVariant);
                        return _VariantCard(
                          product: pair.$1,
                          variant: pair.$2,
                          currencySymbol: _currencySymbol,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A product with variants expands its variant cards inline in the grid;
  // a plain product is added straight to the cart.
  void _onProductTap(CartProvider cart, Product product) {
    if (product.hasVariants) {
      setState(() {
        _expandedVariantProductId =
            _expandedVariantProductId == product.id ? null : product.id;
      });
    } else {
      cart.addProduct(product);
    }
  }

  // ── Right Panel ──────────────────────────────────────────────────────────────

  Widget _buildResizeDivider() {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _rightPanelWidth =
              (_rightPanelWidth - details.delta.dx).clamp(375.0, 580.0);
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(width: 1, color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      width: _rightPanelWidth,
      color: Colors.white,
      child: Consumer<CartProvider>(
        builder: (context, cart, _) => Column(
          children: [
            _buildCustomerBar(cart),
            _buildCartTable(cart),
            _buildSummary(cart),
            _buildPaymentMethods(cart),
            _buildActionButtons(context, cart),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerBar(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Customer Name with autocomplete
          Expanded(
            flex: 1,
            child: _customerAutocomplete(
              controller: _customerNameCtrl,
              focusNode: _customerNameFocus,
              icon: Icons.person_outline_rounded,
              hint: 'Customer Name',
              filterFn: (c, q) => c.name.toLowerCase().contains(q.toLowerCase()),
              displayFn: (c) => c.name,
              onChanged: (v) { cart.customerName = v; setState(() {}); },
              textInputAction: TextInputAction.next,
              onOptionsChanged: (opts) => _nameAcOptions = opts,
              currentOptions: _nameAcOptions,
              onFieldSubmitted: () => _customerPhoneFocus.requestFocus(),
              onSelected: (c) {
                _customerNameCtrl.text = c.name;
                _customerPhoneCtrl.text = c.phone ?? '';
                cart.customerName = c.name;
                cart.customerPhone = c.phone ?? '';
                setState(() {});
                if (!_acSkipRefocus) Future.microtask(() => _customerNameFocus.requestFocus());
                _acSkipRefocus = false;
              },
            ),
          ),
          const SizedBox(width: 10),
          // Phone with autocomplete
          Expanded(
            flex: 1,
            child: _customerAutocomplete(
              controller: _customerPhoneCtrl,
              focusNode: _customerPhoneFocus,
              icon: Icons.phone_outlined,
              hint: 'Phone Number',
              filterFn: (c, q) => (c.phone ?? '').contains(q),
              displayFn: (c) => c.phone ?? '',
              onChanged: (v) { cart.customerPhone = v; setState(() {}); },
              onOptionsChanged: (opts) => _phoneAcOptions = opts,
              currentOptions: _phoneAcOptions,
              onSelected: (c) {
                _customerNameCtrl.text = c.name;
                _customerPhoneCtrl.text = c.phone ?? '';
                cart.customerName = c.name;
                cart.customerPhone = c.phone ?? '';
                setState(() {});
                if (!_acSkipRefocus) Future.microtask(() => _customerPhoneFocus.requestFocus());
                _acSkipRefocus = false;
              },
              keyboardType: TextInputType.phone,
              onFieldSubmitted: () {
                final name  = _customerNameCtrl.text.trim();
                final phone = _customerPhoneCtrl.text.trim();
                final hasData = name.isNotEmpty || phone.isNotEmpty;
                if (hasData) {
                  final isSaved = _savedCustomers.any((c) =>
                    (name.isNotEmpty && c.name.toLowerCase() == name.toLowerCase()) ||
                    (phone.isNotEmpty && (c.phone ?? '') == phone));
                  if (!isSaved) {
                    _customerPhoneFocus.unfocus();
                    _showAddCustomerDialog(cart);
                    return;
                  }
                }
                _addCustomerFocus.requestFocus();
              },
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
            listenable: Listenable.merge([_customerNameCtrl, _customerPhoneCtrl]),
            builder: (context, _) {
              final name  = _customerNameCtrl.text.trim();
              final phone = _customerPhoneCtrl.text.trim();
              final hasData = name.isNotEmpty || phone.isNotEmpty;

              if (hasData) {
                final isSaved = _savedCustomers.any((c) =>
                  (name.isNotEmpty && c.name.toLowerCase() == name.toLowerCase()) ||
                  (phone.isNotEmpty && (c.phone ?? '') == phone));

                if (isSaved) {
                  // saved customer → subtle clear-customer button
                  return Tooltip(
                    message: 'Clear customer',
                    child: GestureDetector(
                      onTap: () {
                        _customerNameCtrl.clear();
                        _customerPhoneCtrl.clear();
                        cart.customerName = '';
                        cart.customerPhone = '';
                        setState(() {});
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_remove_outlined, color: AppColors.textMuted, size: 18),
                      ),
                    ),
                  );
                } else {
                  // new customer → dark add-person button that saves directly
                  return GestureDetector(
                    onTap: () async {
                      if (name.isEmpty) return;
                      await LocalDbService.upsertCustomerByPhone(
                        name: name,
                        phone: phone.isEmpty ? null : phone,
                      );
                      cart.customerName = name;
                      cart.customerPhone = phone;
                      await _loadSavedCustomers();
                      if (ConnectivityService.instance.isOnline) {
                        ConnectivityService.instance.syncNow();
                      }
                      if (mounted) _showToast('Customer saved!');
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                    ),
                  );
                }
              }

              return Focus(
                focusNode: _addCustomerFocus,
                child: GestureDetector(
                  onTap: () => _showAddCustomerDialog(cart),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _customerAutocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    required bool Function(Customer, String) filterFn,
    required String Function(Customer) displayFn,
    required ValueChanged<String> onChanged,
    required ValueChanged<Customer> onSelected,
    required void Function(List<Customer>) onOptionsChanged,
    required List<Customer> currentOptions,
    TextInputType? keyboardType,
    VoidCallback? onFieldSubmitted,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return RawAutocomplete<Customer>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (v) {
        if (v.text.trim().isEmpty) { onOptionsChanged([]); return const []; }
        final opts = _savedCustomers.where((c) => filterFn(c, v.text)).take(6).toList();
        onOptionsChanged(opts);
        return opts;
      },
      displayStringForOption: displayFn,
      onSelected: onSelected,
      fieldViewBuilder: (context, textCtrl, fn, onSubmit) {
        return Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 10),
              Icon(icon, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 7),
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  focusNode: fn,
                  onChanged: onChanged,
                  textInputAction: textInputAction ?? TextInputAction.done,
                  onSubmitted: (_) {
                    if (currentOptions.isNotEmpty) {
                      final first = currentOptions.first;
                      _acSkipRefocus = true;
                      onOptionsChanged([]);
                      fn.unfocus();
                      onSelected(first);
                    } else {
                      onSubmit();
                      onFieldSubmitted?.call();
                    }
                  },
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
      optionsViewBuilder: (context, onSel, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final c = options.elementAt(i);
                final isFirst = i == 0;
                return InkWell(
                  onTap: () => onSel(c),
                  child: Container(
                    color: isFirst ? AppColors.primary.withValues(alpha: 0.07) : null,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.person_outline_rounded, size: 14,
                          color: isFirst ? AppColors.primary : AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: GoogleFonts.inter(fontSize: 12,
                            fontWeight: isFirst ? FontWeight.w700 : FontWeight.w600,
                            color: isFirst ? AppColors.primary : AppColors.textDark)),
                        if (c.phone != null && c.phone!.isNotEmpty)
                          Text(c.phone!, style: GoogleFonts.inter(fontSize: 11,
                              color: isFirst ? AppColors.primary.withValues(alpha: 0.7) : AppColors.textMuted)),
                      ])),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerField({
    required IconData icon,
    required String hint,
    required Function(String) onChanged,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
              color: AppColors.textMuted.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w300),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCartTable(CartProvider cart) {
    return Expanded(
      child: ClipRect(child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
            color: AppColors.surfaceVariant,
            child: Row(
              children: [
                Expanded(
                    child: Text('DESCRIPTION',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1.5))),
                SizedBox(
                    width: 90,
                    child: Text('QTY',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1.5))),
                SizedBox(
                    width: 90,
                    child: Text('AMOUNT',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1.5))),
                const SizedBox(width: 28),
              ],
            ),
          ),
          // Cart items
          Expanded(
            child: (cart.items.isEmpty && !_addingCustomProduct)
                ? Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.border),
                          const SizedBox(height: 8),
                          Text('No items added', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () { setState(() { _addingCustomProduct = true; _customQty = 1; _customNameCtrl.clear(); _customPriceCtrl.clear(); }); Future.microtask(() => _customNameFocus.requestFocus()); },
                            icon: const Icon(Icons.add_rounded, size: 15),
                            label: Text('Custom Product', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              side: const BorderSide(color: AppColors.border),
                              foregroundColor: AppColors.textDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: cart.items.length + 1,
                    separatorBuilder: (_, i) => i < cart.items.length - 1
                        ? const Divider(height: 1, thickness: 0.5, color: AppColors.border, indent: 8, endIndent: 8)
                        : const SizedBox.shrink(),
                    itemBuilder: (_, i) {
                      if (i == cart.items.length) {
                        return _addingCustomProduct
                            ? _buildInlineCustomRow(cart)
                            : _addCustomProductBtn(cart);
                      }
                      return _CartRow(
                          key: ValueKey(cart.items[i].lineId),
                          item: cart.items[i], cart: cart, currencySymbol: _currencySymbol);
                    },
                  ),
          ),
        ],
      )),
    );
  }

  Widget _addCustomProductBtn(CartProvider cart) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: OutlinedButton.icon(
        onPressed: () { setState(() { _addingCustomProduct = true; _customQty = 1; _customNameCtrl.clear(); _customPriceCtrl.clear(); }); Future.microtask(() => _customNameFocus.requestFocus()); },
        icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
        label: Text('CUSTOM PRODUCT',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.8)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 46),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildInlineCustomRow(CartProvider cart) {
    void confirm() {
      final name = _customNameCtrl.text.trim();
      final price = double.tryParse(_customPriceCtrl.text) ?? 0;
      if (name.isNotEmpty && price > 0) {
        final product = Product(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name, price: price,
          category: 'Custom', emoji: '📦', sku: 'CUSTOM', stock: 99,
        );
        for (int i = 0; i < _customQty; i++) cart.addProduct(product);
        setState(() => _addingCustomProduct = false);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Name field (no SKU line)
          Expanded(
            child: TextField(
              controller: _customNameCtrl,
              focusNode: _customNameFocus,
              maxLines: 1,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              decoration: InputDecoration.collapsed(
                hintText: 'Item name',
                hintStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              onSubmitted: (_) => Future.microtask(() => _customPriceFocus.requestFocus()),
            ),
          ),
          const SizedBox(width: 8),
          // Qty controls
          Container(
            width: 90,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () { if (_customQty > 1) setState(() => _customQty--); },
                  child: Container(
                    width: 22, height: 22,
                    alignment: Alignment.center,
                    child: Icon(Icons.remove, size: 14,
                        color: _customQty > 1 ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.3)),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$_customQty', textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _customQty++),
                  child: Container(
                    width: 22, height: 22,
                    alignment: Alignment.center,
                    child: Icon(Icons.add, size: 14, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Price field
          SizedBox(
            width: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _customPriceCtrl,
                  focusNode: _customPriceFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  decoration: InputDecoration.collapsed(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                  onSubmitted: (_) => confirm(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: confirm,
            child: Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _addingCustomProduct = false),
            child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 20,
              offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          _summaryRow('SUBTOTAL', cart.subtotal),
          const SizedBox(height: 10),
          // Discount row
          Row(
            children: [
              Text('DISCOUNT',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      letterSpacing: 1.5)),
              const SizedBox(width: 10),
              _DiscountToggle(cart: cart, currencySymbol: _currencySymbol, focusNode: _discountFocus),
              const Spacer(),
              Text(
                  '-${_fmtComma(cart.discountAmount)}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          _summaryRow('TAX ($_taxLabel $_taxRateDisplay%)', cart.taxAmount),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL PAYABLE',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text(
                      _fmtComma(cart.total),
                      style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -1)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('${cart.itemCount} ITEMS',
                    style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: AppColors.textMuted, letterSpacing: 1.0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount) {
    return Row(
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 1.5)),
        const Spacer(),
        Text(_fmtComma(amount),
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
      ],
    );
  }

  Widget _buildPaymentMethods(CartProvider cart) {
    const methods = [
      (PaymentMethod.cash, 'Cash'),
      (PaymentMethod.card, 'Card'),
      (PaymentMethod.upi, 'UPI/QR'),
      (PaymentMethod.hybrid, 'Hybrid'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAYMENT METHOD',
              style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Row(
            spacing: 8,
            children: methods.map((m) {
              final selected = cart.paymentMethod == m.$1;
              return Expanded(child: GestureDetector(
                onTap: () => cart.setPaymentMethod(m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentBlue.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: selected
                            ? AppColors.accentBlue
                            : AppColors.border,
                        width: selected ? 2 : 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accentBlue
                              : Colors.transparent,
                          border: Border.all(
                              color: selected
                                  ? AppColors.accentBlue
                                  : AppColors.border,
                              width: 1.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(child: Text(m.$2.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              letterSpacing: 0.5,
                              color: selected
                                  ? AppColors.accentBlue
                                  : AppColors.textMuted))),
                    ],
                  ),
                ),
              ));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, CartProvider cart) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cart.items.isEmpty
                      ? null
                      : () => _confirmClear(context, cart),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text('CLEAR BILL',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (cart.items.isEmpty || _isPrinting) ? null : () => _showPrintBillDialog(cart),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: Text('PRINT BILL',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    disabledBackgroundColor: AppColors.border,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: cart.items.isEmpty
                  ? null
                  : () => _closeBill(context, cart),
              icon: const Icon(Icons.check_circle_outline_rounded,
                  size: 22),
              label: Text('Paid - Close Bill',
                  style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                disabledBackgroundColor: AppColors.border,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _bottomBarBtn(Icons.keyboard_outlined, 'SHORTCUTS'),
          const SizedBox(width: 4),
          _bottomBarBtn(Icons.inventory_2_outlined, 'INVENTORY',
              onPressed: () =>
                  setState(() => _selectedTab = 2)),
          const SizedBox(width: 4),
          _bottomBarBtn(Icons.receipt_outlined, 'LAST RECEIPT'),
          const Spacer(),
          Text(
              'INV: #${_queuedTransactionId.length >= 6 ? _queuedTransactionId.replaceAll('-', '').substring(0, 6).toUpperCase() : '------'}  •  SESSION: ${TimeOfDay.now().format(context)}  •  ${_sessionUserLabel()}',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _bottomBarBtn(IconData icon, String label,
      {VoidCallback? onPressed}) {
    return TextButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, size: 14, color: AppColors.textMuted),
      label: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
              letterSpacing: 0.8)),
      style: TextButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
      ),
    );
  }

  String _sessionUserLabel() {
    final email = SupabaseService.currentUser?.email ?? '';
    final local = email.split('@').first;
    final parts = local.split(RegExp(r'[._\-]'));
    if (parts.length >= 2) {
      return '${parts[0].toUpperCase()} ${parts[1][0].toUpperCase()}.';
    }
    return local.toUpperCase();
  }

  // ── Top bar helper ───────────────────────────────────────────────────────────

  Widget _topBarIconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.textMuted),
        ),
      ),
    );
  }

  // ── Profile menu ─────────────────────────────────────────────────────────────

  Widget _buildProfileMenu() {
    final user = SupabaseService.currentUser;
    final email = user?.email ?? 'user@example.com';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.white,
      onSelected: (value) {
        if (value == 'logout') _confirmLogout(context);
        if (value == 'profile') _showProfileDialog(email);
      },
      itemBuilder: (_) => [
        // Header — non-interactive user info
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initials,
                        style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Account',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      Text(email,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'profile',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Text('Profile',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'logout',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded,
                  size: 16, color: AppColors.error),
              const SizedBox(width: 10),
              Text('Logout',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error)),
            ],
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(initials,
              style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );
  }

  Future<String> _uploadLogoToCloud(String localPath) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return '';
      final bytes = await File(localPath).readAsBytes();
      final ext = localPath.split('.').last.toLowerCase();
      await client.storage.from('logos').uploadBinary(
        '$userId.$ext', bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final url = client.storage.from('logos').getPublicUrl('$userId.$ext');
      // Persist URL in auth user metadata so it syncs across devices
      await client.auth.updateUser(UserAttributes(data: {'logo_url': url}));
      return url;
    } catch (e) {
      debugPrint('Logo upload failed: $e');
      return '';
    }
  }

  void _showProfileDialog(String email) {
    _editStoreName    = _storeName;
    _editStoreAddress = _storeAddress;
    _editStorePhone   = _storePhone;
    _editStoreEmail   = _storeEmail;
    _editStoreGstin   = _storeGstin;
    _editStoreUpiId   = _storeUpiId;
    _editBranchNumber = _branchNumber;
    _editLogoPath     = _logoPath;
    _editLogoUrl      = _logoUrl;

    String dialogLogoPath = _logoPath;
    String dialogLogoUrl  = _logoUrl;
    bool isSaving = false;

    final initials = _storeName.trim().split(RegExp(r'\s+')).take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: const Color(0xFFF2F2F7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  color: AppColors.primary,
                  child: Row(
                    children: [
                      // Tappable logo
                      GestureDetector(
                        onTap: () async {
                          final r = await FilePicker.platform.pickFiles(type: FileType.image);
                          if (r?.files.single.path != null) {
                            final copied = await LocalDbService.copyImageToAppDir(r!.files.single.path!);
                            setDlg(() {
                              dialogLogoPath = copied;
                              _editLogoPath  = copied;
                            });
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: dialogLogoPath.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Image.file(File(dialogLogoPath),
                                          width: 56, height: 56, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _logoFallback(initials)),
                                    )
                                  : dialogLogoUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(11),
                                          child: Image.network(dialogLogoUrl,
                                              width: 56, height: 56, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _logoFallback(initials)),
                                        )
                                      : _logoFallback(initials),
                            ),
                            // Camera overlay
                            Positioned(
                              right: 0, bottom: 0,
                              child: Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary, width: 1.5),
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                    size: 11, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_editStoreName.isNotEmpty ? _editStoreName : _storeName,
                                style: GoogleFonts.manrope(
                                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(email,
                                style: GoogleFonts.inter(
                                    fontSize: 11.5, color: Colors.white.withValues(alpha: 0.6))),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final r = await FilePicker.platform.pickFiles(type: FileType.image);
                                if (r?.files.single.path != null) {
                                  final copied = await LocalDbService.copyImageToAppDir(r!.files.single.path!);
                                  setDlg(() {
                                    dialogLogoPath = copied;
                                    _editLogoPath  = copied;
                                  });
                                }
                              },
                              child: Text(
                                dialogLogoPath.isNotEmpty || dialogLogoUrl.isNotEmpty
                                    ? 'Change logo' : 'Upload logo',
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w500,
                                    color: AppColors.accent,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (dialogLogoPath.isNotEmpty)
                        GestureDetector(
                          onTap: () => setDlg(() {
                            dialogLogoPath = '';
                            dialogLogoUrl  = '';
                            _editLogoPath  = '';
                            _editLogoUrl   = '';
                          }),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ),

                // ── Scrollable fields ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _settingsSectionHeader('BUSINESS DETAILS'),
                        _settingsCard([
                          _settingsTextField('Business Name', _editStoreName,
                              (v) => _editStoreName = v),
                          _settingsDivider(),
                          _settingsTextField('Address', _editStoreAddress,
                              (v) => _editStoreAddress = v, maxLines: 2),
                        ]),
                        const SizedBox(height: 20),
                        _settingsSectionHeader('CONTACT INFO'),
                        _settingsCard([
                          _settingsTextField('Phone Number', _editStorePhone,
                              (v) => _editStorePhone = v,
                              keyboardType: TextInputType.phone),
                          _settingsDivider(),
                          _settingsTextField('Business Email', _editStoreEmail,
                              (v) => _editStoreEmail = v,
                              keyboardType: TextInputType.emailAddress),
                        ]),
                        const SizedBox(height: 20),
                        _settingsSectionHeader('TAX & PAYMENTS'),
                        _settingsCard([
                          _settingsTextField('GSTIN', _editStoreGstin,
                              (v) => _editStoreGstin = v),
                          _settingsDivider(),
                          _settingsTextField('UPI ID', _editStoreUpiId,
                              (v) => _editStoreUpiId = v),
                          _settingsDivider(),
                          _settingsTextField('Branch Number', _editBranchNumber,
                              (v) => setState(() => _editBranchNumber = v),
                              hint: 'e.g. 01'),
                        ]),
                        const SizedBox(height: 20),
                        _settingsSectionHeader('BILLCAT ACCOUNT'),
                        _settingsCard([
                          Builder(builder: (_) {
                            final rawUid = Supabase.instance.client.auth.currentUser?.id ?? '';
                            final shortId = rawUid.isEmpty ? '—' : rawUid.replaceAll('-', '').substring(0, rawUid.length >= 6 ? 6 : rawUid.length).toUpperCase();
                            return Container(
                              constraints: const BoxConstraints(minHeight: 46),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Text('BillCat ID',
                                      style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF1C1C1E))),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: shortId));
                                      _showToast('BillCat ID copied!');
                                    },
                                    child: Row(
                                      children: [
                                        Text(shortId,
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: const Color(0xFF8E8E93),
                                                fontFeatures: [const FontFeature.tabularFigures()])),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF8E8E93)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ]),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Footer ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    border: Border(top: BorderSide(color: Color(0xFFD8D8DC), width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: isSaving ? null : () {
                          Navigator.pop(ctx);
                          _confirmLogout(context);
                        },
                        icon: const Icon(Icons.logout_rounded, size: 14, color: AppColors.error),
                        label: Text('Logout',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.error)),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            foregroundColor: AppColors.textMuted),
                        child: Text('Cancel',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          setDlg(() => isSaving = true);
                          // Upload logo to cloud if a new local file was picked
                          if (_editLogoPath.isNotEmpty) {
                            final url = await _uploadLogoToCloud(_editLogoPath);
                            if (url.isNotEmpty) _editLogoUrl = url;
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          setState(() {
                            _storeName    = _editStoreName.trim().isEmpty ? 'BillCat Store' : _editStoreName.trim();
                            _storeAddress = _editStoreAddress.trim();
                            _storePhone   = _editStorePhone.trim();
                            _storeEmail   = _editStoreEmail.trim();
                            _storeGstin   = _editStoreGstin.trim();
                            _storeUpiId   = _editStoreUpiId.trim();
                            _branchNumber = _editBranchNumber.trim().isEmpty ? '01' : _editBranchNumber.trim();
                            _logoPath     = _editLogoPath;
                            _logoUrl      = _editLogoUrl;
                          });
                          _persistSettings();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isSaving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Save Changes',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoFallback(String initials) => Center(
        child: Text(initials.isNotEmpty ? initials : 'B',
            style: GoogleFonts.manrope(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
      );

  // ── Settings panel (Apple-style) ─────────────────────────────────────────────

  void _openSettings() {
    setState(() {
      _editStoreName = _storeName;
      _editStoreAddress = _storeAddress;
      _editStorePhone = _storePhone;
      _editStoreEmail = _storeEmail;
      _editStoreGstin = _storeGstin;
      _editReceiptFooter = _receiptFooter;
      _editTaxLabel = _taxLabel;
      _editTaxRate = _taxRateDisplay;
      _editCurrencyCode = _currencyCode;
      _editCurrencySymbol = _currencySymbol;
      _editDialCode = _dialCode;
      _editPaperSize = _paperSize;
      _editAutoPrint = _autoPrint;
      _editInvoiceLayout = _invoiceLayout;
      _editPrintOrientation = _printOrientation;
      // Tab must match the paper size, else the Paper Size dropdown's value
      // (e.g. "3 inch") won't be among its items and DropdownButton asserts.
      _editPrinterTab = ['A4', 'A5'].contains(_paperSize) ? 'Regular' : 'Thermal';
      _editStoreTerms = _storeTerms;
      _editLogoPath = _logoPath;
      _editLogoUrl  = _logoUrl;
      _editStoreUpiId = _storeUpiId;
      _editBranchNumber = _branchNumber;
      _settingsPage = 'General';
      _showSettings = true;
    });
  }

  void _saveSettings() {
    setState(() {
      _storeName = _editStoreName.trim().isEmpty ? 'BillCat Store' : _editStoreName.trim();
      _storeAddress = _editStoreAddress.trim();
      _storePhone = _editStorePhone.trim();
      _storeEmail = _editStoreEmail.trim();
      _storeGstin = _editStoreGstin.trim();
      _receiptFooter = _editReceiptFooter.trim();
      _taxLabel = _editTaxLabel.trim().isEmpty ? 'GST' : _editTaxLabel.trim();
      _taxRateDisplay = _editTaxRate.trim().isEmpty ? '0' : _editTaxRate.trim();
      _syncTaxRate();
      _currencyCode = _editCurrencyCode;
      _currencySymbol = _editCurrencySymbol;
      _dialCode = _editDialCode;
      _paperSize = _editPaperSize;
      _autoPrint = _editAutoPrint;
      _invoiceLayout = _editInvoiceLayout;
      _printOrientation = _editPrintOrientation;
      _storeTerms = _editStoreTerms;
      _logoPath = _editLogoPath;
      _logoUrl  = _editLogoUrl;
      _storeUpiId = _editStoreUpiId.trim();
      _branchNumber = _editBranchNumber.trim().isEmpty ? '01' : _editBranchNumber.trim();
      _waPhoneNumberId = _editWaPhoneNumberId.trim();
      _waAccessToken = _editWaAccessToken.trim();
      _showSettings = false;
    });
    _persistSettings();
  }

  Future<void> _persistSettings() async {
    await LocalDbService.saveSettings({
      'store_name': _storeName,
      'store_address': _storeAddress,
      'store_phone': _storePhone,
      'store_email': _storeEmail,
      'store_gstin': _storeGstin,
      'receipt_footer': _receiptFooter,
      'tax_label': _taxLabel,
      'tax_rate': _taxRateDisplay,
      'currency_code': _currencyCode,
      'currency_symbol': _currencySymbol,
      'dial_code': _dialCode,
      'paper_size': _paperSize,
      'selected_printer': _selectedPrinter,
      'print_orientation': _printOrientation,
      'invoice_layout': _invoiceLayout,
      'store_terms': _storeTerms,
      'logo_path': _logoPath,
      'logo_url':  _logoUrl,
      'auto_print': _autoPrint ? '1' : '0',
      'store_upi_id': _storeUpiId,
      'branch_number': _branchNumber,
      'wa_phone_number_id': _waPhoneNumberId,
      'wa_access_token': _waAccessToken,
    });
    ConnectivityService.instance.syncNow();
  }

  static const _settingsNavItems = [
    (icon: Icons.storefront_outlined,         label: 'General'),
    (icon: Icons.percent_rounded,             label: 'Tax'),
    (icon: Icons.print_outlined,              label: 'Printer'),
    (icon: Icons.person_outline_rounded,      label: 'Account'),
    (icon: Icons.shield_outlined,             label: 'Security'),
    (icon: Icons.chat_bubble_outline_rounded, label: 'WhatsApp'),
    (icon: Icons.delete_sweep_outlined,       label: 'Data'),
  ];

  Widget _buildSettingsPanel() {
    return Container(
      key: const ValueKey('settings'),
      color: const Color(0xFFF2F2F7),
      child: Column(
        children: [
          // ── header bar ──
          Container(
            height: 64,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showSettings = false),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                  label: Text('Back',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const Spacer(),
                Text('Settings',
                    style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D1D1F))),
                const Spacer(),
                FilledButton(
                  onPressed: _saveSettings,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text('Done',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // ── body: sidebar + content ──
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSettingsSidebar(),
                Container(width: 1, color: const Color(0xFFD8D8DC)),
                Expanded(child: _buildSettingsContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSidebar() {
    return Container(
      width: 200,
      color: const Color(0xFFF5F5F7),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _settingsNavItems.map((item) {
          final selected = _settingsPage == item.label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _settingsPage = item.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          size: 16,
                          color: selected ? AppColors.primary : const Color(0xFF8E8E93)),
                      const SizedBox(width: 10),
                      Text(item.label,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFF3C3C43))),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsContent() {
    if (_settingsPage == 'Printer') return _buildSettingsPrinter();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: switch (_settingsPage) {
            'General'   => _buildSettingsStore(),
            'Tax'       => _buildSettingsTax(),
            'Account'   => _buildSettingsAccount(),
            'Security'  => _buildSettingsSecurity(),
            'WhatsApp'  => _buildSettingsWhatsApp(),
            'Data'      => _buildSettingsData(),
            _           => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  // ── Store ──
  Widget _buildSettingsStore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsPageTitle('General', Icons.storefront_outlined),
        const SizedBox(height: 24),
        _settingsCard([
          _settingsTextField('Store Name', _editStoreName,
              (v) => setState(() => _editStoreName = v)),
          _settingsDivider(),
          _settingsTextField('Store Address', _editStoreAddress,
              (v) => setState(() => _editStoreAddress = v)),
        ]),
        const SizedBox(height: 24),
        _settingsSectionHeader('CURRENCY'),
        const SizedBox(height: 8),
        _settingsCard([
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                final result = await _showCurrencyPicker(context, _editCurrencyCode);
                if (result != null) {
                  setState(() {
                    _editCurrencyCode = result.code;
                    _editCurrencySymbol = result.symbol;
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Text(
                      _currencies.firstWhere((c) => c.code == _editCurrencyCode,
                          orElse: () => _currencies.first).flag,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_editCurrencyCode  $_editCurrencySymbol',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1D1D1F))),
                          Text(
                            _currencies.firstWhere(
                                (c) => c.code == _editCurrencyCode,
                                orElse: () => _currencies.first).name,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF6E6E73)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFC7C7CC), size: 20),
                  ],
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        _settingsSectionHeader('REGION'),
        const SizedBox(height: 8),
        _settingsCard([
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                final picked = await _showDialCodePicker(context, _editDialCode);
                if (picked != null) setState(() => _editDialCode = picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.language_rounded, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Country Dial Code', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1D1D1F))),
                    Text('Used for WhatsApp: $_editDialCode', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6E6E73))),
                  ])),
                  Text(_editDialCode, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFC7C7CC), size: 20),
                ]),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  static const _dialCodes = [
    ('+91', '🇮🇳', 'India'), ('+1', '🇺🇸', 'United States'), ('+44', '🇬🇧', 'United Kingdom'),
    ('+971', '🇦🇪', 'UAE'), ('+966', '🇸🇦', 'Saudi Arabia'), ('+65', '🇸🇬', 'Singapore'),
    ('+60', '🇲🇾', 'Malaysia'), ('+92', '🇵🇰', 'Pakistan'), ('+880', '🇧🇩', 'Bangladesh'),
    ('+94', '🇱🇰', 'Sri Lanka'), ('+977', '🇳🇵', 'Nepal'), ('+61', '🇦🇺', 'Australia'),
    ('+49', '🇩🇪', 'Germany'), ('+33', '🇫🇷', 'France'), ('+81', '🇯🇵', 'Japan'),
    ('+86', '🇨🇳', 'China'), ('+55', '🇧🇷', 'Brazil'), ('+27', '🇿🇦', 'South Africa'),
    ('+234', '🇳🇬', 'Nigeria'), ('+254', '🇰🇪', 'Kenya'),
  ];

  Future<String?> _showDialCodePicker(BuildContext context, String current) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Select Country', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          for (final (code, flag, name) in _dialCodes)
            ListTile(
              leading: Text(flag, style: const TextStyle(fontSize: 22)),
              title: Text(name, style: GoogleFonts.inter(fontSize: 14)),
              trailing: Text(code, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              selected: code == current,
              selectedTileColor: AppColors.primary.withValues(alpha: 0.06),
              onTap: () => Navigator.pop(ctx, code),
            ),
        ],
      ),
    );
  }

  // ── Tax ──
  Widget _buildSettingsTax() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsPageTitle('Tax', Icons.percent_rounded),
        const SizedBox(height: 24),
        _settingsCard([
          _settingsTextField('Tax Label', _editTaxLabel,
              (v) => setState(() => _editTaxLabel = v)),
          _settingsDivider(),
          _settingsTextField('Tax Rate (%)', _editTaxRate,
              (v) => setState(() => _editTaxRate = v),
              keyboardType: TextInputType.number),
        ]),
      ],
    );
  }

  // ── Receipt ──
  Widget _buildSettingsReceipt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsPageTitle('Receipt', Icons.receipt_long_outlined),
        const SizedBox(height: 24),
        _settingsCard([
          _settingsTextField('Receipt Footer', _editReceiptFooter,
              (v) => setState(() => _editReceiptFooter = v), maxLines: 3),
        ]),
      ],
    );
  }

  // ── Printer ──
  Widget _buildSettingsPrinter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left: settings column ──────────────────────────────────────
        SizedBox(
          width: 420,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _settingsPageTitle('Print Settings', Icons.print_outlined),
                const SizedBox(height: 20),

                // Printer type tabs (Regular / Thermal)
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEF0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(children: [
                    for (final t in ['Regular', 'Thermal'])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _editPrinterTab = t;
                            const reg = ['Classic','Simple','Modern','GST','Landscape'];
                            const thm = ['Theme 1','Theme 2','Theme 3','Theme 4','Theme 5'];
                            final valid = t == 'Regular' ? reg : thm;
                            if (!valid.contains(_editInvoiceLayout)) {
                              _editInvoiceLayout = t == 'Regular' ? 'Classic' : 'Theme 1';
                            }
                            _editPaperSize = t == 'Regular' ? 'A4' : '3 inch';
                            _previewRevision++;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: _editPrinterTab == t ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _editPrinterTab == t
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                                  : [],
                            ),
                            child: Center(
                              child: Text('$t Printer',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: _editPrinterTab == t ? FontWeight.w600 : FontWeight.w400,
                                      color: _editPrinterTab == t ? const Color(0xFF1D1D1F) : const Color(0xFF6E6E73))),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Invoice layout themes
                _settingsSectionHeader('INVOICE LAYOUT'),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  const reg = ['Classic','Simple','Modern','GST','Landscape'];
                  const thm = ['Theme 1','Theme 2','Theme 3','Theme 4','Theme 5'];
                  final layouts = _editPrinterTab == 'Regular' ? reg : thm;
                  return SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      itemCount: layouts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final layout = layouts[i];
                        final selected = _editInvoiceLayout == layout;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _editInvoiceLayout = layout;
                              _invoiceLayout = layout;
                              _previewRevision++;
                            });
                            LocalDbService.saveSettings({'invoice_layout': layout});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 88,
                            height: 100,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.06)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? AppColors.primary : const Color(0xFFD8D8DC),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _layoutThumb(layout, selected: selected),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(layout,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? AppColors.primary
                                              : const Color(0xFF6E6E73))),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Company info
                _settingsSectionHeader('COMPANY INFO / HEADER'),
                const SizedBox(height: 8),
                _settingsCard([
                  _settingsTextField('Company Name', _editStoreName, (v) => setState(() => _editStoreName = v)),
                  _settingsDivider(),
                  _settingsTextField('Address', _editStoreAddress, (v) => setState(() => _editStoreAddress = v)),
                  _settingsDivider(),
                  _settingsTextField('Phone Number', _editStorePhone, (v) => setState(() => _editStorePhone = v), keyboardType: TextInputType.phone),
                  _settingsDivider(),
                  _settingsTextField('Email', _editStoreEmail, (v) => setState(() => _editStoreEmail = v), keyboardType: TextInputType.emailAddress),
                  _settingsDivider(),
                  _settingsTextField('GSTIN', _editStoreGstin, (v) => setState(() => _editStoreGstin = v)),
                  _settingsDivider(),
                  _settingsTextField('UPI ID', _editStoreUpiId, (v) => setState(() => _editStoreUpiId = v)),
                  _settingsDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Expanded(child: Text('Company Logo', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark))),
                      if (_editLogoPath.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(File(_editLogoPath), width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox()),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _editLogoPath = ''),
                          child: Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton.icon(
                        onPressed: () async {
                          final r = await FilePicker.platform.pickFiles(type: FileType.image);
                          if (r != null) {
                            final copied = await LocalDbService.copyImageToAppDir(r.files.single.path!);
                            setState(() => _editLogoPath = copied);
                          }
                        },
                        icon: const Icon(Icons.upload_rounded, size: 16),
                        label: Text(_editLogoPath.isEmpty ? 'Upload' : 'Change'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 24),

                // Page setup
                _settingsSectionHeader('PAGE SETUP'),
                const SizedBox(height: 8),
                _settingsCard([
                  _settingsDropdownRow('Paper Size',
                    _editPrinterTab == 'Regular' ? ['A4', 'A5'] : ['2 inch', '3 inch', '4 inch', 'Custom'],
                    _editPaperSize, (v) => setState(() { _editPaperSize = v!; _previewRevision++; })),
                  _settingsDivider(),
                  _settingsDropdownRow('Orientation', ['Portrait', 'Landscape'], _editPrintOrientation, (v) => setState(() { _editPrintOrientation = v!; _previewRevision++; })),
                ]),
                const SizedBox(height: 24),

                // Receipt footer
                _settingsSectionHeader('RECEIPT FOOTER'),
                const SizedBox(height: 8),
                _settingsCard([
                  _settingsTextField('Footer Text', _editReceiptFooter, (v) => setState(() => _editReceiptFooter = v), maxLines: 2),
                ]),
                const SizedBox(height: 24),

                // Terms & Conditions (used in Tax Invoice layout)
                _settingsSectionHeader('TERMS & CONDITIONS'),
                const SizedBox(height: 8),
                _settingsCard([
                  _settingsTextField('Terms & Conditions', _editStoreTerms, (v) => setState(() => _editStoreTerms = v), maxLines: 3),
                ]),
                const SizedBox(height: 24),

                // Auto print
                _settingsSectionHeader('OPTIONS'),
                const SizedBox(height: 8),
                _settingsCard([
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Auto Print', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1D1D1F))),
                        Text('Automatically print receipt after checkout',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6E6E73))),
                      ])),
                      Switch.adaptive(value: _editAutoPrint, onChanged: (v) => setState(() => _editAutoPrint = v), activeColor: AppColors.primary),
                    ]),
                  ),
                ]),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),

        // Vertical divider
        Container(width: 1, color: const Color(0xFFD8D8DC)),

        // ── Right: live preview ────────────────────────────────────────
        Expanded(
          child: Container(
            color: const Color(0xFFE8E8ED),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Preview header bar
                Container(
                  height: 44,
                  color: const Color(0xFFF2F2F7),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF6E6E73)),
                    const SizedBox(width: 6),
                    Text('Live Preview',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6E6E73))),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _printRecord(_testReceipt()),
                      icon: const Icon(Icons.print_outlined, size: 13),
                      label: Text('Print Test', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ]),
                ),
                Container(height: 1, color: const Color(0xFFD8D8DC)),
                // Preview body — renders the actual PDF bytes
                Expanded(
                  child: PdfPreview(
                    key: ValueKey(_previewRevision),
                    build: (_) => ReceiptPrinter.buildPdf(
                      _testReceipt(),
                      storeName: _editStoreName,
                      storeAddress: _editStoreAddress,
                      storePhone: _editStorePhone,
                      storeEmail: _editStoreEmail,
                      storeGstin: _editStoreGstin,
                      receiptFooter: _editReceiptFooter,
                      taxLabel: _editTaxLabel,
                      taxRate: _editTaxRate,
                      currencySymbol: _editCurrencySymbol,
                      paperSize: _editPaperSize,
                      orientation: _editPrintOrientation,
                      layout: _editInvoiceLayout,
                      storeTerms: _editStoreTerms,
                      logoPath: _editLogoPath,
                      storeUpiId: _editStoreUpiId,
                    ),
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    useActions: false,
                    scrollViewDecoration: const BoxDecoration(color: Color(0xFF3C3C3C)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Layout theme thumbnail widget
  Widget _layoutThumb(String layout, {required bool selected}) {
    final c = selected ? AppColors.primary : const Color(0xFFBBBBBB);
    final line = (double w, double h) => Container(
          width: w, height: h,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1)),
        );
    final gap = const SizedBox(height: 2.5);

    switch (layout) {
      case 'Classic':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          line(28, 3), gap, line(36, 1.5), gap, line(36, 1.5), gap, line(36, 1.5), gap, line(24, 3),
        ]);
      case 'Simple':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          line(24, 2.5), const SizedBox(height: 1.5), line(36, 1), const SizedBox(height: 1.5),
          line(36, 1), const SizedBox(height: 1.5), line(36, 1), const SizedBox(height: 1.5),
          line(36, 1), const SizedBox(height: 1.5), line(20, 2.5),
        ]);
      case 'Modern':
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(border: Border.all(color: c, width: 0.7))),
            const SizedBox(width: 2),
            Container(width: 10, height: 10, decoration: BoxDecoration(border: Border.all(color: c, width: 0.7))),
            const SizedBox(width: 2),
            Container(width: 10, height: 10, decoration: BoxDecoration(border: Border.all(color: c, width: 0.7))),
          ]), gap, line(36, 1.5), gap, line(36, 1.5), gap, line(36, 1.5), gap, line(22, 3),
        ]);
      case 'GST':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          line(28, 2.5), gap,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 17, height: 12, decoration: BoxDecoration(border: Border.all(color: c, width: 0.7), borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 2),
            Container(width: 17, height: 12, decoration: BoxDecoration(border: Border.all(color: c, width: 0.7), borderRadius: BorderRadius.circular(1))),
          ]), gap, line(36, 8), gap,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 20, height: 8, decoration: BoxDecoration(border: Border.all(color: c, width: 0.7), borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 2),
            Container(width: 14, height: 8, decoration: BoxDecoration(border: Border.all(color: c, width: 0.7), borderRadius: BorderRadius.circular(1))),
          ]), gap, line(22, 2.5),
        ]);
      case 'Landscape':
        return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(mainAxisSize: MainAxisSize.min, children: [line(16, 3), gap, line(16, 1.5), gap, line(16, 1.5)]),
          const SizedBox(width: 3),
          Column(mainAxisSize: MainAxisSize.min, children: [line(18, 1.5), gap, line(18, 1.5), gap, line(18, 1.5), gap, line(12, 3)]),
        ]);
      // ── Thermal ───────────────────────────────────────────────────────────
      case 'Theme 1':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          line(22, 2.5), gap, line(28, 1), gap, line(28, 1), gap, line(28, 1), gap, line(16, 2.5),
        ]);
      case 'Theme 2':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          line(20, 2), const SizedBox(height: 1.5), line(28, 0.8), const SizedBox(height: 1.5),
          line(28, 0.8), const SizedBox(height: 1.5), line(28, 0.8), const SizedBox(height: 1.5),
          line(28, 0.8), const SizedBox(height: 1.5), line(28, 0.8), const SizedBox(height: 1.5), line(14, 2),
        ]);
      case 'Theme 3':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          line(22, 3), gap, line(28, 2), gap, line(28, 2), gap, line(18, 4),
        ]);
      case 'Theme 4':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          line(22, 2.5), gap, line(28, 1), gap, line(28, 1), gap,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 5, decoration: BoxDecoration(border: Border.all(color: c, width: 0.5))),
            const SizedBox(width: 1),
            Container(width: 7, height: 5, decoration: BoxDecoration(border: Border.all(color: c, width: 0.5))),
            const SizedBox(width: 1),
            Container(width: 7, height: 5, decoration: BoxDecoration(border: Border.all(color: c, width: 0.5))),
          ]), gap, line(16, 2.5),
        ]);
      case 'Theme 5':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          line(22, 2.5), gap,
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Container(width: i == 1 ? 9 : 4, height: 3, color: c),
            ],
          ]), gap,
          for (int r = 0; r < 3; r++) ...[
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Container(width: i == 1 ? 9 : 4, height: 2.5, color: c.withValues(alpha: 0.5)),
              ],
            ]),
            const SizedBox(height: 2),
          ],
          line(16, 2.5),
        ]);
      default:
        return line(32, 20);
    }
  }

  // Receipt preview panel (Flutter-rendered, updates instantly)
  Widget _buildReceiptPreview() {
    if (_editInvoiceLayout == 'GST') return _buildTaxInvoicePreview();
    if (_editInvoiceLayout == 'Classic') return _buildClassicInvoicePreview();

    final isNarrow = _editPrinterTab == 'Thermal';
    final w = _editPaperSize == '2 inch' ? 175.0 : isNarrow ? 220.0 : _editPaperSize == 'A5' ? 260.0 : 310.0;
    final isGst = false;
    final isCompact = _editInvoiceLayout == 'Simple';
    final double fs = isCompact ? 7.0 : (isNarrow ? 8.0 : _editPaperSize == 'A5' ? 8.8 : 9.5);

    Widget sep() => Container(height: 0.5, color: const Color(0xFF888888), margin: EdgeInsets.symmetric(vertical: isCompact ? 3 : 5));
    Widget row(String l, String r, {bool bold = false, double? fsize}) => Row(children: [
          Expanded(child: Text(l, style: TextStyle(fontSize: fsize ?? fs, color: bold ? const Color(0xFF1D1D1F) : const Color(0xFF555555)))),
          Text(r, style: TextStyle(fontSize: fsize ?? fs, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF1D1D1F))),
        ]);

    return LayoutBuilder(builder: (context, constraints) {
      final scale = ((constraints.maxWidth - 48) / w).clamp(1.0, 4.0);
      return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Center(
        child: SizedBox(
          width: w * scale,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: w,
              child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          padding: EdgeInsets.all(isNarrow ? 10 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(child: Text(
                _editStoreName.isEmpty ? 'BillCat Store' : _editStoreName,
                style: TextStyle(fontSize: fs + 3, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F)),
                textAlign: TextAlign.center,
              )),
              if (_editStoreAddress.isNotEmpty) ...[
                const SizedBox(height: 2),
                Center(child: Text(_editStoreAddress, style: TextStyle(fontSize: fs - 1, color: const Color(0xFF777777)), textAlign: TextAlign.center)),
              ],
              if (_editStorePhone.isNotEmpty) ...[
                const SizedBox(height: 1),
                Center(child: Text('Tel: $_editStorePhone', style: TextStyle(fontSize: fs - 1, color: const Color(0xFF777777)))),
              ],
              if (_editStoreEmail.isNotEmpty) ...[
                const SizedBox(height: 1),
                Center(child: Text(_editStoreEmail, style: TextStyle(fontSize: fs - 1, color: const Color(0xFF777777)))),
              ],
              if (isGst && _editStoreGstin.isNotEmpty) ...[
                const SizedBox(height: 1),
                Center(child: Text('GSTIN: $_editStoreGstin', style: TextStyle(fontSize: fs - 1, color: const Color(0xFF555555)))),
              ],
              sep(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Bill #A1B2C3D4', style: TextStyle(fontSize: fs - 1.5, color: const Color(0xFF888888))),
                Text('28/04/2026  14:30', style: TextStyle(fontSize: fs - 1.5, color: const Color(0xFF888888))),
              ]),
              SizedBox(height: isCompact ? 2 : 3),
              Text('Customer: Sample Customer', style: TextStyle(fontSize: fs - 1.5, color: const Color(0xFF888888))),
              sep(),
              // Column headers
              Row(children: [
                Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontSize: fs - 1, fontWeight: FontWeight.bold, color: const Color(0xFF888888)))),
                Text('QTY', style: TextStyle(fontSize: fs - 1, fontWeight: FontWeight.bold, color: const Color(0xFF888888))),
                const SizedBox(width: 8),
                Text('TOTAL', style: TextStyle(fontSize: fs - 1, fontWeight: FontWeight.bold, color: const Color(0xFF888888))),
              ]),
              SizedBox(height: isCompact ? 2 : 4),
              // Sample items
              for (final item in [('Sample Product A', 'x2', '${_editCurrencySymbol}500'), ('Sample Product B', 'x1', '${_editCurrencySymbol}180')])
                Padding(
                  padding: EdgeInsets.symmetric(vertical: isCompact ? 1 : 2),
                  child: Row(children: [
                    Expanded(flex: 5, child: Text(item.$1, style: TextStyle(fontSize: fs, color: const Color(0xFF1D1D1F)))),
                    Text(item.$2, style: TextStyle(fontSize: fs, color: const Color(0xFF555555))),
                    const SizedBox(width: 8),
                    Text(item.$3, style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F))),
                  ]),
                ),
              sep(),
              row('Subtotal', '${_editCurrencySymbol}680'),
              row('$_editTaxLabel ($_editTaxRate%)', '${_editCurrencySymbol}${(680 * (double.tryParse(_editTaxRate) ?? 18) / 100).toStringAsFixed(2)}'),
              SizedBox(height: isCompact ? 2 : 3),
              Container(height: 1, color: const Color(0xFF1D1D1F)),
              SizedBox(height: isCompact ? 2 : 3),
              row('TOTAL', '${_editCurrencySymbol}${(680 * (1 + (double.tryParse(_editTaxRate) ?? 18) / 100)).toStringAsFixed(2)}', bold: true, fsize: fs + 2),
              SizedBox(height: isCompact ? 1 : 2),
              row('Payment', 'CASH'),
              // GST table
              if (isGst) ...[
                sep(),
                Text('Tax Summary', style: TextStyle(fontSize: fs - 0.5, fontWeight: FontWeight.bold, color: const Color(0xFF555555))),
                const SizedBox(height: 3),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCCCCCC), width: 0.5)),
                  child: Column(children: [
                    Container(color: const Color(0xFFF5F5F5), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(children: [
                        Expanded(child: Text('HSN', style: TextStyle(fontSize: fs - 1.5, fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Taxable', style: TextStyle(fontSize: fs - 1.5, fontWeight: FontWeight.bold))),
                        Expanded(child: Text('CGST', style: TextStyle(fontSize: fs - 1.5, fontWeight: FontWeight.bold))),
                        Expanded(child: Text('SGST', style: TextStyle(fontSize: fs - 1.5, fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Total', style: TextStyle(fontSize: fs - 1.5, fontWeight: FontWeight.bold))),
                      ]),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(children: [
                        Expanded(child: Text('1234', style: TextStyle(fontSize: fs - 1.5))),
                        Expanded(child: Text('${_editCurrencySymbol}680', style: TextStyle(fontSize: fs - 1.5))),
                        Expanded(child: Text('${_editCurrencySymbol}61', style: TextStyle(fontSize: fs - 1.5))),
                        Expanded(child: Text('${_editCurrencySymbol}61', style: TextStyle(fontSize: fs - 1.5))),
                        Expanded(child: Text('${_editCurrencySymbol}122', style: TextStyle(fontSize: fs - 1.5))),
                      ]),
                    ),
                  ]),
                ),
              ],
              sep(),
              Center(child: Text(
                _editReceiptFooter.isEmpty ? 'Thank you for your purchase!' : _editReceiptFooter,
                style: TextStyle(fontSize: fs - 1, color: const Color(0xFF888888)),
                textAlign: TextAlign.center,
              )),
            ],
          ),
        ),
            ),
          ),
        ),
      ),
    );
    });
  }

  // Tax Invoice A4 preview (Flutter-rendered)
  Widget _buildTaxInvoicePreview() {
    const fs = 8.5;
    const c555 = Color(0xFF555555);
    const c888 = Color(0xFF888888);
    const c1d = Color(0xFF1D1D1F);
    const cBorder = Color(0xFFCCCCCC);

    Widget sep() => Container(height: 0.5, color: c888, margin: const EdgeInsets.symmetric(vertical: 5));

    Widget labelVal(String lbl, String val) => Row(children: [
          SizedBox(width: 70, child: Text(lbl, style: const TextStyle(fontSize: fs - 1, color: c888))),
          Text(': ', style: const TextStyle(fontSize: fs - 1, color: c888)),
          Expanded(child: Text(val, style: const TextStyle(fontSize: fs - 1, fontWeight: FontWeight.bold, color: c1d))),
        ]);

    Widget totalRow(String l, String r, {bool bold = false, double fsize = fs}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontSize: fsize, color: c555))),
            Text(r, style: TextStyle(fontSize: fsize, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: c1d)),
          ]),
        );

    final taxPct = double.tryParse(_editTaxRate) ?? 18.0;
    final cgst = (680 * taxPct / 100) / 2;

    return LayoutBuilder(builder: (context, constraints) {
      const cardW = 380.0;
      final scale = ((constraints.maxWidth - 48) / cardW).clamp(1.0, 4.0);
      return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Center(
        child: SizedBox(
          width: cardW * scale,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: cardW,
              child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              const Center(
                child: Text('TAX INVOICE',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFF2D2D2D))),
              ),
              const SizedBox(height: 8),
              // Company header
              Text(_editStoreName.isEmpty ? 'BillCat Store' : _editStoreName,
                  style: const TextStyle(fontSize: fs + 1, fontWeight: FontWeight.bold, color: c1d)),
              if (_editStoreAddress.isNotEmpty)
                Text(_editStoreAddress, style: const TextStyle(fontSize: fs - 1, color: c888)),
              if (_editStorePhone.isNotEmpty)
                Text('Phone: $_editStorePhone', style: const TextStyle(fontSize: fs - 1, color: c888)),
              if (_editStoreGstin.isNotEmpty)
                Text('GSTIN: $_editStoreGstin', style: const TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: c555)),
              sep(),
              // Bill To / Invoice Details two-column
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(border: Border.all(color: cBorder, width: 0.5), borderRadius: BorderRadius.circular(3)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Bill To:', style: TextStyle(fontSize: fs - 1.5, fontWeight: FontWeight.bold, color: c888)),
                      const SizedBox(height: 3),
                      const Text('Walk-In Customer', style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: c1d)),
                      const Text('9876543210', style: TextStyle(fontSize: fs - 1, color: c888)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(border: Border.all(color: cBorder, width: 0.5), borderRadius: BorderRadius.circular(3)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Invoice Details:', style: TextStyle(fontSize: fs - 1.5, fontWeight: FontWeight.bold, color: c888)),
                      const SizedBox(height: 3),
                      labelVal('Invoice No.', 'INV-A1B2C3D4'),
                      labelVal('Date', '28/04/2026'),
                      labelVal('Time', '14:30'),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // Items table header
              Container(
                color: const Color(0xFF2D2D2D),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(children: const [
                  SizedBox(width: 14, child: Text('#', style: TextStyle(fontSize: fs - 2, color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 4, child: Text('Item', style: TextStyle(fontSize: fs - 2, color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 24, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: fs - 2, color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 44, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontSize: fs - 2, color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 44, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: fs - 2, color: Colors.white, fontWeight: FontWeight.bold))),
                ]),
              ),
              // Items
              for (final item in [('1', 'Sample Product A', '2', '250.00', '500.00'), ('2', 'Sample Product B', '1', '180.00', '180.00')])
                Container(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cBorder, width: 0.5))),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 14, child: Text(item.$1, style: const TextStyle(fontSize: fs - 2, color: c555))),
                    Expanded(flex: 4, child: Text(item.$2, style: const TextStyle(fontSize: fs - 1, color: c1d))),
                    SizedBox(width: 24, child: Text(item.$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: fs - 1, color: c555))),
                    SizedBox(width: 44, child: Text('$_editCurrencySymbol${item.$4}', textAlign: TextAlign.right, style: const TextStyle(fontSize: fs - 1, color: c555))),
                    SizedBox(width: 44, child: Text('$_editCurrencySymbol${item.$5}', textAlign: TextAlign.right, style: const TextStyle(fontSize: fs - 1, fontWeight: FontWeight.bold, color: c1d))),
                  ]),
                ),
              const SizedBox(height: 8),
              // Tax summary + totals
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Tax summary
                Expanded(
                  flex: 55,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tax Summary:', style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: c555)),
                    const SizedBox(height: 3),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: cBorder, width: 0.5)),
                      child: Column(children: [
                        Container(
                          color: const Color(0xFF5A5A5A),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(children: const [
                            Expanded(child: Text('Tax%', style: TextStyle(fontSize: fs - 2.5, color: Colors.white, fontWeight: FontWeight.bold))),
                            Expanded(child: Text('CGST', textAlign: TextAlign.right, style: TextStyle(fontSize: fs - 2.5, color: Colors.white, fontWeight: FontWeight.bold))),
                            Expanded(child: Text('SGST', textAlign: TextAlign.right, style: TextStyle(fontSize: fs - 2.5, color: Colors.white, fontWeight: FontWeight.bold))),
                            Expanded(child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: fs - 2.5, color: Colors.white, fontWeight: FontWeight.bold))),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(children: [
                            Expanded(child: Text('$_editTaxRate%', style: const TextStyle(fontSize: fs - 2.5, color: c555))),
                            Expanded(child: Text('$_editCurrencySymbol${cgst.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: fs - 2.5, color: c555))),
                            Expanded(child: Text('$_editCurrencySymbol${cgst.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: fs - 2.5, color: c555))),
                            Expanded(child: Text('$_editCurrencySymbol${(cgst * 2).toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: fs - 2.5, color: c555))),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                // Totals
                Expanded(
                  flex: 42,
                  child: Column(children: [
                    totalRow('Sub Total', '$_editCurrencySymbol 680.00'),
                    totalRow('CGST', '$_editCurrencySymbol${cgst.toStringAsFixed(2)}'),
                    totalRow('SGST', '$_editCurrencySymbol${cgst.toStringAsFixed(2)}'),
                    const Divider(height: 8, thickness: 0.5),
                    totalRow('Total', '$_editCurrencySymbol${(680 + cgst * 2).toStringAsFixed(2)}', bold: true, fsize: fs + 1),
                  ]),
                ),
              ]),
              sep(),
              // Amount in words
              RichText(text: TextSpan(children: [
                const TextSpan(text: 'Amount In Words: ', style: TextStyle(fontSize: fs - 1, fontWeight: FontWeight.bold, color: c555)),
                TextSpan(text: 'Six Hundred Eighty Rupees Only', style: const TextStyle(fontSize: fs - 1, color: c888)),
              ])),
              sep(),
              // Footer
              if (_editReceiptFooter.isNotEmpty || _editStoreTerms.isNotEmpty)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_editReceiptFooter.isNotEmpty)
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Description:', style: TextStyle(fontSize: fs - 1, fontWeight: FontWeight.bold, color: c555)),
                      const SizedBox(height: 2),
                      Text(_editReceiptFooter, style: const TextStyle(fontSize: fs - 2, color: c888)),
                    ])),
                  if (_editReceiptFooter.isNotEmpty && _editStoreTerms.isNotEmpty) const SizedBox(width: 8),
                  if (_editStoreTerms.isNotEmpty)
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Terms & Conditions:', style: TextStyle(fontSize: fs - 1, fontWeight: FontWeight.bold, color: c555)),
                      const SizedBox(height: 2),
                      Text(_editStoreTerms, style: const TextStyle(fontSize: fs - 2, color: c888)),
                    ])),
                ]),
            ],
          ),
        ),
            ),
          ),
        ),
      ),
    );
    });
  }

  // Classic Tax Invoice preview (Flutter-rendered)
  Widget _buildClassicInvoicePreview() {
    const w = 310.0;
    const fs = 7.5;
    const c1d = Color(0xFF1D1D1F);
    const c55 = Color(0xFF555555);
    const c88 = Color(0xFF888888);
    const cBorder = Color(0xFFCCCCCC);
    const cGrey = Color(0xFFF0F0F0);

    final invoiceNo = 'Inv. PREVIEW';
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}-${now.month.toString().padLeft(2,'0')}-${now.year}';

    Widget cell(String v, {bool bold = false, Color? c, TextAlign a = TextAlign.left, double? size}) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Text(v, textAlign: a,
            style: TextStyle(fontSize: size ?? fs - 1, fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: c ?? c1d)));

    Widget greyHeader(String t) => Container(color: cGrey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(t, style: TextStyle(fontSize: fs - 0.5, fontWeight: FontWeight.w700, color: c1d)));

    Widget detLine(String lbl, String val) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        Text(lbl, style: TextStyle(fontSize: fs - 1.5, color: c88)),
        Text(': ', style: TextStyle(fontSize: fs - 1.5, color: c88)),
        Text(val, style: TextStyle(fontSize: fs - 1.5, color: c1d)),
      ]));

    Widget totLine(String lbl, String val, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(lbl, style: TextStyle(fontSize: fs - 1.5, color: bold ? c1d : c55, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        Text(val, style: TextStyle(fontSize: fs - 1.5, color: bold ? c1d : c55, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      ]));

    return LayoutBuilder(builder: (context, constraints) {
      final scale = ((constraints.maxWidth - 48) / w).clamp(1.0, 4.0);
      return SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: w * scale,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: w,
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: cBorder, width: 0.8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Title
                    Container(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cBorder))),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Center(child: Text('Tax Invoice', style: TextStyle(fontSize: fs + 1, fontWeight: FontWeight.w700, color: c1d))),
                    ),
                    // Company info (left) | Invoice details (right)
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(flex: 55, child: Container(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cBorder))),
                          padding: const EdgeInsets.all(8),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(width: 44, height: 44, decoration: BoxDecoration(color: cGrey, border: Border.all(color: cBorder, width: 0.5)),
                              child: _editLogoPath.isNotEmpty
                                  ? ClipRRect(child: Image.file(File(_editLogoPath), width: 44, height: 44, fit: BoxFit.cover))
                                  : Center(child: Text('IMG', style: TextStyle(fontSize: 7, color: c88)))),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_editStoreName.isNotEmpty ? _editStoreName : 'Company',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c1d)),
                              if (_editStoreAddress.isNotEmpty) Text(_editStoreAddress,
                                style: TextStyle(fontSize: fs - 2, color: c55)),
                              if (_editStorePhone.isNotEmpty) RichText(text: TextSpan(children: [
                                TextSpan(text: 'Phone: ', style: TextStyle(fontSize: fs - 2, color: c88)),
                                TextSpan(text: _editStorePhone, style: TextStyle(fontSize: fs - 2, fontWeight: FontWeight.w700, color: c1d)),
                              ])),
                              if (_editStoreEmail.isNotEmpty) RichText(text: TextSpan(children: [
                                TextSpan(text: 'Email: ', style: TextStyle(fontSize: fs - 2, color: c88)),
                                TextSpan(text: _editStoreEmail, style: TextStyle(fontSize: fs - 2, fontWeight: FontWeight.w700, color: c1d)),
                              ])),
                            ])),
                          ]),
                        )),
                        Container(width: 0.5, color: cBorder),
                        Expanded(flex: 45, child: Container(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cBorder))),
                          padding: const EdgeInsets.all(8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            detLine('Invoice No.', invoiceNo),
                            detLine('Date', dateStr),
                            detLine('Time', '12:00 PM'),
                            detLine('Due Date', dateStr),
                          ]),
                        )),
                      ]),
                    ),
                    // Bill To | Invoice Details
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(flex: 55, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          greyHeader('Bill To:'),
                          Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Sample Customer', style: TextStyle(fontSize: fs - 1, color: c1d)),
                            Text('Contact No.: 9999999999', style: TextStyle(fontSize: fs - 2, color: c55)),
                            const SizedBox(height: 8),
                          ])),
                        ])),
                        Container(width: 0.5, color: cBorder),
                        Expanded(flex: 45, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          greyHeader('Invoice Details:'),
                          Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            detLine('Invoice No.', invoiceNo),
                            detLine('Date', dateStr),
                            detLine('Time', '12:00 PM'),
                            detLine('Due Date', dateStr),
                          ])),
                        ])),
                      ]),
                    ),
                    Container(height: 0.5, color: cBorder),
                    // Ship To
                    greyHeader('Ship To:'),
                    Container(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cBorder))),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: Text('—', style: TextStyle(fontSize: fs - 1, color: c55)),
                    ),
                    // Items header
                    Container(color: cGrey,
                      child: Row(children: [
                        for (final h in [('#', 14.0, TextAlign.center), ('Item name', 80.0, TextAlign.left),
                          ('HSC/SAC', 38.0, TextAlign.center), ('Qty', 28.0, TextAlign.center),
                          ('Price', 38.0, TextAlign.right), ('Disc', 36.0, TextAlign.right),
                          ('GST', 34.0, TextAlign.right), ('Amt', 36.0, TextAlign.right)])
                          SizedBox(width: h.$2, child: cell(h.$1, bold: true, a: h.$3)),
                      ])),
                    Container(height: 0.5, color: cBorder),
                    // Sample rows
                    for (final row in [('1','Sample Product A','—','2','₹250','₹0','₹0','₹500'), ('2','Sample Product B','—','1','₹180','₹0','₹0','₹180')])
                      Column(children: [
                        Row(children: [
                          SizedBox(width: 14, child: cell(row.$1, a: TextAlign.center)),
                          SizedBox(width: 80, child: cell(row.$2, bold: true)),
                          SizedBox(width: 38, child: cell(row.$3, a: TextAlign.center)),
                          SizedBox(width: 28, child: cell(row.$4, a: TextAlign.center)),
                          SizedBox(width: 38, child: cell(row.$5, a: TextAlign.right)),
                          SizedBox(width: 36, child: cell(row.$6, a: TextAlign.right)),
                          SizedBox(width: 34, child: cell(row.$7, a: TextAlign.right)),
                          SizedBox(width: 36, child: cell(row.$8, bold: true, a: TextAlign.right)),
                        ]),
                        Container(height: 0.5, color: cBorder),
                      ]),
                    // TOTAL row
                    Container(color: cGrey,
                      child: Row(children: [
                        const SizedBox(width: 14),
                        SizedBox(width: 80, child: cell('TOTAL', bold: true)),
                        const SizedBox(width: 38),
                        SizedBox(width: 28, child: cell('3', bold: true, a: TextAlign.center)),
                        const SizedBox(width: 38),
                        SizedBox(width: 36, child: cell('₹0', bold: true, a: TextAlign.right)),
                        SizedBox(width: 34, child: cell('₹0', bold: true, a: TextAlign.right)),
                        SizedBox(width: 36, child: cell('₹680', bold: true, a: TextAlign.right)),
                      ])),
                    Container(height: 0.5, color: cBorder),
                    // Tax Summary | Totals
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(flex: 55, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          // Tax table header
                          Container(color: cGrey, child: Row(children: [
                            SizedBox(width: 28, child: cell('HSN', bold: true, a: TextAlign.center, size: fs - 3)),
                            Container(width: 0.5, color: cBorder),
                            SizedBox(width: 38, child: cell('Taxable', bold: true, a: TextAlign.center, size: fs - 3)),
                            Container(width: 0.5, color: cBorder),
                            Expanded(child: Column(children: [
                              Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cBorder))),
                                child: Center(child: Text('CGST', style: TextStyle(fontSize: fs - 3, fontWeight: FontWeight.w700)))),
                              Row(children: [
                                Expanded(child: Center(child: Text('Rate', style: TextStyle(fontSize: fs - 3.5)))),
                                Container(width: 0.5, color: cBorder),
                                Expanded(child: Center(child: Text('Amt', style: TextStyle(fontSize: fs - 3.5)))),
                              ]),
                            ])),
                            Container(width: 0.5, color: cBorder),
                            Expanded(child: Column(children: [
                              Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cBorder))),
                                child: Center(child: Text('SGST', style: TextStyle(fontSize: fs - 3, fontWeight: FontWeight.w700)))),
                              Row(children: [
                                Expanded(child: Center(child: Text('Rate', style: TextStyle(fontSize: fs - 3.5)))),
                                Container(width: 0.5, color: cBorder),
                                Expanded(child: Center(child: Text('Amt', style: TextStyle(fontSize: fs - 3.5)))),
                              ]),
                            ])),
                            Container(width: 0.5, color: cBorder),
                            SizedBox(width: 32, child: cell('Total Tax', bold: true, a: TextAlign.center, size: fs - 3)),
                          ])),
                          Container(height: 0.5, color: cBorder),
                          // Data row
                          Row(children: [
                            SizedBox(width: 28, child: cell('—', a: TextAlign.center, size: fs - 2.5)),
                            Container(width: 0.5, color: cBorder),
                            SizedBox(width: 38, child: cell('₹680', a: TextAlign.right, size: fs - 2.5)),
                            Container(width: 0.5, color: cBorder),
                            Expanded(child: Row(children: [
                              Expanded(child: cell('${_editTaxRate}%', a: TextAlign.right, size: fs - 2.5)),
                              Container(width: 0.5, color: cBorder),
                              Expanded(child: cell('₹0', a: TextAlign.right, size: fs - 2.5)),
                            ])),
                            Container(width: 0.5, color: cBorder),
                            Expanded(child: Row(children: [
                              Expanded(child: cell('${_editTaxRate}%', a: TextAlign.right, size: fs - 2.5)),
                              Container(width: 0.5, color: cBorder),
                              Expanded(child: cell('₹0', a: TextAlign.right, size: fs - 2.5)),
                            ])),
                            Container(width: 0.5, color: cBorder),
                            SizedBox(width: 32, child: cell('₹0', a: TextAlign.right, size: fs - 2.5)),
                          ]),
                          Container(height: 0.5, color: cBorder),
                          // Payment mode
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: RichText(text: TextSpan(children: [
                              TextSpan(text: 'Payment Mode: ', style: TextStyle(fontSize: fs - 1.5, color: c88)),
                              TextSpan(text: 'Cash', style: TextStyle(fontSize: fs - 1.5, fontWeight: FontWeight.w700, color: c1d)),
                            ]))),
                        ])),
                        Container(width: 0.5, color: cBorder),
                        // Totals right column
                        Expanded(flex: 45, child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            totLine('Sub Total', '₹680.00'),
                            totLine('Tax ($_editTaxRate%)', '₹0.00'),
                            Container(height: 0.5, color: cBorder, margin: const EdgeInsets.symmetric(vertical: 3)),
                            totLine('Total', '$_editCurrencySymbol 680.00', bold: true),
                            const SizedBox(height: 4),
                            Text('Invoice Amount In Words:', style: TextStyle(fontSize: fs - 2, color: c55, fontWeight: FontWeight.w700)),
                            Text('Six Hundred Eighty only', style: TextStyle(fontSize: fs - 2.5, color: c88)),
                            const SizedBox(height: 3),
                            totLine('Received', '₹680.00'),
                            totLine('Balance', '₹0.00'),
                          ]),
                        )),
                      ]),
                    ),
                    Container(height: 0.5, color: cBorder),
                    // Footer
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(flex: 55, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          greyHeader('Description:'),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(_editReceiptFooter.isNotEmpty ? _editReceiptFooter : 'Sale Description',
                              style: TextStyle(fontSize: fs - 2, color: c55))),
                          Container(height: 0.5, color: cBorder),
                          greyHeader('Bank Details:'),
                          Padding(padding: const EdgeInsets.all(6),
                            child: Row(children: [
                              Container(width: 30, height: 30, color: cGrey,
                                child: Center(child: Text('QR', style: TextStyle(fontSize: 7, color: c88)))),
                              const SizedBox(width: 6),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Bank Name: —', style: TextStyle(fontSize: fs - 2.5, color: c55)),
                                Text('Account No.: —', style: TextStyle(fontSize: fs - 2.5, color: c55)),
                                Text('IFSC Code: —', style: TextStyle(fontSize: fs - 2.5, color: c55)),
                              ]),
                            ])),
                        ])),
                        Container(width: 0.5, color: cBorder),
                        Expanded(flex: 45, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          greyHeader('Terms & Conditions:'),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(_editStoreTerms.isNotEmpty ? _editStoreTerms : 'Thanks for doing business with us!',
                              style: TextStyle(fontSize: fs - 2, color: c55))),
                          Container(height: 0.5, color: cBorder),
                          greyHeader('For: ${_editStoreName.isNotEmpty ? _editStoreName : "Company"}:'),
                          Padding(padding: const EdgeInsets.all(6),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              Container(width: 40, height: 34, color: cGrey,
                                child: Center(child: Text('Image', style: TextStyle(fontSize: 7, color: c88)))),
                              const SizedBox(height: 3),
                              Text('Authorized Signatory', style: TextStyle(fontSize: fs - 2, color: c55)),
                            ])),
                        ])),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _settingsDropdownRow(String label, List<String> options, String value, ValueChanged<String?> onChanged) {
    // Guard: DropdownButton asserts if `value` isn't among `options`. Fall back
    // to the first option so a stale value can never red-screen the app.
    final safeValue = options.contains(value) ? value : (options.isNotEmpty ? options.first : null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 130,
          child: Text(label, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1D1D1F))),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              items: options.map((o) => DropdownMenuItem(value: o,
                  child: Text(o, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1D1D1F))))).toList(),
              onChanged: onChanged,
              alignment: Alignment.centerRight,
              isDense: true,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1D1D1F)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Account ──
  Widget _buildSettingsAccount() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final name = user?.userMetadata?['full_name'] as String? ?? 'User';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsPageTitle('Account', Icons.person_outline_rounded),
        const SizedBox(height: 24),
        _settingsCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1D1D1F))),
                      Text(email,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF6E6E73))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 24),
        _settingsCard([
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _manualCheckForUpdate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _isCheckingUpdate
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.system_update_alt_rounded,
                            size: 18, color: Color(0xFF1D1D1F)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Check for Updates',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1D1D1F))),
                    ),
                    if (_updateInfo != null && !_updateDismissed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('v${_updateInfo!.version} available',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      )
                    else
                      Text('v${_appVersion()}',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF6E6E73))),
                  ],
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _settingsCard([
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                setState(() => _showSettings = false);
                await Future.delayed(const Duration(milliseconds: 200));
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        size: 18, color: Colors.red),
                    const SizedBox(width: 12),
                    Text('Sign Out',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red)),
                  ],
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Center(
          child: Text('BillCat v${_appVersion()}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF6E6E73))),
        ),
      ],
    );
  }

  Widget _buildSettingsSecurity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsPageTitle('Security', Icons.shield_outlined),
        const SizedBox(height: 24),
        _settingsSectionHeader('STAFF ACCESS CONTROL'),
        const SizedBox(height: 12),
        _settingsCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xFF1D1D1F)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Enable Staff Mode',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1D1D1F))),
                const SizedBox(height: 2),
                Text('Hide Dashboard & Reports from staff. A passcode unlocks owner access.',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6E6E73))),
              ])),
              Switch(
                value: _ownerLockEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) async {
                  if (val) {
                    // Enabling — require a passcode first
                    if (_ownerPasscode.isEmpty) {
                      _showSetPasscodeDialog(isFirstTime: true, onSet: () async {
                        setState(() { _ownerLockEnabled = true; _isOwnerMode = true; });
                        await LocalDbService.saveSettings({'owner_lock_enabled': '1'});
                        ConnectivityService.instance.syncNow();
                      });
                    } else {
                      setState(() { _ownerLockEnabled = true; _isOwnerMode = true; });
                      await LocalDbService.saveSettings({'owner_lock_enabled': '1'});
                      ConnectivityService.instance.syncNow();
                    }
                  } else {
                    setState(() { _ownerLockEnabled = false; _isOwnerMode = false; });
                    await LocalDbService.saveSettings({'owner_lock_enabled': '0'});
                    ConnectivityService.instance.syncNow();
                  }
                },
              ),
            ]),
          ),
        ]),
        if (_ownerLockEnabled) ...[
          const SizedBox(height: 16),
          _settingsSectionHeader('OWNER PASSCODE'),
          const SizedBox(height: 12),
          _settingsCard([
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showSetPasscodeDialog(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    const Icon(Icons.pin_outlined, size: 18, color: Color(0xFF1D1D1F)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_ownerPasscode.isEmpty ? 'Set Passcode' : 'Change Passcode',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1D1D1F)))),
                    Text(_ownerPasscode.isEmpty ? 'Not set' : '••••',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6E6E73))),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFAAAAAA)),
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ],
    );
  }


  // ── WhatsApp Settings ──
  Widget _buildSettingsWhatsApp() {
    final configured = _waPhoneNumberId.isNotEmpty && _waAccessToken.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsPageTitle('WhatsApp', Icons.chat_bubble_outline_rounded),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 16),
          child: Text(
            'Send invoices automatically via WhatsApp using Meta Cloud API. Free 1,000 conversations/month.',
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF6E6E73)),
          ),
        ),
        if (configured) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF1AAD56)),
              const SizedBox(width: 8),
              Text('WhatsApp API configured', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1AAD56))),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        _settingsSectionHeader('META CLOUD API'),
        const SizedBox(height: 12),
        _settingsCard([
          _settingsTextField('Phone Number ID', _editWaPhoneNumberId,
              (v) => setState(() => _editWaPhoneNumberId = v),
              hint: '1149269661601168'),
          _settingsDivider(),
          _settingsTextField('Access Token', _editWaAccessToken,
              (v) => setState(() => _editWaAccessToken = v),
              hint: 'EAAxxxxxxxx...', obscureText: true),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Get Phone Number ID and Access Token from Meta for Developers → BillCat app → WhatsApp → API Setup.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
            )),
          ]),
        ),
      ],
    );
  }

  // ── Data Reset ──
  Widget _buildSettingsData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsPageTitle('Data', Icons.delete_sweep_outlined),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 24),
          child: Text(
            'Permanently delete data from this device and cloud. This cannot be undone.',
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF6E6E73)),
          ),
        ),
        _settingsSectionHeader('RESET OPTIONS'),
        const SizedBox(height: 12),
        _resetCard(
          icon: Icons.people_outline_rounded,
          title: 'Customer Data',
          subtitle: 'Delete all customers and credit balances',
          onTap: () => _confirmReset('Customer Data', _resetCustomers),
        ),
        const SizedBox(height: 10),
        _resetCard(
          icon: Icons.receipt_long_outlined,
          title: 'Sales',
          subtitle: 'Delete all transactions and billing history',
          onTap: () => _confirmReset('Sales', _resetSales),
        ),
        const SizedBox(height: 10),
        _resetCard(
          icon: Icons.inventory_2_outlined,
          title: 'Inventory',
          subtitle: 'Delete all products and categories',
          onTap: () => _confirmReset('Inventory', _resetInventory),
        ),
        const SizedBox(height: 24),
        _settingsSectionHeader('DANGER ZONE'),
        const SizedBox(height: 12),
        _resetCard(
          icon: Icons.warning_amber_rounded,
          title: 'Reset All Data',
          subtitle: 'Delete everything — customers, sales, and inventory',
          danger: true,
          onTap: () => _confirmReset('All Data', _resetAll),
        ),
      ],
    );
  }

  Widget _resetCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: danger ? const Color(0xFFFF3B30).withValues(alpha: 0.3) : const Color(0xFFE5E5EA)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (danger ? const Color(0xFFFF3B30) : AppColors.primary).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: danger ? const Color(0xFFFF3B30) : AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8E8E93))),
          ])),
          Icon(Icons.chevron_right_rounded, size: 18, color: const Color(0xFFBDBDBD)),
        ]),
      ),
    );
  }

  void _confirmReset(String label, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset $label?', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete all $label from this device and cloud. This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6E6E73), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await action();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$label deleted successfully', style: GoogleFonts.inter(color: Colors.white)),
                backgroundColor: const Color(0xFF34C759),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ));
              _loadDashboardData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetCustomers() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final db = await LocalDbService.db;
    await db.delete('customers');
    if (userId != null) {
      try {
        await Supabase.instance.client.from('customers').delete().eq('user_id', userId);
      } catch (_) {}
    }
  }

  Future<void> _resetSales() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final db = await LocalDbService.db;
    await db.delete('transactions');
    if (userId != null) {
      try {
        await Supabase.instance.client.from('transactions').delete().eq('user_id', userId);
      } catch (_) {}
    }
  }

  Future<void> _resetInventory() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final db = await LocalDbService.db;
    await db.delete('products');
    await db.delete('categories');
    if (userId != null) {
      try {
        await Supabase.instance.client.from('products').delete().eq('user_id', userId);
        await Supabase.instance.client.from('categories').delete().eq('user_id', userId);
      } catch (_) {}
    }
    setState(() => _products = List.from(_defaultProducts));
  }

  Future<void> _resetAll() async {
    await _resetCustomers();
    await _resetSales();
    await _resetInventory();
  }

  // ── Settings UI helpers ──

  Widget _settingsPageTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D1D1F))),
      ],
    );
  }

  Widget _settingsSectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Row(children: [
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8E8E93),
                  letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 0.5, color: const Color(0xFFD8D8DC))),
        ]),
      );

  Widget _settingsCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8ED), width: 0.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  Widget _settingsDivider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, color: Color(0xFFF2F2F7)),
      );

  Widget _settingsTextField(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    String? hint,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? 0 : 46),
      padding: EdgeInsets.symmetric(
          horizontal: 16, vertical: maxLines > 1 ? 12 : 0),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13.5, color: const Color(0xFF3C3C43))),
          ),
          Expanded(
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              keyboardType: keyboardType,
              maxLines: obscureText ? 1 : maxLines,
              obscureText: obscureText,
              style: GoogleFonts.inter(
                  fontSize: 13.5, color: const Color(0xFF1D1D1F)),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint ?? label,
                hintStyle: GoogleFonts.inter(
                    fontSize: 13.5, color: const Color(0xFFC7C7CC)),
                isDense: true,
                contentPadding: maxLines > 1
                    ? const EdgeInsets.symmetric(vertical: 4)
                    : EdgeInsets.zero,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _appVersion() => _currentVersion.isNotEmpty ? _currentVersion : '1.0.0';

  // ── Settings dialog (legacy — kept for reference) ─────────────────────────────────────────────

  void _showSettingsDialog() {
    String storeName = _storeName;
    String storeAddress = _storeAddress;
    String receiptFooter = _receiptFooter;
    String taxLabel = _taxLabel;
    String taxRate = _taxRateDisplay;
    String currencyCode = _currencyCode;
    String currencySymbol = _currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Text('Settings',
                        style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                          foregroundColor: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 20),

                // Store info
                _dialogSectionLabel('STORE INFORMATION'),
                const SizedBox(height: 14),
                _dialogField('Store Name', storeName,
                    (v) => setLocal(() => storeName = v)),
                const SizedBox(height: 12),
                _dialogField('Store Address', storeAddress,
                    (v) => setLocal(() => storeAddress = v)),
                const SizedBox(height: 12),
                _dialogField('Receipt Footer', receiptFooter,
                    (v) => setLocal(() => receiptFooter = v)),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 20),

                // Tax config
                _dialogSectionLabel('TAX CONFIGURATION'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _dialogField('Tax Label', taxLabel,
                            (v) => setLocal(() => taxLabel = v))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _dialogField('Tax Rate (%)', taxRate,
                            (v) => setLocal(() => taxRate = v),
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 20),

                // Currency
                _dialogSectionLabel('CURRENCY'),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    final result = await _showCurrencyPicker(ctx, currencyCode);
                    if (result != null) {
                      setLocal(() {
                        currencyCode = result.code;
                        currencySymbol = result.symbol;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _currencies.firstWhere((c) => c.code == currencyCode,
                              orElse: () => _currencies.first).flag,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$currencyCode  $currencySymbol',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              Text(_currencies.firstWhere((c) => c.code == currencyCode,
                                  orElse: () => _currencies.first).name,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w300, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _storeName =
                              storeName.trim().isEmpty ? 'BillCat Store' : storeName.trim();
                          _storeAddress = storeAddress.trim();
                          _receiptFooter = receiptFooter.trim();
                          _taxLabel =
                              taxLabel.trim().isEmpty ? 'VAT' : taxLabel.trim();
                          _taxRateDisplay =
                              taxRate.trim().isEmpty ? '0' : taxRate.trim();
                          _syncTaxRate();
                          _currencyCode = currencyCode;
                          _currencySymbol = currencySymbol;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: Text('Save Changes',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogSectionLabel(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 1.0));

  Widget _dialogField(String label, String value, Function(String) onChanged,
      {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  // ── Currency picker ──────────────────────────────────────────────────────────

  Future<_Currency?> _showCurrencyPicker(BuildContext ctx, String currentCode) {
    String query = '';
    return showDialog<_Currency>(
      context: ctx,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setLocal) {
          final filtered = query.isEmpty
              ? _currencies
              : _currencies.where((c) =>
                  c.name.toLowerCase().contains(query.toLowerCase()) ||
                  c.code.toLowerCase().contains(query.toLowerCase()) ||
                  c.symbol.contains(query)).toList();
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              width: 420,
              height: 560,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                    child: Row(
                      children: [
                        Text('Select Currency',
                            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dlgCtx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) => setLocal(() => query = v),
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Search currency or code…',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w300),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  // List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final selected = c.code == currentCode;
                        return InkWell(
                          onTap: () => Navigator.pop(dlgCtx, c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            color: selected ? AppColors.primary.withValues(alpha: 0.05) : null,
                            child: Row(
                              children: [
                                Text(c.flag, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: AppColors.textDark)),
                                      Text(c.code,
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w300, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Text(c.symbol,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textMuted)),
                                if (selected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Printer dialog ───────────────────────────────────────────────────────────

  void _showPrinterDialog() async {
    if (!mounted) return;
    // Open dialog immediately — load printers in the background
    List<Printer> systemPrinters = [];

    Printer? selPrinter = _activePrinter;
    bool isPdfExport = _selectedPrinter == 'PDF Export';
    String paper = _paperSize;
    // Map stored paper size to Thermal/Regular
    bool isThermal = !['A4', 'A5'].contains(paper);
    // Thermal defaults to 80mm (3 inch) unless a thermal size is already set.
    if (isThermal && !['2 inch', '3 inch', '4 inch'].contains(paper)) paper = '3 inch';
    bool autoCut = _thermalAutoCut;

    Widget printerRow(String name, {bool selected = false, required VoidCallback onTap, IconData icon = Icons.print_rounded}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 15, color: selected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.primary : AppColors.textDark)),
            ),
          ]),
        ),
      );
    }

    bool _loadingPrinters = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          if (_loadingPrinters) {
            _loadingPrinters = false;
            Future(() async {
              try {
                final printers = await Printing.listPrinters()
                    .timeout(const Duration(seconds: 5));
                if (ctx.mounted) setLocal(() => systemPrinters = printers);
              } catch (_) {
                if (ctx.mounted) setLocal(() {});
              }
            });
          }
          return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.print_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Text('Printer Settings',
                        style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 20),

                // Printer list
                _dialogSectionLabel('SELECT PRINTER'),
                const SizedBox(height: 10),

                if (systemPrinters.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text('No printers found. Add one in System Settings.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  )
                else
                  ...systemPrinters.map((p) => printerRow(
                        p.name,
                        selected: !isPdfExport && selPrinter?.url == p.url,
                        icon: Icons.print_rounded,
                        onTap: () => setLocal(() { selPrinter = p; isPdfExport = false; }),
                      )),

                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 20),

                // Printer type
                _dialogSectionLabel('PRINTER TYPE'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setLocal(() { isThermal = false; paper = 'A4'; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !isThermal ? AppColors.primary : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: !isThermal ? AppColors.primary : AppColors.border),
                      ),
                      child: Column(children: [
                        Icon(Icons.print_rounded, size: 20, color: !isThermal ? Colors.white : AppColors.textMuted),
                        const SizedBox(height: 6),
                        Text('Regular', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: !isThermal ? Colors.white : AppColors.textMuted)),
                        Text('A4 / A5', style: GoogleFonts.inter(fontSize: 10, color: !isThermal ? Colors.white.withValues(alpha: 0.8) : AppColors.textMuted)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () => setLocal(() { isThermal = true; paper = ['2 inch','3 inch','4 inch'].contains(paper) ? paper : '3 inch'; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isThermal ? AppColors.primary : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isThermal ? AppColors.primary : AppColors.border),
                      ),
                      child: Column(children: [
                        Icon(Icons.receipt_long_rounded, size: 20, color: isThermal ? Colors.white : AppColors.textMuted),
                        const SizedBox(height: 6),
                        Text('Thermal', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isThermal ? Colors.white : AppColors.textMuted)),
                        Text('80mm roll', style: GoogleFonts.inter(fontSize: 10, color: isThermal ? Colors.white.withValues(alpha: 0.8) : AppColors.textMuted)),
                      ]),
                    ),
                  )),
                ]),

                // Thermal-only: paper width + auto-cut (for ESC/POS reliability)
                if (isThermal) ...[
                  const SizedBox(height: 16),
                  _dialogSectionLabel('PAPER WIDTH'),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final w in const [('2 inch', '58mm'), ('3 inch', '80mm'), ('4 inch', '112mm')]) ...[
                      Expanded(child: GestureDetector(
                        onTap: () => setLocal(() => paper = w.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: paper == w.$1 ? AppColors.primary : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: paper == w.$1 ? AppColors.primary : AppColors.border),
                          ),
                          child: Center(child: Text(w.$2, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                              color: paper == w.$1 ? Colors.white : AppColors.textMuted))),
                        ),
                      )),
                      if (w.$1 != '4 inch') const SizedBox(width: 8),
                    ],
                  ]),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => setLocal(() => autoCut = !autoCut),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: autoCut ? AppColors.primary : AppColors.border),
                      ),
                      child: Row(children: [
                        Icon(Icons.content_cut_rounded, size: 16, color: autoCut ? AppColors.primary : AppColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Auto-cut paper', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                              color: autoCut ? AppColors.primary : AppColors.textMuted)),
                          Text('Turn off if your printer has no cutter',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ])),
                        Switch(
                          value: autoCut,
                          onChanged: (v) => setLocal(() => autoCut = v),
                          activeTrackColor: AppColors.primary,
                          activeThumbColor: Colors.white,
                        ),
                      ]),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          // Reflect the dialog's current cutter choice in the test.
                          _thermalAutoCut = autoCut;
                          // Print straight to the printer selected above (in the
                          // chosen Regular/Thermal format); only fall back to the
                          // PDF/Preview path when "PDF Export" is the choice.
                          if (isPdfExport || selPrinter == null) {
                            _printRecord(_testReceipt(), paperSize: paper);
                          } else {
                            _printRecord(_testReceipt(), paperSize: paper,
                                toPrinter: true, printerNameOverride: selPrinter!.name);
                          }
                        },
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: Text('Print Test Page',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.border),
                          foregroundColor: AppColors.textDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final printerName = isPdfExport
                              ? 'PDF Export'
                              : (selPrinter?.name ?? 'System Default');
                          setState(() {
                            _activePrinter = selPrinter;
                            _selectedPrinter = printerName;
                            _paperSize = paper;
                            _thermalAutoCut = autoCut;
                          });
                          LocalDbService.saveSettings({
                            'selected_printer': printerName,
                            'paper_size': paper,
                            'thermal_auto_cut': autoCut ? '1' : '0',
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Save',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              await LocalDbService.clearAll();
              await SupabaseService.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()),
                  (r) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Logout',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Bill',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700)),
        content: Text('Remove all items from the current bill?',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Clear',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Print helpers ────────────────────────────────────────────────────────────

  TransactionRecord _snapshotCart(CartProvider cart, {String? invoiceNumber, String? transactionId}) => TransactionRecord(
        id: transactionId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        customerName: cart.customerName.isEmpty ? null : cart.customerName,
        customerPhone: cart.customerPhone.isEmpty ? null : cart.customerPhone,
        items: cart.items
            .map((i) => TransactionItem(
                  productId: i.product.id,
                  productName: i.variant != null ? '${i.product.name} (${i.variant!.name})' : i.product.name,
                  price: i.unitPrice,
                  quantity: i.quantity,
                  description: i.product.description,
                ))
            .toList(),
        subtotal: cart.subtotal,
        discountAmount: cart.discountAmount,
        taxAmount: cart.taxAmount,
        total: cart.total,
        paymentMethod: cart.paymentMethod.name,
        createdAt: DateTime.now(),
        invoiceNumber: invoiceNumber,
      );

  void _printCurrentBill(CartProvider cart, {String docType = 'Invoice', bool toPrinter = false}) =>
      _printRecord(_snapshotCart(cart), docType: docType, toPrinter: toPrinter);

  void _showPrintBillDialog(CartProvider cart) {
    bool sendToPrinter = _lastPrintToPrinter;
    bool sendWhatsApp = _lastPrintWhatsApp;
    String docType = _lastPrintDocType;
    final phoneCtrl = TextEditingController(text: cart.customerPhone);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('Print Bill', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
                  ),
                ]),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),
                // Document type selector
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setLocal(() => docType = 'Invoice'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: docType == 'Invoice' ? AppColors.primary : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: docType == 'Invoice' ? AppColors.primary : AppColors.border),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.receipt_long_rounded, size: 14,
                            color: docType == 'Invoice' ? Colors.white : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text('Invoice', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                            color: docType == 'Invoice' ? Colors.white : AppColors.textMuted)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () => setLocal(() => docType = 'Quotation'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: docType == 'Quotation' ? AppColors.primary : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: docType == 'Quotation' ? AppColors.primary : AppColors.border),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.description_outlined, size: 14,
                            color: docType == 'Quotation' ? Colors.white : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text('Quotation', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                            color: docType == 'Quotation' ? Colors.white : AppColors.textMuted)),
                      ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 12),
                // Printer toggle
                InkWell(
                  onTap: () => setLocal(() => sendToPrinter = !sendToPrinter),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: sendToPrinter
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sendToPrinter ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Row(children: [
                      Icon(Icons.print_rounded, size: 16,
                          color: sendToPrinter ? AppColors.primary : AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send to Printer',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: sendToPrinter ? AppColors.primary : AppColors.textMuted)),
                          Text('Sends directly to default printer',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      )),
                      Switch(
                        value: sendToPrinter,
                        onChanged: (v) => setLocal(() => sendToPrinter = v),
                        activeTrackColor: AppColors.primary,
                        activeThumbColor: Colors.white,
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setLocal(() => sendWhatsApp = !sendWhatsApp),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: sendWhatsApp
                          ? const Color(0xFF25D366).withValues(alpha: 0.08)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sendWhatsApp ? const Color(0xFF25D366) : AppColors.border,
                      ),
                    ),
                    child: Row(children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 16,
                          color: sendWhatsApp ? const Color(0xFF1AAD56) : AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send via WhatsApp',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: sendWhatsApp ? const Color(0xFF1AAD56) : AppColors.textMuted)),
                          Text('Opens WhatsApp Web with invoice',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      )),
                      Switch(
                        value: sendWhatsApp,
                        onChanged: (v) => setLocal(() => sendWhatsApp = v),
                        activeTrackColor: const Color(0xFF25D366),
                        activeThumbColor: Colors.white,
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () {
                      final txId = _queuedTransactionId.isNotEmpty ? _queuedTransactionId : Uuid().v4();
                      final snapshot = _snapshotCart(cart, transactionId: txId);
                      // Remember the choices so the dialog reopens the same way
                      _lastPrintDocType = docType;
                      _lastPrintToPrinter = sendToPrinter;
                      _lastPrintWhatsApp = sendWhatsApp;
                      LocalDbService.saveSettings({
                        'print_doc_type': docType,
                        'print_to_printer': sendToPrinter ? '1' : '0',
                        'print_via_whatsapp': sendWhatsApp ? '1' : '0',
                      });
                      Navigator.pop(ctx);
                      if (sendToPrinter) _printCurrentBill(cart, docType: docType, toPrinter: true);
                      if (sendWhatsApp) {
                        _sendInvoiceViaWhatsApp(snapshot, phoneCtrl.text.trim(), docType: docType);
                      }
                    },
                    icon: sendToPrinter ? const Icon(Icons.print_rounded, size: 15) : const SizedBox.shrink(),
                    label: Text(sendToPrinter ? 'Print' : 'Confirm',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearPrintingState() {
    _printSafetyTimer?.cancel();
    _printSafetyTimer = null;
    if (mounted && _isPrinting) setState(() => _isPrinting = false);
  }

  // ── CUPS printing — basic principle: resolve queue → raw bytes → verify ──
  //
  // Every thermal receipt printer speaks ESC/POS, so the one reliable
  // pipeline for all makes is: find a queue that really exists, hand it the
  // raw bytes (bypassing whatever driver the queue happens to have), then
  // confirm the job left the queue — lpr exits 0 even when the printer is
  // unplugged, so success must be verified, not assumed.

  Future<List<String>> _cupsQueues() async {
    try {
      final res = await Process.run(
        '/usr/bin/lpstat',
        ['-e'],
      ).timeout(const Duration(seconds: 5));
      if (res.exitCode != 0) return const [];
      return (res.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Resolves a printer's display name to its actual CUPS queue name.
  /// CUPS mangles names beyond spaces→underscores (adds Printer_ prefixes,
  /// numeric suffixes, drops hyphens), so a naive replaceAll can miss and
  /// lpr then fails with "No such file or directory".
  String? _matchQueue(String displayName, List<String> queues) {
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final want = norm(displayName);
    if (want.isEmpty) return null;
    for (final q in queues) {
      if (norm(q) == want) return q;
    }
    for (final q in queues) {
      final nq = norm(q);
      if (nq.isEmpty) continue;
      if (nq.contains(want) || want.contains(nq)) return q;
    }
    return null;
  }

  /// Order of trust: the printer picked in settings, else the system
  /// default, else whatever queue exists — a receipt on the wrong printer
  /// beats no receipt at all on a busy counter.
  Future<String?> _resolveQueue(String target) async {
    final queues = await _cupsQueues();
    if (queues.isEmpty) return null;
    if (target != 'System Default' &&
        target != 'PDF Export' &&
        target.isNotEmpty) {
      final q = _matchQueue(target, queues);
      if (q != null) return q;
    }
    try {
      final res = await Process.run(
        '/usr/bin/lpstat',
        ['-d'],
      ).timeout(const Duration(seconds: 5));
      final out = res.stdout as String;
      final idx = out.indexOf(':');
      if (idx > 0) {
        final def = out.substring(idx + 1).trim();
        if (queues.contains(def)) return def;
      }
    } catch (_) {}
    return queues.first;
  }

  /// Prints [path] on [target]'s queue. Returns null on success, otherwise a
  /// human-readable problem. [raw] bypasses the driver (ESC/POS receipts);
  /// without it the file goes through the driver (PDF layouts).
  Future<String?> _printViaCups(
    String path,
    String target, {
    required bool raw,
  }) async {
    final queue = await _resolveQueue(target);
    if (queue == null) {
      return 'No printers are set up on this Mac (System Settings → Printers)';
    }
    final ProcessResult result;
    try {
      result = await Process.run(
        '/usr/bin/lpr',
        [if (raw) '-l', '-P', queue, path],
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      return '$e';
    }
    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      return err.isEmpty ? 'lpr failed (exit ${result.exitCode})' : err;
    }
    // Accepted by CUPS is not the same as printed: a job for an unplugged
    // printer queues forever with no error. Verify in the background so the
    // counter isn't blocked. Raw receipts transfer in well under a second,
    // so only they get the check — driver-rendered PDFs can legitimately
    // take longer and would false-alarm.
    if (raw) _warnIfQueueStuck(queue);
    return null;
  }

  /// Fire-and-forget: if [queue] still holds jobs a few seconds after we
  /// queued one, the printer is off or unplugged — surface that instead of
  /// letting receipts pile up silently.
  void _warnIfQueueStuck(String queue) {
    Future(() async {
      await Future.delayed(const Duration(seconds: 4));
      try {
        final check = await Process.run(
          '/usr/bin/lpstat',
          ['-o', queue],
        ).timeout(const Duration(seconds: 5));
        if ((check.stdout as String).trim().isNotEmpty && mounted) {
          _showToast(
            'Receipt sent to "$queue" but the printer is not responding — '
            'check its power and USB cable',
            isError: true,
          );
        }
      } catch (_) {}
    });
  }

  /// Same short link the WhatsApp share uses — the receipt QR opens the
  /// customer's digital invoice.
  String _invoiceLinkFor(TransactionRecord tx) {
    final invoiceNo = tx.id.replaceAll('-', '').substring(0, 6).toLowerCase();
    final rawUid = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
    final shortUid = rawUid.replaceAll('-', '').substring(0, 6).toLowerCase();
    final branchPadded = _branchNumber.padLeft(2, '0');
    return 'https://billcat.in/invoices/$shortUid$branchPadded$invoiceNo';
  }

  Future<void> _printRecord(TransactionRecord tx, {String? paperSize, String docType = 'Invoice', bool toPrinter = false, String? printerNameOverride}) async {
    _clearPrintingState();
    if (!mounted) return;
    setState(() => _isPrinting = true);
    _printSafetyTimer = Timer(const Duration(seconds: 30), _clearPrintingState);

    final effectivePaper = paperSize ?? _paperSize;
    final bool isThermal = effectivePaper.toLowerCase().contains('inch');

    // Thermal (80mm) printers are ESC/POS. Their CUPS drivers frequently can't
    // rasterise a PDF (some ship a Zebra ZPL driver that garbles it), so send
    // native ESC/POS bytes straight to the queue with `lp -o raw`.
    if (toPrinter && isThermal) {
      try {
        List<int>? logoRaster;
        if (_logoPath.isNotEmpty) {
          try {
            final logoFile = File(_logoPath);
            if (await logoFile.exists()) {
              logoRaster = EscPosReceipt.rasterFromImageBytes(
                await logoFile.readAsBytes(),
              );
            }
          } catch (_) {} // fall back to the block mark
        }
        final bytes = EscPosReceipt(
          cols: EscPosReceipt.colsForPaper(effectivePaper),
          cut: _thermalAutoCut,
        ).build(
          tx,
          storeName: _storeName, storeAddress: _storeAddress,
          storePhone: _storePhone, storeGstin: _storeGstin,
          receiptFooter: _receiptFooter, taxLabel: _taxLabel,
          taxRate: _taxRateDisplay, currencySymbol: _currencySymbol,
          storeTerms: _storeTerms, docType: docType,
          qrLink: _invoiceLinkFor(tx),
          logoRaster: logoRaster,
        );
        final receiptName = tx.invoiceNumber != null
            ? 'Receipt-${tx.invoiceNumber}'
            : 'Receipt-${billNo(tx)}';
        final escFile = File('/tmp/$receiptName.escpos');
        await escFile.writeAsBytes(bytes);
        final target = printerNameOverride ?? _selectedPrinter;
        // lpr -l (literal/raw): bytes go to the printer unfiltered — same
        // effect as `lp -o raw`, but lpr is the binary that the macOS app
        // can actually spawn (lp resolves to "No such file").
        final problem = await _printViaCups(escFile.path, target, raw: true);
        if (problem != null && mounted) {
          _showToast('Could not print: $problem', isError: true);
        }
      } catch (e) {
        if (mounted) _showToast('Could not print: $e', isError: true);
      } finally {
        _clearPrintingState();
      }
      return;
    }

    try {
      final Uint8List pdfBytes = await ReceiptPrinter.buildPdf(
        tx,
        storeName: _storeName, storeAddress: _storeAddress,
        storePhone: _storePhone, storeEmail: _storeEmail,
        storeGstin: _storeGstin, receiptFooter: _receiptFooter,
        taxLabel: _taxLabel, taxRate: _taxRateDisplay,
        currencySymbol: _currencySymbol, paperSize: paperSize ?? _paperSize,
        orientation: _printOrientation, layout: _invoiceLayout,
        storeTerms: _storeTerms, logoPath: _logoPath,
        storeUpiId: _storeUpiId, docType: docType,
      );

      _clearPrintingState();

      final receiptName = tx.invoiceNumber != null
          ? 'Receipt-${tx.invoiceNumber}'
          : 'Receipt-${billNo(tx)}';

      final pdfFile = File('/tmp/$receiptName.pdf');
      await pdfFile.writeAsBytes(pdfBytes);
      if (toPrinter) {
        // lpr sends directly to the selected printer silently — no UI opens.
        // printerNameOverride lets the Printer Settings "Print Test Page" target
        // the printer picked in the dialog before it has been saved.
        final target = printerNameOverride ?? _selectedPrinter;
        final problem = await _printViaCups(pdfFile.path, target, raw: false);
        if (problem != null && mounted) {
          _showToast('Could not print: $problem', isError: true);
        }
      } else {
        final result = await Process.run('/usr/bin/osascript',['-e',
  'tell application "Preview" to activate\n'
  'tell application "Preview" to open POSIX file "${pdfFile.path}"\n'
  'delay 1\n'
  'tell application "System Events" to keystroke "p" using command down',
]);
        if (result.exitCode != 0 && mounted) {
          _showToast('Could not print: ${result.stderr}', isError: true);
        }
      }
    } catch (e) {
      if (mounted) _showToast('Could not open PDF: $e', isError: true);
    } finally {
      _clearPrintingState();
    }
  }

  TransactionRecord _testReceipt() => TransactionRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerName: 'Test Customer',
        items: const [
          TransactionItem(productId: '1', productName: 'Sample Product A', price: 250, quantity: 2),
          TransactionItem(productId: '2', productName: 'Sample Product B', price: 180, quantity: 1),
        ],
        subtotal: 680,
        discountAmount: 0,
        taxAmount: 102,
        total: 782,
        paymentMethod: 'cash',
        createdAt: DateTime.now(),
      );

  void _closeBill(BuildContext context, CartProvider cart) {
    bool sendWaAfterClose = false;
    final hasPhone = cart.customerPhone.isNotEmpty;
    final hasWa = _waPhoneNumberId.isNotEmpty && _waAccessToken.isNotEmpty;
    final total = cart.total;
    final paidCtrl = TextEditingController(text: total.toStringAsFixed(2));
    final paidFocus = FocusNode();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final paid = double.tryParse(paidCtrl.text) ?? total;
          final credit = (total - paid).clamp(0.0, total);
          final change = (paid - total).clamp(0.0, double.infinity);
          return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 24),
            const SizedBox(width: 8),
            Text('Confirm Payment',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  Text(_fmtComma(total), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              // Amount Paid field
              Text('Amount Paid', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1)),
              const SizedBox(height: 6),
              TextField(
                controller: paidCtrl,
                focusNode: paidFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '$_currencySymbol ',
                  prefixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setLocal(() {}),
              ),
              if (credit > 0 || change > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: credit > 0 ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(credit > 0 ? 'Credit (due)' : 'Change',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                              color: credit > 0 ? const Color(0xFFE65100) : AppColors.success)),
                      Text(_fmtComma(credit > 0 ? credit : change),
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800,
                              color: credit > 0 ? const Color(0xFFE65100) : AppColors.success)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${cart.itemCount} item(s)',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
              ),
              if (hasPhone && hasWa) ...[
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => setLocal(() => sendWaAfterClose = !sendWaAfterClose),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: sendWaAfterClose
                          ? const Color(0xFF25D366).withValues(alpha: 0.08)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sendWaAfterClose
                              ? const Color(0xFF25D366)
                              : const Color(0xFFE0E0E0)),
                    ),
                    child: Row(children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 15,
                          color: sendWaAfterClose ? const Color(0xFF1AAD56) : AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Send invoice via WhatsApp',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500,
                              color: sendWaAfterClose ? const Color(0xFF1AAD56) : AppColors.textMuted))),
                      Switch(
                        value: sendWaAfterClose,
                        onChanged: (v) => setLocal(() => sendWaAfterClose = v),
                        activeTrackColor: const Color(0xFF25D366),
                        activeThumbColor: Colors.white,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ]),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: () async {
                final invNum = _queuedInvoiceNo.isNotEmpty ? _queuedInvoiceNo : LocalDbService.generateInvoiceId();
                final txId = _queuedTransactionId.isNotEmpty ? _queuedTransactionId : Uuid().v4();
                final snapshot = _snapshotCart(cart, invoiceNumber: invNum, transactionId: txId);
                final phone = cart.customerPhone;
                final creditDue = (total - (double.tryParse(paidCtrl.text) ?? total)).clamp(0.0, total);
                Navigator.pop(ctx);
                await cart.checkout(invoiceNumber: invNum, transactionId: txId);
                if (creditDue > 0 && phone.isNotEmpty) {
                  await LocalDbService.addCreditToCustomer(phone, creditDue);
                }
                await ConnectivityService.instance.syncNow();
                _refreshQueuedInvoiceNo();
                _customerNameCtrl.clear();
                _customerPhoneCtrl.clear();
                _loadProducts();
                _loadDashboardData();
                if (!context.mounted) return;
                if (creditDue > 0) {
                  _showToast('Bill closed · $_currencySymbol${creditDue.toStringAsFixed(2)} credit recorded');
                } else {
                  _showToast('Payment successful!');
                }
                if (_autoPrint) {
                  await _printRecord(snapshot);
                }
                _autoSavePdf(snapshot);
                if (sendWaAfterClose) {
                  _sendInvoiceViaWhatsApp(snapshot, phone);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Confirm',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        );
        }
      ),
    );
    Future.microtask(() => paidFocus.requestFocus());
  }

  Future<void> _autoSavePdf(TransactionRecord tx) async {
    try {
      final pdfBytes = await ReceiptPrinter.buildPdf(
        tx,
        storeName: _storeName, storeAddress: _storeAddress,
        storePhone: _storePhone, storeEmail: _storeEmail,
        storeGstin: _storeGstin, receiptFooter: _receiptFooter,
        taxLabel: _taxLabel, taxRate: _taxRateDisplay,
        currencySymbol: _currencySymbol, paperSize: _paperSize,
        orientation: _printOrientation, layout: _invoiceLayout,
        storeTerms: _storeTerms, logoPath: _logoPath,
        storeUpiId: _storeUpiId,
      );
      final home = Platform.environment['HOME'] ?? '';
      final safeName = _storeName.trim().isEmpty ? 'BillCat' : _storeName.trim();
      final folder = Directory('$home/Documents/$safeName Receipts');
      if (!folder.existsSync()) folder.createSync(recursive: true);
      final receiptName = tx.invoiceNumber != null
          ? 'Receipt-${tx.invoiceNumber}'
          : 'Receipt-${billNo(tx)}';
      await File('${folder.path}/$receiptName.pdf').writeAsBytes(pdfBytes);
    } catch (_) {}
  }

  String _esc(String? s) => (s ?? '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  String _buildReceiptHtml(TransactionRecord tx, {String docType = 'Invoice'}) {
    final sym = _currencySymbol;
    final invoiceNo = _esc(billNo(tx));
    final date = tx.createdAt;
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final timeStr = '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
    final itemRows = tx.items.map((item) {
      final name = _esc(item.productName);
      final qty = item.quantity;
      final price = item.price.toStringAsFixed(2);
      final total = (item.price * item.quantity).toStringAsFixed(2);
      return '<tr><td>$name</td><td class="center">$qty</td><td class="right">$sym$price</td><td class="right">$sym$total</td></tr>';
    }).join();
    final subtotal = tx.subtotal.toStringAsFixed(2);
    final discount = tx.discountAmount;
    final tax = tx.taxAmount;
    final total = tx.total.toStringAsFixed(2);
    final storeName = _esc(_storeName);
    final initial = storeName.isEmpty ? 'B' : storeName[0].toUpperCase();

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$docType #$invoiceNo — $storeName</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Inter',sans-serif;background:#f0f4f8;color:#1a1a2e;min-height:100vh;padding:24px 16px}
.card{background:#fff;max-width:540px;margin:0 auto;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)}
.header{background:#006e25;padding:28px 28px 24px;color:#fff}
.header-top{display:flex;align-items:center;gap:14px;margin-bottom:16px}
.logo{width:52px;height:52px;border-radius:10px;background:rgba(255,255,255,.2);display:flex;align-items:center;justify-content:center;font-size:22px;font-weight:800;color:#fff}
.store-name{font-size:20px;font-weight:700}
.store-sub{font-size:12px;color:rgba(255,255,255,.75);margin-top:2px}
.badge{background:rgba(255,255,255,.18);border-radius:8px;padding:10px 16px;display:flex;justify-content:space-between;align-items:center}
.inv-label{font-size:11px;font-weight:600;color:rgba(255,255,255,.7);text-transform:uppercase;letter-spacing:.6px}
.inv-no{font-size:17px;font-weight:700}
.inv-date{font-size:12px;color:rgba(255,255,255,.8);text-align:right}
.body{padding:24px 28px}
.sec{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.8px;color:#8a9bb0;margin-bottom:8px}
.cust{background:#f7fafc;border-radius:10px;padding:12px 16px;margin-bottom:20px}
.cust-name{font-size:15px;font-weight:600}
.cust-ph{font-size:12px;color:#8a9bb0;margin-top:2px}
table{width:100%;border-collapse:collapse;margin-bottom:4px}
thead tr{border-bottom:1px solid #e8edf2}
thead th{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.6px;color:#8a9bb0;padding:6px 4px;text-align:left}
th.center,td.center{text-align:center}th.right,td.right{text-align:right}
tbody tr{border-bottom:1px solid #f0f4f8}
tbody td{font-size:13px;padding:10px 4px;vertical-align:top}
.totals{margin-top:12px;border-top:1px solid #e8edf2;padding-top:12px}
.row{display:flex;justify-content:space-between;font-size:13px;color:#4a5568;margin-bottom:6px}
.row.grand{font-size:16px;font-weight:700;color:#1a1a2e;margin-top:8px;padding-top:8px;border-top:2px solid #e8edf2}
.paid{display:inline-block;background:#e6f4ea;color:#006e25;font-size:11px;font-weight:700;padding:4px 10px;border-radius:20px;margin-bottom:20px}
.pm{font-size:12px;color:#8a9bb0;margin-bottom:20px}
.divider{height:1px;background:#e8edf2;margin:16px 0}
.powered{margin-top:20px;text-align:center;font-size:11px;color:#b0bec5}
.powered a{color:#006e25;font-weight:600;text-decoration:none}
</style>
</head>
<body>
<div class="card">
  <div class="header">
    <div class="header-top">
      <div class="logo">$initial</div>
      <div><div class="store-name">$storeName</div>${_esc(_storeAddress).isNotEmpty ? '<div class="store-sub">${_esc(_storeAddress)}</div>' : ''}</div>
    </div>
    <div class="badge">
      <div><div class="inv-label">$docType</div><div class="inv-no">#$invoiceNo</div></div>
      <div class="inv-date"><div>$dateStr</div><div>$timeStr</div></div>
    </div>
  </div>
  <div class="body">
    ${tx.customerName?.isNotEmpty == true ? '<div class="sec">Bill To</div><div class="cust"><div class="cust-name">${_esc(tx.customerName)}</div>${tx.customerPhone?.isNotEmpty == true ? '<div class="cust-ph">${_esc(tx.customerPhone)}</div>' : ''}</div>' : ''}
    <div class="sec">Items</div>
    <table>
      <thead><tr><th>Item</th><th class="center">Qty</th><th class="right">Price</th><th class="right">Total</th></tr></thead>
      <tbody>$itemRows</tbody>
    </table>
    <div class="totals">
      <div class="row"><span>Subtotal</span><span>$sym$subtotal</span></div>
      ${discount > 0 ? '<div class="row"><span>Discount</span><span>-$sym${discount.toStringAsFixed(2)}</span></div>' : ''}
      ${tax > 0 ? '<div class="row"><span>$_taxLabel</span><span>$sym${tax.toStringAsFixed(2)}</span></div>' : ''}
      <div class="row grand"><span>Total</span><span>$sym$total</span></div>
    </div>
    <div class="divider"></div>
    <div class="paid">✓ PAID</div>
    <div class="pm">Payment via ${_esc(tx.paymentMethod)}</div>
    <div class="powered">Powered by <a href="https://billcat.in">BillCat</a></div>
  </div>
</div>
</body>
</html>''';
  }

  Future<void> _sendInvoiceViaWhatsApp(TransactionRecord tx, String phone, {String docType = 'Invoice'}) async {
    if (phone.isEmpty) {
      _showToast('No customer phone number to send to.', isError: true);
      return;
    }

    // Use tx.id prefix — matches Supabase's id column, website has id-prefix fallback query
    final invoiceNo = tx.id.replaceAll('-', '').substring(0, 6).toLowerCase();

    // Generate link immediately, sync in background
    final rawUid = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
    final shortUid = rawUid.replaceAll('-', '').substring(0, 6).toLowerCase();
    final branchPadded = _branchNumber.padLeft(2, '0');
    final invoiceLink = 'https://billcat.in/invoices/$shortUid$branchPadded$invoiceNo';
    ConnectivityService.instance.syncNow().ignore();

    // If Meta API is configured, send directly
    if (_waPhoneNumberId.isNotEmpty && _waAccessToken.isNotEmpty) {
      _showToast('Sending via WhatsApp...');
      try {
        final pdfBytes = await ReceiptPrinter.buildPdf(
          tx,
          storeName: _storeName, storeAddress: _storeAddress,
          storePhone: _storePhone, storeEmail: _storeEmail,
          storeGstin: _storeGstin, receiptFooter: _receiptFooter,
          taxLabel: _taxLabel, taxRate: _taxRateDisplay,
          currencySymbol: _currencySymbol, paperSize: _paperSize,
          orientation: _printOrientation, layout: _invoiceLayout,
          storeTerms: _storeTerms, logoPath: _logoPath,
          storeUpiId: _storeUpiId, docType: docType,
        );
        final svc = _wa.WhatsAppService(
            phoneNumberId: _waPhoneNumberId, accessToken: _waAccessToken);
        final ok = await svc.sendInvoicePdf(
          toPhone: phone,
          pdfBytes: pdfBytes,
          invoiceNo: invoiceNo,
          storeName: _storeName,
          customerName: tx.customerName ?? '',
          amount: '$_currencySymbol${tx.total.toStringAsFixed(2)}',
          date: '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
          docType: docType,
          invoiceLink: invoiceLink,
        );
        if (mounted) _showToast(ok ? 'Invoice sent via WhatsApp!' : 'WhatsApp send failed.', isError: !ok);
      } catch (e) {
        if (mounted) _showToast('WhatsApp error: $e', isError: true);
      }
      return;
    }

    // Fallback: open WhatsApp Web with pre-filled message
    try {
      // Normalize: strip formatting, prepend dial code if no country code present
      String normalized = phone.replaceAll(RegExp(r'[\s\-().]'), '');
      if (!normalized.startsWith('+') && !normalized.startsWith('00')) {
        normalized = _dialCode + normalized.replaceFirst(RegExp(r'^0'), '');
      }
      normalized = normalized.replaceAll('+', '');

      final customerName = (tx.customerName?.isNotEmpty ?? false) ? tx.customerName! : 'Valued Customer';
      final dateStr = '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}';
      final message = Uri.encodeComponent(
        'Hello $customerName,\n\n'
        'Thank you for choosing $_storeName.\n'
        'Your e-bill for $docType #$invoiceNo has been generated successfully.\n\n'
        'Amount: $_currencySymbol${tx.total.toStringAsFixed(2)}\n'
        'Date: $dateStr\n'
        'Payment Status: Paid\n\n'
        'For any queries, feel free to contact us.\n'
        'Thank you for your support!\n\n'
        '— $_storeName'
        '${invoiceLink.isNotEmpty ? '\n\nView your bill: $invoiceLink' : ''}',
      );
      final url = 'https://web.whatsapp.com/send?phone=$normalized&text=$message';
      // Reuse existing WhatsApp Web tab in Chrome if open, else open new tab
      final appleScript = '''
tell application "Google Chrome"
  set didReuse to false
  repeat with w in windows
    set tabIdx to 0
    repeat with t in tabs of w
      set tabIdx to tabIdx + 1
      if (URL of t) starts with "https://web.whatsapp.com" then
        set URL of t to "$url"
        set index of w to 1
        set active tab index of w to tabIdx
        set didReuse to true
        exit repeat
      end if
    end repeat
    if didReuse then exit repeat
  end repeat
  if not didReuse then
    if (count of windows) > 0 then
      tell front window to make new tab with properties {URL:"$url"}
    else
      open location "$url"
    end if
  end if
  activate
end tell
''';
      final result = await Process.run('/usr/bin/osascript',['-e', appleScript]);
      if (result.exitCode != 0) {
        // Fallback if Chrome isn't running
        await Process.run('/usr/bin/open', [url]);
      }

      if (mounted) _showToast('Opening WhatsApp Web...');
    } catch (e) {
      if (mounted) _showToast('Error: $e', isError: true);
    }
  }

  void _showAddCustomerDialog(CartProvider cart) {
    final nameCtrl = TextEditingController(text: _customerNameCtrl.text);
    final phoneCtrl = TextEditingController(text: _customerPhoneCtrl.text);
    final addressCtrl = TextEditingController();
    final phoneFocus = FocusNode();
    final addressFocus = FocusNode();

    Future<void> doSave(BuildContext ctx) async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      await LocalDbService.upsertCustomerByPhone(
        name: name,
        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
      );
      _customerNameCtrl.text = name;
      _customerPhoneCtrl.text = phoneCtrl.text.trim();
      cart.customerName = name;
      cart.customerPhone = phoneCtrl.text.trim();
      if (ConnectivityService.instance.isOnline) {
        ConnectivityService.instance.syncNow();
      }
      if (context.mounted) {
        Navigator.pop(ctx);
        _showToast('Customer saved!');
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text('Add Customer', style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                    style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                  ),
                ]),
              ),
              // ── Fields ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _dlgLabel('CUSTOMER NAME'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      if (phoneCtrl.text.trim().isNotEmpty) {
                        doSave(ctx);
                      } else {
                        phoneFocus.requestFocus();
                      }
                    },
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                    decoration: _dlgInputDecor('e.g. Ravi Kumar'),
                  ),
                  const SizedBox(height: 16),
                  _dlgLabel('PHONE NUMBER'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    focusNode: phoneFocus,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => doSave(ctx),
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                    decoration: _dlgInputDecor('e.g. 9876543210'),
                  ),
                  const SizedBox(height: 16),
                  _dlgLabel('ADDRESS (OPTIONAL)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addressCtrl,
                    focusNode: addressFocus,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => doSave(ctx),
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                    decoration: _dlgInputDecor('Street, city…'),
                  ),
                  const SizedBox(height: 24),
                  // ── Actions ───────────────────────────────────────────
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => doSave(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Save Customer',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomProductDialog(CartProvider cart) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Custom Product',
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9.]'))
                ],
                decoration: InputDecoration(
                    labelText: 'Price',
                    prefixText: '\$',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10)))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price =
                  double.tryParse(priceCtrl.text) ?? 0;
              if (name.isNotEmpty && price > 0) {
                cart.addProduct(Product(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  name: name,
                  price: price,
                  category: 'Custom',
                  emoji: '📦',
                  sku: 'CUSTOM',
                  stock: 99,
                ));
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Add',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Bulk Barcode Print View ──────────────────────────────────────────────────

  // Live printer connection status. macOS: parse `lpstat -l -p` and look for the
  // `offline-report` alert CUPS raises when a USB/network printer is unreachable.
  // Returns a map keyed by printer display name → true (online) / false (offline).
  /// Returns each printer's status: 'online', 'paused' (queue disabled/stopped by
  /// the user), or 'offline' (unreachable / not responding). Absent = unknown.
  Future<Map<String, String>> _fetchPrinterStatusMap() async {
    final map = <String, String>{};
    if (!Platform.isMacOS) return map;
    try {
      final res = await Process.run('/usr/bin/lpstat', ['-l', '-p'])
          .timeout(const Duration(seconds: 3));
      final lines = '${res.stdout}'.split('\n');
      String? current;
      String status = 'online';
      void commit() {
        if (current != null) map[current!.replaceAll('_', ' ')] = status;
      }
      bool looksOffline(String s) =>
          s.contains('offline') || s.contains('not responding') ||
          s.contains('connecting') || s.contains('unplugged') ||
          s.contains('rejecting') || s.contains('powered off');
      for (final line in lines) {
        final m = RegExp(r'^printer (\S+) (.+)$').firstMatch(line);
        if (m != null) {
          commit();
          current = m.group(1);
          final rest = (m.group(2) ?? '').toLowerCase();
          if (rest.contains('disabled') || rest.contains('stopped')) {
            status = looksOffline(rest) ? 'offline' : 'paused';
          } else {
            status = 'online'; // idle / processing / enabled
          }
        } else {
          final l = line.trimLeft().toLowerCase();
          if (l.startsWith('alerts:') || l.startsWith('reasons:')) {
            if (looksOffline(l)) {
              status = 'offline';
            } else if (status == 'online' && (l.contains('paused') || l.contains('stopped'))) {
              status = 'paused';
            }
          }
        }
      }
      commit();
    } catch (_) {}
    return map;
  }

  // ── Label printer setup (raw TSPL/ZPL over TCP:9100) ───────────────────────
  Future<void> _showLabelPrinterSetup() {
    var profile = LabelPrinterService.cached;
    final hostCtrl = TextEditingController(text: profile.host);
    final portCtrl = TextEditingController(text: '${profile.port}');
    var usbQueues = <String>[];
    var queuesTried = false;
    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final isNetwork = profile.transport == LabelTransport.network;
        final isUsb = profile.transport == LabelTransport.usb;
        if (!queuesTried) {
          queuesTried = true;
          LabelPrinterService.listQueues().then((q) {
            if (ctx.mounted) setLocal(() => usbQueues = q);
          });
        }
        InputDecoration dec(String hint) => InputDecoration(
          isDense: true, hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        );
        Widget modeChip(String label, IconData icon, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
              ),
              child: Column(children: [
                Icon(icon, size: 20, color: selected ? AppColors.primary : AppColors.textMuted),
                const SizedBox(height: 5),
                Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textDark)),
              ]),
            ),
          ),
        );
        LabelSpec currentSpec() => LabelSpec(
          labelWmm: _barcodeLabelW, labelHmm: _barcodeLabelH, columns: _barcodePerRow, gapMm: 2.0);
        LabelPrinterProfile buildProfile() => profile.copyWith(
          host: hostCtrl.text.trim(),
          port: int.tryParse(portCtrl.text.trim()) ?? 9100,
        );
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(width: 440, child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.settings_ethernet_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('Label Printer Setup', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const Spacer(),
                InkWell(onTap: () => Navigator.pop(ctx), borderRadius: BorderRadius.circular(7),
                  child: Container(width: 26, height: 26, decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted))),
              ]),
              const SizedBox(height: 4),
              Text('Raw mode sends the printer its native language (TSPL/ZPL) — pixel-perfect, no driver needed. Best for GODEX/TSC/TVS.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              Row(children: [
                modeChip('System\n(PDF)', Icons.picture_as_pdf_outlined, !isNetwork && !isUsb,
                    () => setLocal(() => profile = profile.copyWith(transport: LabelTransport.pdf))),
                const SizedBox(width: 8),
                modeChip('USB\n(Raw)', Icons.usb_rounded, isUsb,
                    () => setLocal(() => profile = profile.copyWith(transport: LabelTransport.usb))),
                const SizedBox(width: 8),
                modeChip('Network\n(Raw)', Icons.lan_outlined, isNetwork,
                    () => setLocal(() => profile = profile.copyWith(transport: LabelTransport.network))),
              ]),
              if (isNetwork || isUsb) ...[
                const SizedBox(height: 16),
                if (isUsb) ...[
                  Text('USB PRINTER', style: _fieldMiniLabel()),
                  const SizedBox(height: 6),
                  Container(
                    height: 42, padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                      value: usbQueues.contains(profile.queue) ? profile.queue : null,
                      isExpanded: true, isDense: true,
                      hint: Text(usbQueues.isEmpty ? 'Loading printers…' : 'Select your label printer',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                      items: usbQueues.map((q) => DropdownMenuItem(value: q,
                        child: Text(q.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setLocal(() => profile = profile.copyWith(queue: v)),
                    )),
                  ),
                ] else ...[
                  Text('PRINTER IP ADDRESS', style: _fieldMiniLabel()),
                  const SizedBox(height: 6),
                  TextField(controller: hostCtrl, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark), decoration: dec('192.168.1.50')),
                ],
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (isNetwork) ...[
                    SizedBox(width: 90, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PORT', style: _fieldMiniLabel()), const SizedBox(height: 6),
                      TextField(controller: portCtrl, keyboardType: TextInputType.number, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark), decoration: dec('9100')),
                    ])),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('LANGUAGE', style: _fieldMiniLabel()), const SizedBox(height: 6),
                    Container(
                      height: 42, padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
                      child: DropdownButtonHideUnderline(child: DropdownButton<LabelLanguage>(
                        value: profile.language, isExpanded: true, isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                        items: LabelLanguage.values.map((l) => DropdownMenuItem(value: l,
                          child: Text(l.label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setLocal(() => profile = profile.copyWith(language: v)),
                      )),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  SizedBox(width: 80, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('DPI', style: _fieldMiniLabel()), const SizedBox(height: 6),
                    Container(
                      height: 42, padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
                      child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                        value: profile.dpi, isExpanded: true, isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                        items: const [203, 300].map((d) => DropdownMenuItem(value: d,
                          child: Text('$d', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)))).toList(),
                        onChanged: (v) => setLocal(() => profile = profile.copyWith(dpi: v)),
                      )),
                    ),
                  ])),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(9)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(isUsb
                        ? 'Uses label Size (${_barcodeLabelW.toStringAsFixed(0)}×${_barcodeLabelH.toStringAsFixed(0)}mm) and Per Row ($_barcodePerRow) from Print Barcodes. Bypasses the printer driver entirely — works even without a Mac driver.'
                        : 'Uses label Size (${_barcodeLabelW.toStringAsFixed(0)}×${_barcodeLabelH.toStringAsFixed(0)}mm) and Per Row ($_barcodePerRow) from Print Barcodes. Give the printer a fixed IP on your router.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.primary, height: 1.4))),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () async {
                    final p = buildProfile();
                    if (isUsb && p.queue.isEmpty) { _showToast('Select your USB printer first', isError: true); return; }
                    if (isNetwork && p.host.isEmpty) { _showToast('Enter the printer IP first', isError: true); return; }
                    final dest = isUsb ? p.queue : p.host;
                    try {
                      await LabelPrinterService.printTestLabel(currentSpec(), p);
                      if (mounted) _showToast('Test label sent to $dest');
                    } catch (e) {
                      if (mounted) _showToast('Print failed: $e', isError: true);
                    }
                  },
                  icon: const Icon(Icons.science_outlined, size: 16),
                  label: Text('Print Test Label', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
              ],
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textMuted, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    await LabelPrinterService.save(buildProfile());
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _showToast('Label printer saved');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text('Save', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)))),
              ]),
            ]),
          )),
        );
      }),
    );
  }

  TextStyle _fieldMiniLabel() => GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.6);

  /// Expands products into one printable barcode label per variant (each with
  /// its own SKU, barcode and price); a product without variants yields one.
  List<_BarcodeTarget> _barcodeTargets() {
    final out = <_BarcodeTarget>[];
    for (final p in _products) {
      if (p.variants.isEmpty) {
        out.add(_BarcodeTarget(
          key: p.id, name: p.name, sku: p.sku,
          barcodeValue: p.barcodeNo.isNotEmpty ? p.barcodeNo : p.sku,
          stock: p.stock, price: p.price));
      } else {
        for (final v in p.variants) {
          final vsku = v.sku.isNotEmpty ? v.sku : p.sku;
          out.add(_BarcodeTarget(
            key: '${p.id}::${v.id}', name: '${p.name} ${v.name}', sku: vsku,
            barcodeValue: v.barcodeNo.isNotEmpty ? v.barcodeNo : vsku,
            stock: v.stock, price: v.price));
        }
      }
    }
    return out;
  }

  void _showBulkPrintDialog() {
    final labelWCtrl  = TextEditingController(text: _barcodeLabelW.toStringAsFixed(_barcodeLabelW == _barcodeLabelW.truncateToDouble() ? 0 : 1));
    final labelHCtrl  = TextEditingController(text: _barcodeLabelH.toStringAsFixed(_barcodeLabelH == _barcodeLabelH.truncateToDouble() ? 0 : 1));
    final perRowCtrl  = TextEditingController(text: '$_barcodePerRow');
    final searchCtrl  = TextEditingController();
    final targets     = _barcodeTargets();
    final qtys        = <String, int>{ for (final t in targets) t.key: t.stock > 0 ? t.stock : 1 };
    final selected    = <String, bool>{};
    var printers      = <String>['System Default'];
    var printerObjects = <Printer>[];
    var printerStatus = <String, String>{}; // name → 'online' | 'paused' | 'offline'
    String printer    = _barcodePrinter;
    String searchQ    = '';
    Timer? statusTimer;

    // Per-label qty controllers, keyed by target (product or variant).
    final qtyCtrlMap = <String, TextEditingController>{
      for (final t in targets) t.key: TextEditingController(text: '${qtys[t.key]}'),
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        void refreshPrinters() {
          Printing.listPrinters().then((list) async {
            final names = <String>['System Default', ...list.map((p) => p.name)];
            final status = await _fetchPrinterStatusMap();
            if (ctx.mounted) setLocal(() {
              printers = names;
              printerObjects = list;
              printerStatus = status;
              // NOTE: never reassign `printer` here — the status timer calls this
              // every few seconds and doing so would clobber the user's selection.
            });
          });
        }
        if (printers.length <= 1) refreshPrinters();
        statusTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
          if (ctx.mounted) {
            refreshPrinters();
          } else {
            statusTimer?.cancel();
          }
        });
        final filteredTargets = searchQ.isEmpty
          ? targets
          : targets.where((t) {
              final q = searchQ.toLowerCase();
              return t.name.toLowerCase().contains(q) || t.sku.toLowerCase().contains(q);
            }).toList();
        final total = targets.where((t) => selected[t.key] == true).fold<int>(0, (s, t) => s + (qtys[t.key] ?? 0));

        Future<void> doPrint() async {
          if (!(total > 0 && printerStatus[printer] != 'offline')) return;
          final w = double.tryParse(labelWCtrl.text) ?? _barcodeLabelW;
          final h = double.tryParse(labelHCtrl.text) ?? _barcodeLabelH;
          final perRow = int.tryParse(perRowCtrl.text) ?? _barcodePerRow;
          Navigator.pop(ctx);
          setState(() { _barcodeLabelW = w; _barcodeLabelH = h; _barcodePerRow = perRow; _barcodePrinter = printer; });
          LabelPrinterService.saveBarcodeSettings({'labelW': w, 'labelH': h, 'perRow': perRow, 'printer': printer});
          final selTargets = targets.where((t) => selected[t.key] == true).toList();
          await _printAllBarcodesWithQty(selTargets, qtys, labelW: w, labelH: h, labelsPerRow: perRow, printerName: printer);
        }

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter): doPrint,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): doPrint,
          },
          child: Focus(
          autofocus: true,
          child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
          child: SizedBox(
            width: 620,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 18, 16),
                child: Row(children: [
                  Text('Print Barcodes', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(width: 28, height: 28,
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.close_rounded, size: 15, color: AppColors.textMuted)),
                  ),
                ]),
              ),
              // ── Settings bar ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Text('Size', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  const SizedBox(width: 7),
                  _miniNumField(labelWCtrl, 'W', 60),
                  const SizedBox(width: 5),
                  _miniNumField(labelHCtrl, 'H', 60),
                  const SizedBox(width: 16),
                  Text('Per Row', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  const SizedBox(width: 7),
                  _miniNumField(perRowCtrl, '', 44),
                  const SizedBox(width: 16),
                  const Icon(Icons.print_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                    value: printers.contains(printer) ? printer : 'System Default',
                    isDense: true, isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textMuted),
                    items: printers.map((n) {
                      Color dotColor;
                      String? statusLabel;
                      if (n == 'System Default') {
                        dotColor = const Color(0xFF8E8E93);
                      } else {
                        switch (printerStatus[n]) {
                          case 'online':
                            dotColor = const Color(0xFF34C759); break;   // green
                          case 'paused':
                            dotColor = const Color(0xFFFF9500); statusLabel = 'paused'; break; // orange
                          case 'offline':
                            dotColor = const Color(0xFFFF3B30); statusLabel = 'offline'; break; // red
                          default:
                            dotColor = const Color(0xFF8E8E93);          // grey / unknown
                        }
                      }
                      return DropdownMenuItem(value: n,
                        child: Row(children: [
                          Container(width: 7, height: 7,
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(n, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark), overflow: TextOverflow.ellipsis)),
                          if (statusLabel != null) ...[
                            const SizedBox(width: 6),
                            Text(statusLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: dotColor)),
                          ],
                        ]));
                    }).toList(),
                    onChanged: (v) => setLocal(() => printer = v ?? 'System Default'),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                  ))),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Raw label printer setup (USB / network)',
                    child: InkWell(
                      onTap: () async { await _showLabelPrinterSetup(); setLocal(() {}); },
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: LabelPrinterService.cached.isRaw ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: LabelPrinterService.cached.isRaw ? AppColors.primary : AppColors.border),
                        ),
                        child: Icon(Icons.settings_ethernet_rounded, size: 15,
                            color: LabelPrinterService.cached.isRaw ? AppColors.primary : AppColors.textMuted),
                      ),
                    ),
                  ),
                ]),
              ),
              // ── Search bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 10),
                    const Icon(Icons.search_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      controller: searchCtrl,
                      onChanged: (v) => setLocal(() => searchQ = v),
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        isDense: true, border: InputBorder.none,
                        hintText: 'Search products…',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                        contentPadding: EdgeInsets.zero,
                      ),
                    )),
                    if (searchQ.isNotEmpty) InkWell(
                      onTap: () { searchCtrl.clear(); setLocal(() => searchQ = ''); },
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(padding: EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted)),
                    ),
                    const SizedBox(width: 6),
                  ]),
                ),
              ),
              // ── Products grid ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: filteredTargets.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off_rounded, size: 32, color: AppColors.textMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text('No products found', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                        ])),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: filteredTargets.length,
                        itemBuilder: (_, i) {
                          final t = filteredTargets[i];
                          final isSelected = selected[t.key] == true;
                          final qty = qtys[t.key] ?? 1;
                          final qtyCtrl = qtyCtrlMap[t.key] ??= TextEditingController(text: '$qty');
                          return GestureDetector(
                            onTap: () {
                              setLocal(() {
                                if (isSelected) {
                                  selected[t.key] = false;
                                } else {
                                  selected[t.key] = true;
                                  if (!qtys.containsKey(t.key)) {
                                    qtys[t.key] = t.stock > 0 ? t.stock : 1;
                                    qtyCtrlMap[t.key]?.text = '${qtys[t.key]}';
                                  }
                                }
                              });
                            },
                            child: Stack(children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 14),
                                      child: Text(t.name,
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                                          color: isSelected ? AppColors.primary : AppColors.textDark),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      width: double.infinity, height: 30,
                                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(5)),
                                      child: CustomPaint(painter: _BarcodePainter(t.barcodeValue))),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Expanded(child: Text(t.sku, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Text('$_currencySymbol${t.price.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                    ]),
                                    const Spacer(),
                                    if (isSelected) Container(
                                      height: 28,
                                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(7)),
                                      child: Row(children: [
                                        InkWell(
                                          onTap: qty > 1 ? () { setLocal(() => qtys[t.key] = qty - 1); qtyCtrl.text = '${qty - 1}'; } : null,
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                                          child: Container(width: 26, height: 28, alignment: Alignment.center,
                                            child: Icon(Icons.remove_rounded, size: 11, color: qty > 1 ? AppColors.textDark : AppColors.textMuted))),
                                        Container(width: 1, height: 16, color: AppColors.border),
                                        Expanded(child: TextFormField(
                                          controller: qtyCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                                          decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                          onChanged: (v) { final n = int.tryParse(v); if (n != null && n > 0) setLocal(() => qtys[t.key] = n); },
                                        )),
                                        Container(width: 1, height: 16, color: AppColors.border),
                                        InkWell(
                                          onTap: () { setLocal(() => qtys[t.key] = qty + 1); qtyCtrl.text = '${qty + 1}'; },
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                                          child: Container(width: 26, height: 28, alignment: Alignment.center,
                                            child: const Icon(Icons.add_rounded, size: 11, color: AppColors.textDark))),
                                      ]),
                                    ) else Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('${t.stock} in stock',
                                        style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                                    ),
                                  ]),
                                ),
                              ),
                              if (isSelected) Positioned(
                                top: 6, right: 6,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
                ),
              ),
              const SizedBox(height: 4),
              // ── Footer ──
              Builder(builder: (_) {
              final isDefault = printer == 'System Default';
              final stat = printerStatus[printer];
              final isOffline = stat == 'offline';
              final isPaused = stat == 'paused';
              // System Default falls back to the OS default printer; only block
              // when there's nothing to print or the chosen printer is offline.
              final canPrint = total > 0 && !isOffline;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(children: [
                  Flexible(child: Text(
                      isOffline
                          ? '$printer is offline — connect it to print'
                          : isPaused
                              ? '$printer is paused — resume it to print (job will queue)'
                              : isDefault
                                  ? '$total label${total != 1 ? 's' : ''} → system default printer'
                                  : '$total label${total != 1 ? 's' : ''} to print',
                      style: GoogleFonts.inter(fontSize: 12,
                          color: isOffline ? const Color(0xFFFF3B30)
                              : isPaused ? const Color(0xFFFF9500) : AppColors.textMuted),
                      overflow: TextOverflow.ellipsis)),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: !canPrint ? null : doPrint,
                    icon: const Icon(Icons.print_rounded, size: 15),
                    label: Text('Print $total Label${total != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ]),
              );
              }),
            ]),
          ),
          ),
          ),
        );
      }),
    ).then((_) => statusTimer?.cancel());
  }

  Widget _miniNumField(TextEditingController ctrl, String suffix, double width) => Container(
    width: width,
    height: 30,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Expanded(child: TextFormField(
        controller: ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
        decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4)),
      )),
      if (suffix.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 5),
        child: Text(suffix, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted))),
    ]),
  );

  Future<void> _printAllBarcodesWithQty(List<_BarcodeTarget> targets, Map<String, int> qtys,
      {double labelW = 58, double labelH = 30, int labelsPerRow = 1, String? printerName}) async {
    if (targets.isEmpty) return;

    // Raw path: if a network label printer is configured, send TSPL/ZPL straight
    // to it over TCP:9100 — pixel-perfect, no driver, no preview needed.
    final profile = LabelPrinterService.cached;
    if (profile.isRaw) {
      final dest = profile.isUsb ? profile.queue : profile.host;
      final items = <LabelItem>[
        for (final t in targets)
          LabelItem(
            barcodeValue: t.barcodeValue,
            name: t.name,
            price: '$_currencySymbol${t.price.toStringAsFixed(2)}',
            count: qtys[t.key] ?? 1,
          ),
      ];
      final spec = LabelSpec(labelWmm: labelW, labelHmm: labelH, columns: labelsPerRow, gapMm: 2.0);
      try {
        await LabelPrinterService.printBatch(items, spec, profile);
        if (mounted) _showToast('Sent to $dest');
      } catch (e) {
        if (mounted) _showToast('Printer $dest failed: $e', isError: true);
      }
      return;
    }

    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData    = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold    = pw.Font.ttf(boldData);

    final doc = pw.Document();
    // labelW x labelH = ONE sticker; page = perRow stickers, edge-to-edge so the
    // page width equals the physical liner width (e.g. 3 × 35mm = 105mm exactly).
    const gapMm = 0.0;
    const marginMm = 0.0;
    final gap = gapMm * PdfPageFormat.mm;
    final margin = marginMm * PdfPageFormat.mm;
    final cellW = labelW * PdfPageFormat.mm;
    final cellH = labelH * PdfPageFormat.mm;
    final pageW = margin * 2 + labelsPerRow * cellW + (labelsPerRow - 1) * gap;
    final pageH = cellH;
    final pageFormat = PdfPageFormat(pageW, pageH);
    final pad = 0.5 * PdfPageFormat.mm;

    // Collect all labels across all products in order
    final allLabels = <pw.Widget>[];
    for (final t in targets) {
      final count = qtys[t.key] ?? 1;
      final barcodeVal = t.barcodeValue;
      String svgStr;
      try {
        svgStr = bc.Barcode.ean13().toSvg(barcodeVal, width: 200, height: 80, drawText: false);
      } catch (_) {
        svgStr = bc.Barcode.code128().toSvg(barcodeVal, width: 200, height: 80, drawText: false);
      }
      final innerPad = 5.0 * PdfPageFormat.mm;
      pw.Widget labelCell() => pw.Container(
        width: cellW, height: cellH,
        padding: pw.EdgeInsets.symmetric(horizontal: innerPad, vertical: 1.5 * PdfPageFormat.mm),
        child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.SvgImage(svg: svgStr, width: (cellW - innerPad * 2), height: (cellH - 2 * PdfPageFormat.mm) * 0.62),
          pw.Text(t.name, style: pw.TextStyle(font: bold, fontSize: 4.5, letterSpacing: 0.4), textAlign: pw.TextAlign.center),
          pw.Text('$_currencySymbol${t.price.toStringAsFixed(2)}', style: pw.TextStyle(font: bold, fontSize: 4.5), textAlign: pw.TextAlign.center),
        ]),
      );
      for (int i = 0; i < count; i++) allLabels.add(labelCell());
    }

    for (int start = 0; start < allLabels.length; start += labelsPerRow) {
      final rowCells = allLabels.sublist(start, (start + labelsPerRow).clamp(0, allLabels.length));
      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.symmetric(horizontal: margin),
        build: (_) {
          final cells = <pw.Widget>[];
          for (int i = 0; i < rowCells.length; i++) {
            if (i > 0) cells.add(pw.SizedBox(width: gap));
            cells.add(rowCells[i]);
          }
          return pw.Row(children: cells);
        },
      ));
    }

    final bytes = await doc.save();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text('Print Preview',
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
                ),
              ]),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 260,
                  child: PdfPreview(
                    build: (_) async => bytes,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: false,
                    scrollViewDecoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
                    pdfPreviewPageDecoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () async {
                    // System Default resolves to the OS default printer in _printPdfBytes.
                    final targetPrinter = printerName ?? 'System Default';
                    Navigator.pop(ctx);
                    final sheetW = marginMm * 2 + labelsPerRow * labelW + (labelsPerRow - 1) * gapMm;
                    final sheetH = labelH;
                    await _printPdfBytes(
                      bytes: bytes,
                      printerName: targetPrinter,
                      widthPt: sheetW / 25.4 * 72,
                      heightPt: sheetH / 25.4 * 72,
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 15),
                  label: Text('Print', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Inventory View ───────────────────────────────────────────────────────────

  Widget _buildInventoryView() {
    final lowStock   = _products.where((p) => p.stock > 0 && p.stock < 10).length;
    final outOfStock = _products.where((p) => p.stock == 0).length;

    final filtered = _products.where((p) {
      final matchCat = _inventoryCategoryFilter == 'All' || p.category == _inventoryCategoryFilter;
      if (!matchCat) return false;
      if (_inventorySearchQuery.isEmpty) return true;
      final q = _inventorySearchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.barcodeNo.contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Inventory', style: GoogleFonts.manrope(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text('${_products.length} products in catalogue',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
            ]),
            const Spacer(),
            // Stats + Print Barcodes row
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _statCell('${_products.length}', 'TOTAL', AppColors.textDark, first: true),
                _statDivider(),
                _statCell('$lowStock', 'LOW STOCK', const Color(0xFFF59E0B)),
                _statDivider(),
                _statCell('$outOfStock', 'OUT OF STOCK', AppColors.error, last: true),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _inventorySearchQuery = v),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Search by name, SKU or category...',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Category chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _inventoryCategoryChip('All'),
              ..._userCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _inventoryCategoryChip(cat, editable: true),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          // Product grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 210,
                childAspectRatio: 0.82,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemCount: filtered.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return _addProductCard();
                return _inventoryCard(filtered[i - 1]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryCategoryChip(String label, {bool editable = false}) {
    final selected = _inventoryCategoryFilter == label;
    return _InventoryCatChip(
      label: label,
      selected: selected,
      editable: editable,
      onTap: () => setState(() => _inventoryCategoryFilter = label),
      onEdit: () => _showEditCategoryDialog(label),
    );
  }


  void _showEditCategoryDialog(String category) {
    final ctrl = TextEditingController(text: category);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Edit Category', style: GoogleFonts.manrope(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'Category name',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalDbService.deleteCategory(category);
              final affected = _products.where((p) => p.category == category).toList();
              for (final p in affected) {
                final updated = Product(id: p.id, name: p.name, price: p.price,
                    buyingPrice: p.buyingPrice, taxPercent: p.taxPercent,
                    category: '', emoji: p.emoji, sku: p.sku, stock: p.stock,
                    description: p.description);
                await LocalDbService.updateProduct(updated);
              }
              setState(() {
                _userCategories.remove(category);
                for (int i = 0; i < _products.length; i++) {
                  if (_products[i].category == category) {
                    _products[i] = Product(id: _products[i].id, name: _products[i].name,
                        price: _products[i].price, buyingPrice: _products[i].buyingPrice,
                        taxPercent: _products[i].taxPercent, category: '',
                        emoji: _products[i].emoji, sku: _products[i].sku, stock: _products[i].stock,
                        description: _products[i].description);
                  }
                }
                if (_inventoryCategoryFilter == category) _inventoryCategoryFilter = 'All';
              });
              ConnectivityService.instance.syncNow();
            },
            child: Text('Delete', style: GoogleFonts.inter(
                color: AppColors.error, fontWeight: FontWeight.w500)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty || newName == category) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              await LocalDbService.renameCategory(category, newName);
              final affected = _products.where((p) => p.category == category).toList();
              for (final p in affected) {
                final updated = Product(id: p.id, name: p.name, price: p.price,
                    buyingPrice: p.buyingPrice, taxPercent: p.taxPercent,
                    category: newName, emoji: p.emoji, sku: p.sku, stock: p.stock,
                    description: p.description);
                await LocalDbService.updateProduct(updated);
              }
              setState(() {
                final idx = _userCategories.indexOf(category);
                if (idx != -1) _userCategories[idx] = newName;
                for (int i = 0; i < _products.length; i++) {
                  if (_products[i].category == category) {
                    _products[i] = Product(id: _products[i].id, name: _products[i].name,
                        price: _products[i].price, buyingPrice: _products[i].buyingPrice,
                        taxPercent: _products[i].taxPercent, category: newName,
                        emoji: _products[i].emoji, sku: _products[i].sku, stock: _products[i].stock,
                        description: _products[i].description);
                  }
                }
                if (_inventoryCategoryFilter == category) _inventoryCategoryFilter = newName;
              });
              ConnectivityService.instance.syncNow();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Rename', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label, Color color, {bool first = false, bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(left: first ? 20 : 16, right: last ? 20 : 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 1),
          Text(label,
              style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 24, color: AppColors.border);

  Widget _colHeader(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.8));

  Widget _addProductCard() {
    return GestureDetector(
      onTap: _showAddProductDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 12),
            Text('Add Product',
                style: GoogleFonts.manrope(fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('Tap to add new item',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _inventoryCard(Product p) {
    final (statusLabel, statusColor, statusBg) = p.stock == 0
        ? ('Out of Stock', AppColors.error, AppColors.error.withValues(alpha: 0.08))
        : p.stock < 10
            ? ('Low Stock', const Color(0xFFF59E0B), const Color(0xFFF59E0B).withValues(alpha: 0.08))
            : ('In Stock', AppColors.success, AppColors.success.withValues(alpha: 0.08));
    final topRank = _topProductsToday.indexWhere((t) => t.$1 == p.name);
    final topMedal = topRank == 0 ? '🥇' : topRank == 1 ? '🥈' : topRank == 2 ? '🥉' : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44, height: 44,
                child: p.emoji.startsWith('/')
                    ? Image.file(File(p.emoji), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _MediumInitialsBox(name: p.name, radius: 10))
                    : _MediumInitialsBox(name: p.name, radius: 10),
              ),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded,
                  size: 16, color: AppColors.textMuted),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              color: Colors.white,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', height: 38,
                    child: Row(children: [
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Edit', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                    ])),
                PopupMenuItem(value: 'barcode', height: 38,
                    child: Row(children: [
                      const Icon(Icons.barcode_reader, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text('Print Barcode', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                    ])),
                PopupMenuItem(value: 'delete', height: 38,
                    child: Row(children: [
                      const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Delete', style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
                    ])),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  _showEditProductDialog(p);
                } else if (v == 'barcode') {
                  _showPrintBarcodeDialog(p);
                } else if (v == 'delete') {
                  _confirmDeleteProduct(p);
                }
              },
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: statusBg, borderRadius: BorderRadius.circular(100)),
              child: Text(statusLabel, style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: statusColor, letterSpacing: 0.2)),
            ),
            if (topMedal != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                ),
                child: Text('$topMedal Top', style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: const Color(0xFF9E7D00), letterSpacing: 0.2)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Text(p.name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 3),
          Text(p.sku, style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textMuted)),
          const Spacer(),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(p.category, style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.accentBlue)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text('$_currencySymbol${p.price.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(fontSize: 14,
                    fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const Spacer(),
            Text('${p.stock} ${p.unit}', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: p.stock < 10 ? AppColors.error : AppColors.textMuted)),
          ]),
        ],
      ),
    );
  }

  // ── Edit / Delete Product ─────────────────────────────────────────────────────

  void _showPrintBarcodeDialog(Product p) {
    int qty = p.stock > 0 ? p.stock : 1;
    int labelsPerRow = _barcodePerRow;
    final labelWCtrl = TextEditingController(text: _barcodeLabelW.toStringAsFixed(_barcodeLabelW == _barcodeLabelW.truncateToDouble() ? 0 : 1));
    final labelHCtrl = TextEditingController(text: _barcodeLabelH.toStringAsFixed(_barcodeLabelH == _barcodeLabelH.truncateToDouble() ? 0 : 1));
    final qtyCtrl = TextEditingController(text: '$qty');
    final perRowCtrl = TextEditingController(text: '$labelsPerRow');
    List<String> availablePrinters = ['System Default'];
    String selectedDialogPrinter = _barcodePrinter;

    // helper for clean stepper
    Widget _stepper({required TextEditingController ctrl, required int val, required VoidCallback onDec, required VoidCallback onInc, required ValueChanged<String> onChange}) =>
      Container(
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(onTap: onDec, borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
            child: Container(width: 34, height: 38, alignment: Alignment.center,
              child: Icon(Icons.remove_rounded, size: 15, color: val > 1 ? AppColors.textDark : AppColors.textMuted))),
          Container(width: 1, height: 24, color: AppColors.border),
          SizedBox(width: 52, height: 38, child: Center(child: TextFormField(
            controller: ctrl, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
            onChanged: onChange,
          ))),
          Container(width: 1, height: 24, color: AppColors.border),
          InkWell(onTap: onInc, borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
            child: Container(width: 34, height: 38, alignment: Alignment.center,
              child: const Icon(Icons.add_rounded, size: 15, color: AppColors.textDark))),
        ]),
      );

    Widget _field(String label, TextEditingController ctrl) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl, keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true, fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          if (availablePrinters.length <= 1) {
            Printing.listPrinters().then((list) {
              final names = <String>['System Default', ...list.map((p) => p.name)];
              if (ctx.mounted) setLocal(() {
                availablePrinters = names;
                if (names.contains(_barcodePrinter)) selectedDialogPrinter = _barcodePrinter;
              });
            });
          }
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            child: Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Text('Print Barcode', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Barcode preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Container(
                      width: 210,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 3))],
                      ),
                      child: Column(children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black87)),
                        const SizedBox(height: 6),
                        SizedBox(height: 48, width: double.infinity, child: CustomPaint(painter: _BarcodePainter(p.sku))),
                        const SizedBox(height: 4),
                        Text(p.sku, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 1.5, fontFamily: 'Courier')),
                        Text('$_currencySymbol${p.price.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Quantity + Per Row
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Quantity', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                    const SizedBox(height: 5),
                    _stepper(
                      ctrl: qtyCtrl, val: qty,
                      onDec: qty > 1 ? () => setLocal(() { qty--; qtyCtrl.text = '$qty'; }) : () {},
                      onInc: () => setLocal(() { qty++; qtyCtrl.text = '$qty'; }),
                      onChange: (v) { final n = int.tryParse(v); if (n != null && n > 0) setLocal(() => qty = n); },
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Per Row', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                    const SizedBox(height: 5),
                    _stepper(
                      ctrl: perRowCtrl, val: labelsPerRow,
                      onDec: labelsPerRow > 1 ? () => setLocal(() { labelsPerRow--; perRowCtrl.text = '$labelsPerRow'; }) : () {},
                      onInc: () => setLocal(() { labelsPerRow++; perRowCtrl.text = '$labelsPerRow'; }),
                      onChange: (v) { final n = int.tryParse(v); if (n != null && n >= 1) setLocal(() => labelsPerRow = n); },
                    ),
                  ]),
                ]),
                const SizedBox(height: 14),
                // Label size
                Row(children: [
                  Expanded(child: _field('Width (mm)', labelWCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Height (mm)', labelHCtrl)),
                ]),
                const SizedBox(height: 14),
                // Printer — styled like a segmented/filled selector
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Printer', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<String>(
                          value: availablePrinters.contains(selectedDialogPrinter) ? selectedDialogPrinter : 'System Default',
                          isExpanded: true,
                          items: availablePrinters.map((name) => DropdownMenuItem(
                            value: name,
                            child: Row(children: [
                              Icon(
                                name == 'System Default' ? Icons.print_outlined : Icons.print_rounded,
                                size: 14,
                                color: name == selectedDialogPrinter ? AppColors.primary : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(name,
                                style: GoogleFonts.inter(fontSize: 13,
                                  color: name == selectedDialogPrinter ? AppColors.primary : AppColors.textDark,
                                  fontWeight: name == selectedDialogPrinter ? FontWeight.w600 : FontWeight.w400),
                                overflow: TextOverflow.ellipsis)),
                            ]),
                          )).toList(),
                          onChanged: (v) => setLocal(() => selectedDialogPrinter = v ?? 'System Default'),
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                          isDense: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                          selectedItemBuilder: (ctx) => availablePrinters.map((name) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(name, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                // Buttons
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final w = double.tryParse(labelWCtrl.text) ?? 58;
                      final h = double.tryParse(labelHCtrl.text) ?? 30;
                      final finalQty = int.tryParse(qtyCtrl.text) ?? qty;
                      final finalPerRow = int.tryParse(perRowCtrl.text) ?? labelsPerRow;
                      // Persist last-used barcode settings
                      setState(() {
                        _barcodeLabelW = w;
                        _barcodeLabelH = h;
                        _barcodePerRow = finalPerRow;
                        _barcodePrinter = selectedDialogPrinter;
                      });
                      LabelPrinterService.saveBarcodeSettings({
                        'labelW': w, 'labelH': h, 'perRow': finalPerRow, 'printer': selectedDialogPrinter,
                      });
                      _printBarcode(p, quantity: finalQty, labelW: w, labelH: h, labelsPerRow: finalPerRow, printerName: selectedDialogPrinter);
                    },
                    icon: const Icon(Icons.print_rounded, size: 15),
                    label: Text('Print ${int.tryParse(qtyCtrl.text) ?? qty} Label${(int.tryParse(qtyCtrl.text) ?? qty) > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
                ]),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  Future<void> _printBarcode(Product p, {int quantity = 1, double labelW = 58, double labelH = 30, int labelsPerRow = 1, String? printerName}) async {
    final barcodeVal = p.barcodeNo.isNotEmpty ? p.barcodeNo : p.sku;
    String svgStr;
    try {
      svgStr = bc.Barcode.ean13().toSvg(barcodeVal, width: 200, height: 60, drawText: false);
    } catch (_) {
      svgStr = bc.Barcode.code128().toSvg(barcodeVal, width: 200, height: 60, drawText: false);
    }

    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData    = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold    = pw.Font.ttf(boldData);

    final doc = pw.Document();
    // labelW x labelH = ONE sticker; page = perRow stickers, edge-to-edge so the
    // page width equals the physical liner width (e.g. 3 × 35mm = 105mm exactly).
    const gapMm = 0.0;
    const marginMm = 0.0;
    final gap = gapMm * PdfPageFormat.mm;
    final margin = marginMm * PdfPageFormat.mm;
    final cellW = labelW * PdfPageFormat.mm;
    final cellH = labelH * PdfPageFormat.mm;
    final pageW = margin * 2 + labelsPerRow * cellW + (labelsPerRow - 1) * gap;
    final pageH = cellH;
    final pageFormat = PdfPageFormat(pageW, pageH);

    final pad = 5.0 * PdfPageFormat.mm;
    pw.Widget labelCell() => pw.Container(
      width: cellW,
      height: cellH,
      padding: pw.EdgeInsets.symmetric(horizontal: pad, vertical: 1.5 * PdfPageFormat.mm),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.SvgImage(svg: svgStr, width: cellW - pad * 2, height: (cellH - 2 * PdfPageFormat.mm) * 0.62),
          pw.Text(p.name, style: pw.TextStyle(font: bold, fontSize: 4.5, letterSpacing: 0.4), textAlign: pw.TextAlign.center),
          pw.Text('$_currencySymbol${p.price.toStringAsFixed(2)}', style: pw.TextStyle(font: bold, fontSize: 4.5), textAlign: pw.TextAlign.center),
        ],
      ),
    );

    int printed = 0;
    while (printed < quantity) {
      final n = ((quantity - printed) < labelsPerRow) ? (quantity - printed) : labelsPerRow;
      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.symmetric(horizontal: margin),
        build: (_) {
          final cells = <pw.Widget>[];
          for (int i = 0; i < n; i++) {
            if (i > 0) cells.add(pw.SizedBox(width: gap));
            cells.add(labelCell());
          }
          return pw.Row(children: cells);
        },
      ));
      printed += n;
    }

    final bytes = await doc.save();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text('Print Preview',
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
                ),
              ]),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 260,
                  child: PdfPreview(
                    build: (_) async => bytes,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: false,
                    scrollViewDecoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
                    pdfPreviewPageDecoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () async {
                    // System Default resolves to the OS default printer in _printPdfBytes.
                    final targetPrinter = printerName ?? 'System Default';
                    Navigator.pop(ctx);
                    // Sheet dimensions: side margins + perRow stickers + gaps
                    const gapMm = 0.5;
                    const marginMm = 2.0;
                    final sheetW = marginMm * 2 + labelsPerRow * labelW + (labelsPerRow - 1) * gapMm;
                    final sheetH = labelH;
                    await _printPdfBytes(
                      bytes: bytes,
                      printerName: targetPrinter,
                      widthPt: sheetW / 25.4 * 72,
                      heightPt: sheetH / 25.4 * 72,
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 15),
                  label: Text('Print', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _registerMacOSPaperSize(double wMm, double hMm) async {
    final wPt = wMm * 72.0 / 25.4;
    final hPt = hMm * 72.0 / 25.4;
    final key = 'BillCat_${wMm.round()}x${hMm.round()}';
    final displayName = '${wMm.round()} x ${hMm.round()} mm';

    // Clean up wrong entry from previous attempt, then write correct format
    // macOS custom papers use: id, name, width, height, top/bottom/left/right, custom, printer
    // Must use `defaults write` so cfprefsd picks it up immediately (PlistBuddy bypasses cache)
    await Process.run('/usr/bin/defaults',['delete', 'com.apple.print.custompapers', '0']);
    await Process.run('/usr/bin/defaults',['write', 'com.apple.print.custompapers', key,
      '{custom = 1; id = "$key"; name = "$displayName"; width = $wPt; height = $hPt; top = 0; bottom = 0; left = 0; right = 0; printer = "";}']);
  }

  Future<void> _printAllBarcodes(List<Product> products) async {
    if (products.isEmpty) return;

    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData    = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold    = pw.Font.ttf(boldData);

    final doc = pw.Document();
    final lw = 58 * PdfPageFormat.mm;
    final lh = 30 * PdfPageFormat.mm;
    // Use A4 so printer receives standard paper size
    const pageFormat = PdfPageFormat.a4;
    const pageMargin = 8.0 * PdfPageFormat.mm;
    final cols = ((pageFormat.width - pageMargin * 2) / lw).floor().clamp(1, 999);
    final rowsPerPage = ((pageFormat.height - pageMargin * 2) / lh).floor().clamp(1, 999);

    final allLabels = <pw.Widget>[];
    for (final p in products) {
      final barcodeVal = p.barcodeNo.isNotEmpty ? p.barcodeNo : p.sku;
      String svgStr;
      try {
        svgStr = bc.Barcode.ean13().toSvg(barcodeVal, width: 200, height: 80, drawText: false);
      } catch (_) {
        svgStr = bc.Barcode.code128().toSvg(barcodeVal, width: 200, height: 80, drawText: false);
      }
      allLabels.add(pw.Container(
        width: lw, height: lh,
        padding: pw.EdgeInsets.symmetric(horizontal: 5 * PdfPageFormat.mm, vertical: 1.5 * PdfPageFormat.mm),
        child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.SvgImage(svg: svgStr, width: lw - 10 * PdfPageFormat.mm, height: 17 * PdfPageFormat.mm),
          pw.SizedBox(height: 1 * PdfPageFormat.mm),
          pw.Text(p.sku, style: pw.TextStyle(font: bold, fontSize: 7), textAlign: pw.TextAlign.center),
          pw.Text(p.name, maxLines: 1, style: pw.TextStyle(font: regular, fontSize: 6), textAlign: pw.TextAlign.center),
          pw.Text('$_currencySymbol${p.price.toStringAsFixed(2)}', style: pw.TextStyle(font: bold, fontSize: 7), textAlign: pw.TextAlign.center),
        ]),
      ));
    }

    final labelsPerPage = cols * rowsPerPage;
    for (int start = 0; start < allLabels.length; start += labelsPerPage) {
      final chunk = allLabels.sublist(start, (start + labelsPerPage).clamp(0, allLabels.length));
      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(pageMargin),
        build: (_) {
          final rows = <pw.Widget>[];
          for (int r = 0; r * cols < chunk.length; r++) {
            final rowCells = chunk.skip(r * cols).take(cols).toList();
            rows.add(pw.Row(children: rowCells));
          }
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: rows);
        },
      ));
    }

    final bytes = await doc.save();
    // System Default resolves to the OS default printer in _printPdfBytes.
    final sheetW3 = 2.0 * 2 + _barcodePerRow * _barcodeLabelW + (_barcodePerRow - 1) * 0.5;
    final sheetH3 = _barcodeLabelH;
    await _printPdfBytes(
      bytes: bytes,
      printerName: _barcodePrinter,
      widthPt: sheetW3 / 25.4 * 72,
      heightPt: sheetH3 / 25.4 * 72,
    );
  }

  /// Prints already-rendered PDF [bytes] to a named printer using the OS print
  /// system (CUPS on macOS / Windows spooler) via the printing package — avoids
  /// shelling out to `lpr`, which fails inside restricted app environments.
  Future<void> _printPdfBytes({
    required Uint8List bytes,
    required String printerName,
    Printer? printerObj,
    double? widthPt,
    double? heightPt,
    String jobName = 'BillCat Labels',
  }) async {
    try {
      Printer? target = printerObj;
      if (target == null) {
        final list = await Printing.listPrinters();
        if (printerName.isEmpty || printerName == 'System Default') {
          // Fall back to the OS default printer, or the only printer available.
          for (final p in list) { if (p.isDefault) { target = p; break; } }
          if (target == null && list.length == 1) target = list.first;
        } else {
          for (final p in list) { if (p.name == printerName) { target = p; break; } }
          // Saved printer no longer on this machine → fall back to default.
          if (target == null) {
            for (final p in list) { if (p.isDefault) { target = p; break; } }
          }
        }
      }
      if (target == null) {
        if (mounted) _showToast('No printer available — add one in System Settings', isError: true);
        return;
      }
      final fmt = (widthPt != null && heightPt != null && widthPt > 0 && heightPt > 0)
          ? PdfPageFormat(widthPt, heightPt)
          : PdfPageFormat.a4;
      // usePrinterSettings:true → the printer uses its OWN configured label
      // media, which is what every driver reliably renders. Forcing a custom
      // page size (false) makes many drivers accept the job but print nothing.
      // Exact app-controlled sizing (multi-across) is handled by the raw
      // TSPL/ZPL network path instead.
      final ok = await Printing.directPrintPdf(
        printer: target,
        onLayout: (_) async => bytes,
        name: jobName,
        format: fmt,
        usePrinterSettings: true,
      );
      if (!mounted) return;
      _showToast(ok ? 'Sent to $printerName' : 'Print was cancelled', isError: !ok);
    } catch (e) {
      if (mounted) _showToast('Print failed: $e', isError: true);
    }
  }

  void _confirmDeleteProduct(Product p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete "${p.name}"?', style: GoogleFonts.manrope(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Text('This will permanently remove the product from your inventory.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await LocalDbService.deleteProduct(p.id);
              ConnectivityService.instance.syncNow();
              setState(() => _products.removeWhere((x) => x.id == p.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Variants editor (shared by Add + Edit product dialogs) ────────────────

  /// Compact variant dropdown shown next to the Product Name field.
  /// Value -1 = Default (base product); 0..n select a variant; -2 = add new.
  Widget _variantDropdown({
    required List<_VariantDraft> drafts,
    required int selVar,
    required void Function(int) onSelect,
    required StateSetter setLocal,
  }) {
    // No "Default" row: the base product is the rest state (box shows an
    // "Add variant" button); when a variant is selected the box becomes an
    // editable name field so it can be renamed in place. The suffix menu
    // switches between existing variants and adds new ones.
    final bool variantSelected = selVar >= 0 && selVar < drafts.length;

    void addVariant() {
      setLocal(() {
        drafts.add(_VariantDraft());
        onSelect(drafts.length - 1);
      });
      // Focus the box so the user types the new variant's name right here.
      WidgetsBinding.instance.addPostFrameCallback((_) => _variantNameFocus.requestFocus());
    }

    // Dropdown-style menu (the ▾) to switch variants or add another.
    Widget variantsMenu() => PopupMenuButton<int>(
      tooltip: 'Variants',
      padding: EdgeInsets.zero,
      color: Colors.white,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
      onSelected: (v) {
        if (v == -2) {
          addVariant();
        } else {
          onSelect(v);
        }
      },
      itemBuilder: (_) => [
        ...List.generate(drafts.length, (i) {
          final nm = drafts[i].name.text.trim().isEmpty ? 'Variant ${i + 1}' : drafts[i].name.text.trim();
          return PopupMenuItem(value: i, child: Text(nm, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)));
        }),
        if (drafts.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem(value: -2, child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_rounded, size: 14, color: AppColors.accentBlue),
          const SizedBox(width: 6),
          Text('Add variant', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentBlue)),
        ])),
      ],
    );

    if (variantSelected) {
      // Editable name — typing renames the selected variant live.
      return TextField(
        controller: drafts[selVar].name,
        focusNode: _variantNameFocus,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
        onChanged: (_) => setLocal(() {}),
        decoration: _dlgInputDecor('Variant ${selVar + 1}').copyWith(
          // Pencil hints that the name is editable in place.
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 10, right: 4),
            child: Icon(Icons.edit_rounded, size: 13, color: AppColors.textMuted),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: variantsMenu(),
          suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        ),
      );
    }

    // Base product: an "Add variant" button (plus the menu if variants exist
    // elsewhere to switch back to them).
    return InkWell(
      onTap: addVariant,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _dlgInputDecor('').copyWith(
          suffixIcon: drafts.isEmpty ? null : variantsMenu(),
          suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_rounded, size: 14, color: AppColors.accentBlue),
          const SizedBox(width: 6),
          Flexible(child: Text('Add variant', overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentBlue))),
        ]),
      ),
    );
  }

  /// The "Price & stock below apply to this variant · Remove" line.
  /// (Renaming happens inline in the VARIANT box, so there's no Rename link.)
  Widget _variantEditNote({
    required List<_VariantDraft> drafts,
    required int selVar,
    required void Function(int) onSelect,
    required StateSetter setLocal,
  }) {
    if (selVar < 0 || selVar >= drafts.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(child: Text('Price & stock below apply to this variant',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))),
        GestureDetector(
          onTap: () => setLocal(() {
            drafts.removeAt(selVar);
            onSelect(-1);
          }),
          child: Text('Remove', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFFF3B30))),
        ),
      ]),
    );
  }

  /// Dealer/Supplier + Purchase Date fields shown on the product form.
  Widget _supplierAndDateRow({
    required TextEditingController supplierCtrl,
    required DateTime? purchaseDate,
    required void Function(DateTime?) onPickDate,
    FocusNode? supplierFocus,
    VoidCallback? onSupplierSubmitted,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dlgLabel('DEALER / SUPPLIER'),
      const SizedBox(height: 6),
      Builder(builder: (fctx) => TextFormField(
        controller: supplierCtrl,
        focusNode: supplierFocus,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => onSupplierSubmitted != null
            ? onSupplierSubmitted()
            : FocusScope.of(fctx).nextFocus(),
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
        decoration: _dlgInputDecor('e.g. Metro Wholesale'),
      )),
      const SizedBox(height: 16),
      _dlgLabel('PURCHASE DATE'),
      const SizedBox(height: 6),
      Builder(builder: (ctx) => GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: ctx,
            initialDate: purchaseDate ?? now,
            firstDate: DateTime(now.year - 5),
            lastDate: DateTime(now.year + 1),
          );
          if (picked != null) onPickDate(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Text(purchaseDate != null ? _fmtDate(purchaseDate) : 'Select purchase date',
                style: GoogleFonts.inter(fontSize: 13, color: purchaseDate != null ? AppColors.textDark : AppColors.textMuted)),
            const Spacer(),
            if (purchaseDate != null)
              GestureDetector(
                onTap: () => onPickDate(null),
                child: const Icon(Icons.close_rounded, size: 15, color: AppColors.textMuted),
              ),
          ]),
        ),
      )),
    ]);
  }

  /// Convert drafts → variants, deriving SKU/barcode from the parent when blank.
  List<ProductVariant> _buildVariantsFromDrafts(
      List<_VariantDraft> drafts, String parentSku, double parentPrice) {
    final out = <ProductVariant>[];
    for (final d in drafts) {
      final vname = d.name.text.trim();
      if (vname.isEmpty) continue;
      final vsku = d.sku.text.trim();
      out.add(ProductVariant(
        id: d.id.isNotEmpty ? d.id : 'v${DateTime.now().microsecondsSinceEpoch}${out.length}',
        name: vname,
        price: double.tryParse(d.price.text) ?? parentPrice,
        stock: int.tryParse(d.stock.text) ?? 0,
        sku: vsku.isNotEmpty ? vsku : (parentSku.isNotEmpty ? '$parentSku-$vname' : vname),
        barcodeNo: d.barcodeNo,
      ));
    }
    return out;
  }

  void _showEditProductDialog(Product p) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: p.name);
    final skuCtrl = TextEditingController(text: p.sku);
    final priceCtrl = TextEditingController(text: p.price.toStringAsFixed(2));
    final buyingPriceCtrl = TextEditingController(text: p.buyingPrice > 0 ? p.buyingPrice.toStringAsFixed(2) : '');
    final taxPercentCtrl = TextEditingController(text: p.taxPercent > 0 ? p.taxPercent.toStringAsFixed(2) : '');
    final stockCtrl = TextEditingController(text: '${p.stock}');
    List<String> tags = p.description.isNotEmpty
        ? p.description.split(RegExp(r'[,\n]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : [];
    final tagInputCtrl = TextEditingController();
    final tagFocusNode = FocusNode();
    bool isAddingTag = false;
    String emoji = p.emoji;
    String category = _userCategories.contains(p.category) ? p.category : (_userCategories..add(p.category)).last;
    String unit = kProductUnits.contains(p.unit) ? p.unit : 'pcs';
    final barcodeNoCtrl = TextEditingController(text: p.barcodeNo);
    final supplierCtrl = TextEditingController(text: p.supplier);
    // Fall back to today ("date of adding") when the product has no date set.
    DateTime? purchaseDate = p.purchaseDate ?? DateTime.now();
    final variantDrafts = p.variants.map(_VariantDraft.fromVariant).toList();
    // Show the first saved variant on open so existing variants are visible
    // (there's no "Default" row now); -1 = base product when there are none.
    int selVar = variantDrafts.isNotEmpty ? 0 : -1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final activeVar = (selVar >= 0 && selVar < variantDrafts.length) ? variantDrafts[selVar] : null;
        final priceController = activeVar?.price ?? priceCtrl;
        final stockController = activeVar?.stock ?? stockCtrl;
        final skuController = activeVar?.sku ?? skuCtrl;
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('Edit Product', style: GoogleFonts.manrope(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      style: IconButton.styleFrom(minimumSize: const Size(32,32), padding: EdgeInsets.zero),
                    ),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dlgLabel('IMAGE'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final r = await FilePicker.platform.pickFiles(type: FileType.image);
                              if (r?.files.single.path != null) {
                                final copied = await LocalDbService.copyImageToAppDir(r!.files.single.path!);
                                setLocal(() => emoji = copied);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: emoji.startsWith('/')
                                    ? Image.file(File(emoji), fit: BoxFit.cover,
                                        width: 64, height: 64,
                                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)))
                                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        emoji.isNotEmpty
                                            ? Text(emoji, style: const TextStyle(fontSize: 24))
                                            : Icon(Icons.add_photo_alternate_outlined,
                                                color: AppColors.textMuted, size: 22),
                                        if (emoji.isEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text('Photo', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
                                        ]
                                      ]),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _dlgLabel('PRODUCT NAME'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: nameCtrl,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                                validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Required',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                decoration: _dlgInputDecor('e.g. Wireless Keyboard'),
                              ),
                            ])),
                            const SizedBox(width: 14),
                            SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _dlgLabel('VARIANT'),
                              const SizedBox(height: 6),
                              _variantDropdown(drafts: variantDrafts, selVar: selVar, onSelect: (v) => setLocal(() => selVar = v), setLocal: setLocal),
                            ])),
                          ]),
                          _variantEditNote(drafts: variantDrafts, selVar: selVar, onSelect: (v) => setLocal(() => selVar = v), setLocal: setLocal),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dlgLabel('SKU'),
                          const SizedBox(height: 6),
                          TextFormField(controller: skuController,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                              decoration: _dlgInputDecor('e.g. WK-00123')),
                        ])),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dlgLabel('CATEGORY'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: category.isEmpty ? null : category,
                            items: [
                              ..._userCategories.map((c) => DropdownMenuItem(value: c,
                                  child: Text(c, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)))),
                              DropdownMenuItem(value: '__add__',
                                  child: Row(children: [
                                    const Icon(Icons.add_rounded, size: 14, color: AppColors.accentBlue),
                                    const SizedBox(width: 6),
                                    Text('Add Category', style: GoogleFonts.inter(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentBlue)),
                                  ])),
                            ],
                            onChanged: (v) async {
                              if (v == '__add__') {
                                final newCat = await _showAddCategoryDialog(ctx);
                                if (newCat != null && newCat.isNotEmpty) {
                                  if (!_userCategories.contains(newCat)) {
                                    await LocalDbService.saveCategory(newCat);
                                    ConnectivityService.instance.syncNow();
                                    setState(() => _userCategories.add(newCat));
                                  }
                                  setLocal(() => category = newCat);
                                }
                              } else if (v != null) setLocal(() => category = v);
                            },
                            decoration: _dlgInputDecor('Category'),
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                            dropdownColor: Colors.white,
                          ),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      _supplierAndDateRow(
                        supplierCtrl: supplierCtrl,
                        purchaseDate: purchaseDate,
                        onPickDate: (d) => setLocal(() => purchaseDate = d),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dlgLabel(activeVar != null ? 'VARIANT PRICE ($_currencySymbol)' : 'SELLING PRICE ($_currencySymbol)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: priceController,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            validator: (v) => activeVar != null || (v != null && v.isNotEmpty && double.tryParse(v) != null) ? null : 'Required',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                            decoration: _dlgInputDecor('0.00'),
                          ),
                        ])),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dlgLabel(activeVar != null ? 'VARIANT STOCK' : 'STOCK QTY'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: stockController,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                            enabled: activeVar != null || variantDrafts.isEmpty,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) => activeVar != null || variantDrafts.isNotEmpty || (v != null && v.isNotEmpty) ? null : 'Required',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                            decoration: _dlgInputDecor(activeVar == null && variantDrafts.isNotEmpty ? 'Auto (sum of variants)' : '0'),
                          ),
                        ])),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dlgLabel('UNIT'),
                          const SizedBox(height: 6),
                          _unitDropdown(unit, (v) => setLocal(() => unit = v)),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dlgLabel('BUYING PRICE ($_currencySymbol)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: buyingPriceCtrl,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                            decoration: _dlgInputDecor('0.00'),
                          ),
                        ])),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dlgLabel('TAX (%)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: taxPercentCtrl,
                            textInputAction: TextInputAction.done,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                            decoration: _dlgInputDecor('0.00'),
                          ),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      _dlgLabel('TAGS'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          ...List.generate(tags.length, (i) {
                            const tagColors = [
                              Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B),
                              Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFFEC4899),
                              Color(0xFF8B5CF6), Color(0xFF14B8A6), Color(0xFFF97316),
                            ];
                            final c = tagColors[i % tagColors.length];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: c.withValues(alpha: 0.4)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(tags[i], style: GoogleFonts.inter(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () => setLocal(() => tags.removeAt(i)),
                                  child: Icon(Icons.close_rounded, size: 13, color: c),
                                ),
                              ]),
                            );
                          }),
                          if (isAddingTag)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                              ),
                              child: SizedBox(
                                width: 160,
                                child: TextField(
                                  controller: tagInputCtrl,
                                  focusNode: tagFocusNode,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                                  decoration: InputDecoration(
                                    hintText: 'Type tag…',
                                    hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (v) {
                                    final t = v.trim();
                                    if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
                                    tagInputCtrl.clear();
                                    setLocal(() => isAddingTag = false);
                                  },
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () { setLocal(() => isAddingTag = true); Future.delayed(const Duration(milliseconds: 50), () => tagFocusNode.requestFocus()); },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.add_rounded, size: 13, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text('Add tag', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                                ]),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final newBarcodeNo = barcodeNoCtrl.text.trim().isNotEmpty
                          ? barcodeNoCtrl.text.trim()
                          : await LocalDbService.getNextBarcodeNo();
                        final basePrice = double.tryParse(priceCtrl.text) ?? 0;
                        final baseSku = skuCtrl.text.trim().isEmpty ? p.sku : skuCtrl.text.trim();
                        final variants = _buildVariantsFromDrafts(variantDrafts, baseSku, basePrice);
                        // With variants, total stock is the sum of variant stocks.
                        final effectiveStock = variants.isNotEmpty
                            ? variants.fold<int>(0, (s, v) => s + v.stock)
                            : (int.tryParse(stockCtrl.text) ?? 0);
                        final updated = Product(
                          id: p.id,
                          name: nameCtrl.text.trim(),
                          price: basePrice,
                          buyingPrice: double.tryParse(buyingPriceCtrl.text) ?? 0.0,
                          taxPercent: double.tryParse(taxPercentCtrl.text) ?? 0.0,
                          category: category,
                          emoji: emoji,
                          sku: baseSku,
                          stock: effectiveStock,
                          description: tags.join(', '),
                          unit: unit,
                          barcodeNo: newBarcodeNo,
                          supplier: supplierCtrl.text.trim(),
                          purchaseDate: purchaseDate,
                          variants: variants,
                        );
                        await LocalDbService.updateProduct(updated);
                        ConnectivityService.instance.syncNow();
                        if (!ctx.mounted) return;
                        setState(() {
                          final idx = _products.indexWhere((x) => x.id == p.id);
                          if (idx != -1) _products[idx] = updated;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text('Update Changes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Add Product Dialog ────────────────────────────────────────────────────────

  String _generateUniqueSku(String name, {String? excludeId}) {
    final words = name.trim().split(RegExp(r'\s+'));
    String prefix = '';
    for (final w in words) {
      final clean = w.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      if (clean.isNotEmpty) {
        prefix += clean.length > 2 ? clean.substring(0, 2) : clean;
      }
      if (prefix.length >= 4) break;
    }
    if (prefix.isEmpty) prefix = 'ITEM';
    prefix = prefix.substring(0, prefix.length.clamp(1, 6));
    final existing = _products
        .where((p) => excludeId == null || p.id != excludeId)
        .map((p) => p.sku)
        .toSet();
    int num = 1;
    while (existing.contains('$prefix${num.toString().padLeft(2, '0')}')) {
      num++;
    }
    return '$prefix${num.toString().padLeft(2, '0')}';
  }

  void _showAddProductDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final buyingPriceCtrl = TextEditingController();
    final taxPercentCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    List<String> tags = [];
    final tagInputCtrl = TextEditingController();
    final tagFocusNode = FocusNode();
    bool isAddingTag = false;
    String emoji = '';
    String category = _userCategories.isNotEmpty ? _userCategories.first : '';
    String unit = 'pcs';
    String barcodeNo = '';
    final supplierCtrl = TextEditingController();
    DateTime? purchaseDate = DateTime.now();
    bool skuAutoMode = true;
    final variantDrafts = <_VariantDraft>[];
    int selVar = -1; // -1 = base product; else index into variantDrafts
    // Explicit focus chain so Enter walks only the text fields (skips dropdowns,
    // the date picker and the action buttons).
    final nameFocus = FocusNode();
    final skuFocus = FocusNode();
    final supplierFocus = FocusNode();
    final priceFocus = FocusNode();
    final stockFocus = FocusNode();
    final buyingFocus = FocusNode();
    final taxFocus = FocusNode();
    LocalDbService.getNextBarcodeNo().then((n) { barcodeNo = n; });

    nameCtrl.addListener(() {
      if (skuAutoMode && nameCtrl.text.isNotEmpty) {
        skuCtrl.text = _generateUniqueSku(nameCtrl.text);
      }
    });
    skuCtrl.addListener(() {
      // If user manually edits SKU, stop auto-generating
      final expected = nameCtrl.text.isNotEmpty ? _generateUniqueSku(nameCtrl.text) : '';
      if (skuCtrl.text != expected) skuAutoMode = false;
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final activeVar = (selVar >= 0 && selVar < variantDrafts.length) ? variantDrafts[selVar] : null;
        final priceController = activeVar?.price ?? priceCtrl;
        final stockController = activeVar?.stock ?? stockCtrl;
        final skuController = activeVar?.sku ?? skuCtrl;
        Future<void> submitProduct() async {
          if (!formKey.currentState!.validate()) return;
          final sku = skuCtrl.text.trim().isEmpty
              ? _generateUniqueSku(nameCtrl.text.trim())
              : skuCtrl.text.trim().toUpperCase();
          if (_products.any((p) => p.sku == sku)) {
            _showToast('SKU "$sku" already exists', isError: true);
            return;
          }
          final basePrice = double.tryParse(priceCtrl.text) ?? 0;
          final variants = _buildVariantsFromDrafts(variantDrafts, sku, basePrice);
          final effectiveStock = variants.isNotEmpty
              ? variants.fold<int>(0, (s, v) => s + v.stock)
              : (int.tryParse(stockCtrl.text) ?? 0);
          final newProduct = Product(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text.trim(),
            price: basePrice,
            buyingPrice: double.tryParse(buyingPriceCtrl.text) ?? 0.0,
            taxPercent: double.tryParse(taxPercentCtrl.text) ?? 0.0,
            category: category,
            emoji: emoji,
            sku: sku,
            stock: effectiveStock,
            description: tags.join(', '),
            unit: unit,
            barcodeNo: barcodeNo.isEmpty
                ? await LocalDbService.getNextBarcodeNo()
                : barcodeNo,
            supplier: supplierCtrl.text.trim(),
            purchaseDate: purchaseDate,
            variants: variants,
          );
          await LocalDbService.insertProduct(newProduct);
          ConnectivityService.instance.syncNow();
          if (!ctx.mounted) return;
          setState(() => _products.add(newProduct));
          Navigator.pop(ctx);
          _showToast('${newProduct.name} added to inventory');
        }
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 20),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(
                        bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_box_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('Add New Product',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          )),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textMuted),
                        style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                ),
                // Form
                Flexible(
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emoji + Name row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image picker
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _dlgLabel('IMAGE'),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () async {
                                    final r = await FilePicker.platform.pickFiles(
                                        type: FileType.image);
                                    if (r?.files.single.path != null) {
                                      final copied = await LocalDbService.copyImageToAppDir(r!.files.single.path!);
                                      setLocal(() => emoji = copied);
                                    }
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: emoji.startsWith('/')
                                          ? Image.file(File(emoji), fit: BoxFit.cover,
                                              width: 64, height: 64,
                                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)))
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_photo_alternate_outlined,
                                                    color: AppColors.textMuted, size: 22),
                                                const SizedBox(height: 3),
                                                Text('Photo', style: GoogleFonts.inter(
                                                    fontSize: 9, color: AppColors.textMuted)),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            // Name + Variant
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      _dlgLabel('PRODUCT NAME'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: nameCtrl,
                                        focusNode: nameFocus,
                                        textInputAction: TextInputAction.next,
                                        onFieldSubmitted: (_) => skuFocus.requestFocus(),
                                        validator: (v) =>
                                            v != null && v.trim().isNotEmpty ? null : 'Required',
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                        decoration: _dlgInputDecor('e.g. Wireless Keyboard'),
                                      ),
                                    ])),
                                    const SizedBox(width: 14),
                                    SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      _dlgLabel('VARIANT'),
                                      const SizedBox(height: 6),
                                      _variantDropdown(drafts: variantDrafts, selVar: selVar, onSelect: (v) => setLocal(() => selVar = v), setLocal: setLocal),
                                    ])),
                                  ]),
                                  _variantEditNote(drafts: variantDrafts, selVar: selVar, onSelect: (v) => setLocal(() => selVar = v), setLocal: setLocal),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // SKU + Category row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _dlgLabel('SKU'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: skuController,
                                    focusNode: skuFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => supplierFocus.requestFocus(),
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textDark),
                                    decoration:
                                        _dlgInputDecor('e.g. WK-00123'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _dlgLabel('CATEGORY'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: category.isEmpty ? null : category,
                                    items: [
                                      ..._userCategories.map((c) =>
                                          DropdownMenuItem(value: c,
                                              child: Text(c, style: GoogleFonts.inter(
                                                  fontSize: 13, color: AppColors.textDark)))),
                                      DropdownMenuItem(
                                        value: '__add__',
                                        child: Row(children: [
                                          const Icon(Icons.add_rounded, size: 14, color: AppColors.accentBlue),
                                          const SizedBox(width: 6),
                                          Text('Add Category', style: GoogleFonts.inter(
                                              fontSize: 13, fontWeight: FontWeight.w600,
                                              color: AppColors.accentBlue)),
                                        ]),
                                      ),
                                    ],
                                    onChanged: (v) async {
                                      if (v == '__add__') {
                                        final newCat = await _showAddCategoryDialog(ctx);
                                        if (newCat != null && newCat.isNotEmpty) {
                                          if (!_userCategories.contains(newCat)) {
                                            await LocalDbService.saveCategory(newCat);
                                            ConnectivityService.instance.syncNow();
                                            setState(() => _userCategories.add(newCat));
                                          }
                                          setLocal(() => category = newCat);
                                        }
                                      } else if (v != null) {
                                        setLocal(() => category = v);
                                      }
                                    },
                                    decoration: _dlgInputDecor('Category'),
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                    dropdownColor: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _supplierAndDateRow(
                          supplierCtrl: supplierCtrl,
                          purchaseDate: purchaseDate,
                          onPickDate: (d) => setLocal(() => purchaseDate = d),
                          supplierFocus: supplierFocus,
                          onSupplierSubmitted: () => priceFocus.requestFocus(),
                        ),
                        const SizedBox(height: 16),
                        // Price + Stock row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _dlgLabel(activeVar != null ? 'VARIANT PRICE ($_currencySymbol)' : 'SELLING PRICE ($_currencySymbol)'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: priceController,
                                    focusNode: priceFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => stockFocus.requestFocus(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                                    validator: (v) {
                                      if (activeVar != null) return null;
                                      if (v == null || v.isEmpty) return 'Required';
                                      if (double.tryParse(v) == null) return 'Invalid number';
                                      return null;
                                    },
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                    decoration: _dlgInputDecor('0.00'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _dlgLabel(activeVar != null ? 'VARIANT STOCK' : 'STOCK QTY'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: stockController,
                                    focusNode: stockFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => buyingFocus.requestFocus(),
                                    enabled: activeVar != null || variantDrafts.isEmpty,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    validator: (v) => activeVar != null || variantDrafts.isNotEmpty || (v != null && v.isNotEmpty) ? null : 'Required',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                    decoration: _dlgInputDecor(activeVar == null && variantDrafts.isNotEmpty ? 'Auto (sum of variants)' : '0'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _dlgLabel('UNIT'),
                              const SizedBox(height: 6),
                              _unitDropdown(unit, (v) => setLocal(() => unit = v)),
                            ])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Buying Price + Tax row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _dlgLabel('BUYING PRICE ($_currencySymbol)'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: buyingPriceCtrl,
                                    focusNode: buyingFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => taxFocus.requestFocus(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                    decoration: _dlgInputDecor('0.00'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _dlgLabel('TAX (%)'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: taxPercentCtrl,
                                    focusNode: taxFocus,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => submitProduct(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                    decoration: _dlgInputDecor('0.00'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _dlgLabel('TAGS'),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            ...List.generate(tags.length, (i) {
                              const tagColors = [
                                Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B),
                                Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFFEC4899),
                                Color(0xFF8B5CF6), Color(0xFF14B8A6), Color(0xFFF97316),
                              ];
                              final c = tagColors[i % tagColors.length];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: c.withValues(alpha: 0.4)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(tags[i], style: GoogleFonts.inter(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 5),
                                  GestureDetector(
                                    onTap: () => setLocal(() => tags.removeAt(i)),
                                    child: Icon(Icons.close_rounded, size: 13, color: c),
                                  ),
                                ]),
                              );
                            }),
                            if (isAddingTag)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                ),
                                child: SizedBox(
                                  width: 160,
                                  child: TextField(
                                    controller: tagInputCtrl,
                                    focusNode: tagFocusNode,
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                                    decoration: InputDecoration(
                                      hintText: 'Type tag…',
                                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (v) {
                                      final t = v.trim();
                                      if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
                                      tagInputCtrl.clear();
                                      setLocal(() => isAddingTag = false);
                                    },
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () { setLocal(() => isAddingTag = true); Future.delayed(const Duration(milliseconds: 50), () => tagFocusNode.requestFocus()); },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.add_rounded, size: 13, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text('Add tag', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                                  ]),
                                ),
                              ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: submitProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text('Add Product',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<String?> _pickEmoji(BuildContext ctx, String current) async {
    const emojis = [
      '📦', '💻', '🖥️', '🖱️', '⌨️', '🎧', '🎮', '📷', '💾', '🧠',
      '🔌', '🗂️', '⚡', '📱', '🖨️', '📡', '🔋', '💿', '📺', '🎙️',
      '🕹️', '🔦', '🖊️', '📋', '🗃️', '🧲', '🔧', '🔩', '⚙️', '🛒',
    ];
    return showDialog<String>(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Pick an Emoji',
                    style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: emojis.map((e) {
                    final selected = e == current;
                    return GestureDetector(
                      onTap: () => Navigator.pop(ctx, e),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: selected
                              ? Border.all(
                                  color: AppColors.primary, width: 1.5)
                              : null,
                        ),
                        child: Center(
                            child: Text(e,
                                style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showAddCategoryDialog(BuildContext ctx) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('New Category', style: GoogleFonts.manrope(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'e.g. Electronics',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Hardware keyboard handler — pure-digit sequences go silently to cart
  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final isCmd = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final noDialogOpen = ModalRoute.of(context)?.isCurrent != false;
    // Cmd/Ctrl+P → Print Barcodes on Inventory, Print Bill on Billing
    if (event.logicalKey == LogicalKeyboardKey.keyP && isCmd) {
      if (_selectedTab == 2 && noDialogOpen) {
        _bulkPrintQtys = { for (final p in _products) p.id: p.stock > 0 ? p.stock : 1 };
        _bulkPrintSelected = {};
        _bulkPrinters = ['System Default'];
        _showBulkPrintDialog();
        return true;
      }
      if (_selectedTab == 1 && noDialogOpen) {
        if (_isPrinting) return true;
        final cart = context.read<CartProvider>();
        if (cart.items.isEmpty) {
          _showToast('Cart is empty', isError: true);
          return true;
        }
        _showPrintBillDialog(cart);
        return true;
      }
      return false;
    }
    // Cmd/Ctrl+C on Billing → Paid - Close Bill. Real copy still wins whenever
    // text is actually selected, so this never eats a deliberate Cmd+C.
    if (event.logicalKey == LogicalKeyboardKey.keyC && isCmd) {
      if (_selectedTab != 1 || !noDialogOpen) return false;
      final focused = FocusManager.instance.primaryFocus?.context?.widget;
      if (focused is EditableText &&
          !focused.controller.selection.isCollapsed) return false;
      final cart = context.read<CartProvider>();
      if (cart.items.isEmpty) {
        _showToast('Cart is empty', isError: true);
        return true;
      }
      _closeBill(context, cart);
      return true;
    }
    // Only on billing tab (tab 1), not inside a dialog
    if (_selectedTab != 1) return false;
    final isDialogOpen = ModalRoute.of(context)?.isCurrent == false;
    if (isDialogOpen) return false;
    // If any text field has focus, don't intercept
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText) return false;
    if (_customerNameFocus.hasFocus || _customerPhoneFocus.hasFocus ||
        _searchFocus.hasFocus || _addCustomerFocus.hasFocus ||
        _discountFocus.hasFocus || _customNameFocus.hasFocus ||
        _customPriceFocus.hasFocus) return false;

    final logical = event.logicalKey;

    if (logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.numpadEnter) {
      final buf = _scanBuffer.trim();
      _scanBuffer = '';
      // Only treat as barcode if it's 8+ digits (EAN-8 minimum)
      if (buf.length >= 8 && RegExp(r'^\d+$').hasMatch(buf)) {
        Product? match = _products.cast<Product?>().firstWhere(
          (p) => _barcodeMatches(p!.barcodeNo, buf), orElse: () => null);
        match ??= _products.cast<Product?>().firstWhere(
          (p) => p!.sku == buf, orElse: () => null);
        if (match != null) {
          context.read<CartProvider>().addProduct(match);
          _showToast('${match.name} added to cart');
        } else {
          _showToast('No product for barcode "$buf"', isError: true);
        }
        // Clear search bar in case any digits leaked through
        setState(() { _searchQuery = ''; _searchController.clear(); });
        return true; // consume Enter
      }
      return false;
    }

    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      // Digit → buffer it and consume so it doesn't appear in search bar
      _scanBuffer += char;
      return true;
    }

    // Non-digit → clear buffer, let keypress reach search bar / other fields
    _scanBuffer = '';
    return false;
  }

  // Matches stored 12-digit EAN-13 against scanner output (12 or 13 digits)
  bool _barcodeMatches(String stored, String scanned) {
    if (stored.isEmpty) return false;
    if (stored == scanned) return true;
    // Scanner sends full 13-digit EAN-13 (stored is the 12-digit input)
    if (scanned.length == 13 && scanned.startsWith(stored)) return true;
    // Scanner configured as UPC-A: strips leading '0' from EAN-13 before sending
    // e.g. stored=000000100009, EAN-13=0000001000092, scanner sends=000001000092
    if (scanned.length == 12) {
      final withLeadingZero = '0$scanned';
      if (withLeadingZero.startsWith(stored)) return true;
    }
    return false;
  }

  Widget _unitDropdown(String value, void Function(String) onChanged) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
          dropdownColor: Colors.white,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark),
          items: kProductUnits.map((u) => DropdownMenuItem(
            value: u,
            child: Text(u, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _dlgLabel(String text) => Text(text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1,
      ));

  InputDecoration _dlgInputDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      );

  static String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  String _fmtShort(double v) {
    if (v >= 1000000) return '$_currencySymbol${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '$_currencySymbol${(v / 1000).toStringAsFixed(1)}K';
    return '$_currencySymbol${v.toStringAsFixed(0)}';
  }

  // Indian comma format: 1,00,000.00
  String _fmtComma(double v) {
    // Returns/refunds are negative — keep the sign outside the grouping,
    // otherwise "-500" groups into "-,500".
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    String intPart = parts[0];
    if (intPart.length > 3) {
      final last3 = intPart.substring(intPart.length - 3);
      final rest = intPart.substring(0, intPart.length - 3);
      final grouped = rest.replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
      intPart = '$grouped,$last3';
    }
    return '${neg ? '-' : ''}$_currencySymbol$intPart.${parts[1]}';
  }

  Widget _buildBarChart(List<(String, double)> bars) =>
      _PremiumBarChart(bars: bars, currencySymbol: _currencySymbol);

  // ── Dashboard View ───────────────────────────────────────────────────────────

  Widget _buildDashboardView() {
    // Active period data
    final pSales = switch (_dashPeriod) {
      'This Week'  => _dashWeekSales,
      'This Month' => _dashMonthSales,
      'This Year'  => _dashYearSales,
      _            => _dashSales,
    };
    final pTx = switch (_dashPeriod) {
      'This Week'  => _dashWeekTxCount,
      'This Month' => _dashMonthTxCount,
      'This Year'  => _dashYearTxCount,
      _            => _dashTxCount,
    };
    final pItems = switch (_dashPeriod) {
      'This Week'  => _dashWeekItems,
      'This Month' => _dashMonthItems,
      'This Year'  => _dashYearItems,
      _            => _dashItemsSold,
    };
    final pProfit = switch (_dashPeriod) {
      'This Week'  => _dashProfitWeek,
      'This Month' => _dashProfitMonth,
      'This Year'  => _dashProfitYear,
      _            => _dashProfitToday,
    };
    final pBars = switch (_dashPeriod) {
      'This Week'  => _chartBarsWeek,
      'This Month' => _chartBarsMonth,
      'This Year'  => _chartBarsYear,
      _            => _chartBarsToday,
    };
    final _dow = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.now().weekday];
    String _pctVs(double current, double prev, String label) {
      if (prev == 0) return 'No data last $label';
      final pct = ((current - prev) / prev * 100).round();
      return '${pct >= 0 ? '+' : ''}$pct% vs last $label';
    }
    final pVsLabel = switch (_dashPeriod) {
      'This Week'  => 'Mon – today',
      'This Month' => '1–${DateTime.now().day} ${_monthName(DateTime.now().month)}',
      'This Year'  => 'Jan–${_monthName(DateTime.now().month)} ${DateTime.now().year}',
      _ => _dashYestSales > 0
          ? '${_dashSales >= _dashYestSales ? '+' : ''}${((_dashSales - _dashYestSales) / _dashYestSales * 100).round()}% vs yesterday'
          : _pctVs(_dashSales, _dashLastWeekSameDaySales, _dow),
    };
    final pTopProducts = switch (_dashPeriod) {
      'This Week'  => _topProductsWeek,
      'This Month' => _topProductsMonth,
      'This Year'  => _topProductsYear,
      _            => _topProductsToday,
    };

    final maxCat = _dashCategories.isEmpty ? 1.0
        : _dashCategories.map((e) => e.$2).reduce((a, b) => a > b ? a : b);

    const periods = ['Today', 'This Week', 'This Month', 'This Year'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard',
                      style: GoogleFonts.manrope(
                          fontSize: 22, fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  Text(_fmtDate(DateTime.now()),
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w300,
                          color: AppColors.textMuted)),
                ],
              ),
              const Spacer(),
              // Period dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dashPeriod,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.textMuted),
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppColors.textDark),
                    isDense: true,
                    onChanged: (v) { if (v != null) setState(() => _dashPeriod = v); },
                    items: periods.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Metric cards ──
          Row(children: [
            _metricCard('Total Sales', _fmtComma(pSales),
                Icons.attach_money_rounded, AppColors.accent, pVsLabel,
                currencyIcon: _currencySymbol),
            const SizedBox(width: 16),
            _metricCard('Transactions', '$pTx',
                Icons.receipt_long_rounded, AppColors.accentBlue, '$_dashPeriod'),
            const SizedBox(width: 16),
            _metricCard('Items Sold', '$pItems',
                Icons.shopping_bag_outlined, const Color(0xFF10B981), '$_dashPeriod'),
            const SizedBox(width: 16),
            _metricCard('Profit', _fmtComma(pProfit),
                Icons.trending_up_rounded, const Color(0xFF8B5CF6), '$_dashPeriod',
                currencyIcon: _currencySymbol),
          ]),
          const SizedBox(height: 16),

          // ── Sales Chart ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Sales Overview',
                      style: GoogleFonts.manrope(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const Spacer(),
                  Text(_dashPeriod,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted)),
                ]),
                const SizedBox(height: 4),
                Text('${_fmtComma(pSales)} total  •  $pTx transactions',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w300,
                        color: AppColors.textMuted)),
                const SizedBox(height: 20),
                _buildBarChart(pBars),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Sold Products ──
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Top Products', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        const Spacer(),
                        Text(_dashPeriod, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      ]),
                      Text('Best sellers by qty', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.textMuted)),
                      const SizedBox(height: 16),
                      if (pTopProducts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No sales $_dashPeriod',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                        )
                      else
                        ...pTopProducts.asMap().entries.map((e) {
                          final rank = e.key + 1;
                          final p = e.value;
                          final medalColor = rank == 1 ? const Color(0xFFFFB800)
                              : rank == 2 ? const Color(0xFF9E9E9E)
                              : rank == 3 ? const Color(0xFFCD7F32)
                              : AppColors.textMuted;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: medalColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text('$rank',
                                      style: GoogleFonts.inter(
                                          fontSize: 11, fontWeight: FontWeight.w700,
                                          color: medalColor))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.$1,
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                          overflow: TextOverflow.ellipsis),
                                      Text('${p.$2} units sold',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Text('$_currencySymbol${_fmtShort(p.$3).replaceAll(_currencySymbol, '')}',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sales by Category', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      Text('Revenue breakdown today', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.textMuted)),
                      const SizedBox(height: 20),
                      if (_dashCategories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No sales today yet',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                        )
                      else
                        ..._dashCategories.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(c.$1, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                                const Spacer(),
                                Text(_fmtComma(c.$2), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              ]),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: c.$2 / maxCat,
                                  minHeight: 6,
                                  backgroundColor: AppColors.surfaceVariant,
                                  valueColor: AlwaysStoppedAnimation<Color>(c.$3),
                                ),
                              ),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Recent Transactions', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() { _selectedTab = 3; _reportView = 'Sales'; }),
                          child: Text('View all →', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.accentBlue)),
                        ),
                      ]),
                      Text('Last ${_dashRecentTx.length} bills closed today',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.textMuted)),
                      const SizedBox(height: 16),
                      if (_dashRecentTx.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No transactions today yet',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(children: [
                            Expanded(flex: 3, child: _dashColHeader('CUSTOMER')),
                            Expanded(flex: 2, child: _dashColHeader('METHOD')),
                            Expanded(flex: 2, child: _dashColHeader('TIME')),
                            Expanded(flex: 1, child: _dashColHeader('ITEMS')),
                            Expanded(flex: 2, child: _dashColHeader('AMOUNT', right: true)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: AppColors.border),
                        ..._dashRecentTx.map((tx) {
                          final name = (tx.customerName?.isNotEmpty == true) ? tx.customerName! : 'Walk-in';
                          final timeStr = '${tx.createdAt.hour.toString().padLeft(2,'0')}:${tx.createdAt.minute.toString().padLeft(2,'0')}';
                          final method = switch (tx.paymentMethod.toLowerCase()) {
                            'cash' => 'Cash', 'card' => 'Card', 'upi' => 'UPI/QR', _ => tx.paymentMethod,
                          };
                          final itemCount = tx.items.fold(0, (s, i) => s + i.quantity);
                          return Column(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                              child: Row(children: [
                                Expanded(flex: 3, child: Row(children: [
                                  Container(
                                    width: 28, height: 28,
                                    decoration: const BoxDecoration(color: AppColors.surfaceVariant, shape: BoxShape.circle),
                                    child: Center(child: Text(name[0].toUpperCase(),
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(name, overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark))),
                                ])),
                                Expanded(flex: 2, child: _paymentBadge(method)),
                                Expanded(flex: 2, child: Text(timeStr,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.textMuted))),
                                Expanded(flex: 1, child: Text('$itemCount',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark))),
                                Expanded(flex: 2, child: Text(_fmtComma(tx.total),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark))),
                              ]),
                            ),
                            const Divider(height: 1, color: AppColors.border),
                          ]);
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, String sub, {String? currencyIcon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: currencyIcon != null
                    ? Center(child: Text(currencyIcon, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)))
                    : Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: sub.startsWith('+') ? AppColors.accent.withValues(alpha: 0.08)
                        : sub.startsWith('-') ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(100)),
                child: Text(sub, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500,
                    color: sub.startsWith('+') ? AppColors.accent
                        : sub.startsWith('-') ? const Color(0xFFEF4444)
                        : AppColors.textMuted)),
              ),
            ]),
            const SizedBox(height: 14),
            Text(value, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _printIconBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.print_rounded, color: Colors.white, size: 16),
    ),
  );

  Future<void> _printSalesTable(List<TransactionRecord> txList, String periodLabel) async {
    if (txList.isEmpty) return;
    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData    = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold    = pw.Font.ttf(boldData);

    final q = _salesSearchQuery.toLowerCase();
    final rows = txList.where((t) {
      if (q.isEmpty) return true;
      return (t.customerName ?? '').toLowerCase().contains(q) ||
          t.items.any((i) => i.productName.toLowerCase().contains(q));
    }).toList();

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text('Transaction History – $periodLabel',
            style: pw.TextStyle(font: bold, fontSize: 16)),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['DATE', 'INVOICE', 'CUSTOMER', 'PAYMENT', 'TOTAL']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 8)),
                      ))
                  .toList(),
            ),
            ...rows.map((t) => pw.TableRow(children: [
              _pdfCell(t.createdAt.toString().substring(0, 16), regular),
              _pdfCell('#${billNo(t)}', regular),
              _pdfCell(t.customerName ?? '—', regular),
              _pdfCell(t.paymentMethod, regular),
              _pdfCell('$_currencySymbol${t.total.toStringAsFixed(2)}', bold),
            ])),
          ],
        ),
      ],
    ));
    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Sales-$periodLabel');
  }

  Future<void> _printCustomersTable(List<Customer> customers) async {
    if (customers.isEmpty) return;
    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData    = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold    = pw.Font.ttf(boldData);

    final q = _customerSearchQuery.toLowerCase();
    final rows = customers.where((c) =>
        q.isEmpty ||
        c.name.toLowerCase().contains(q) ||
        (c.phone ?? '').contains(q)).toList();

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text('Customer List',
            style: pw.TextStyle(font: bold, fontSize: 16)),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['#', 'NAME', 'PHONE', 'ADDED ON']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 8)),
                      ))
                  .toList(),
            ),
            ...rows.asMap().entries.map((e) => pw.TableRow(children: [
              _pdfCell('${e.key + 1}', regular),
              _pdfCell(e.value.name, regular),
              _pdfCell(e.value.phone ?? '—', regular),
              _pdfCell(e.value.createdAt.toString().substring(0, 10), regular),
            ])),
          ],
        ),
      ],
    ));
    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Customers');
  }

  Future<void> _printInventoryTable(List<Product> products) async {
    if (products.isEmpty) return;
    final regularData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData    = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold    = pw.Font.ttf(boldData);

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text('Product Inventory',
            style: pw.TextStyle(font: bold, fontSize: 16)),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(1),
            6: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['#', 'PRODUCT', 'CATEGORY', 'SKU', 'PRICE', 'STOCK', 'VALUE']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 8)),
                      ))
                  .toList(),
            ),
            ...products.asMap().entries.map((e) {
              final p = e.value;
              return pw.TableRow(children: [
                _pdfCell('${e.key + 1}', regular),
                _pdfCell(p.name, regular),
                _pdfCell(p.category, regular),
                _pdfCell(p.sku, regular),
                _pdfCell('$_currencySymbol${p.price.toStringAsFixed(2)}', regular),
                _pdfCell('${p.stock}', regular),
                _pdfCell('$_currencySymbol${(p.price * p.stock).toStringAsFixed(2)}', bold),
              ]);
            }),
          ],
        ),
      ],
    ));
    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Inventory');
  }

  pw.Widget _pdfCell(String text, pw.Font font) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
  );

  Widget _dashColHeader(String text, {bool right = false}) => Text(text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.8));

  Widget _paymentBadge(String method) {
    final (color, bg) = switch (method) {
      'Cash'   => (AppColors.accent,    AppColors.accent.withValues(alpha: 0.1)),
      'Card'   => (AppColors.accentBlue, AppColors.accentBlue.withValues(alpha: 0.1)),
      'UPI/QR' => (const Color(0xFF8B5CF6), const Color(0xFF8B5CF6).withValues(alpha: 0.1)),
      _        => (AppColors.textMuted, AppColors.surfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(method, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  // ── Utilities View ────────────────────────────────────────────────────────────

  Widget _buildUtilitiesView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_utilitiesView, style: GoogleFonts.manrope(
              fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text('May ${DateTime.now().day}, ${DateTime.now().year}',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          if (_utilitiesView == 'Quotation') _buildQuotationView(),
        ],
      ),
    );
  }

  // Quotations are print/share-only documents: they never touch the sales
  // tables or stock, so everything here builds a throwaway TransactionRecord
  // and hands it to the existing (approved) print/PDF pipeline as docType
  // 'Quotation'.

  double get _quoteSubtotal =>
      _quoteLines.fold(0.0, (s, l) => s + l.total);

  double get _quoteTaxAmount {
    if (!_quoteApplyTax) return 0;
    final rate = double.tryParse(_taxRateDisplay) ?? 0;
    return _quoteSubtotal * rate / 100;
  }

  List<_QuoteLine> get _validQuoteLines => _quoteLines
      .where((l) => l.name.text.trim().isNotEmpty && l.priceValue > 0)
      .toList();

  TransactionRecord _quoteTx() {
    _quoteNumber ??=
        'QTN-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final items = _validQuoteLines
        .map((l) => TransactionItem(
              productId: '',
              productName: l.name.text.trim(),
              price: l.priceValue,
              quantity: l.qty,
            ))
        .toList();
    return TransactionRecord(
      id: const Uuid().v4(),
      invoiceNumber: _quoteNumber,
      customerName: _quoteCustomerCtrl.text.trim().isEmpty
          ? null
          : _quoteCustomerCtrl.text.trim(),
      customerPhone: _quotePhoneCtrl.text.trim().isEmpty
          ? null
          : _quotePhoneCtrl.text.trim(),
      items: items,
      subtotal: _quoteSubtotal,
      discountAmount: 0,
      taxAmount: _quoteTaxAmount,
      total: _quoteSubtotal + _quoteTaxAmount,
      paymentMethod: 'Quotation',
      createdAt: DateTime.now(),
    );
  }

  Future<Uint8List> _quotePdfBytes() => ReceiptPrinter.buildPdf(
        _quoteTx(),
        storeName: _storeName, storeAddress: _storeAddress,
        storePhone: _storePhone, storeEmail: _storeEmail,
        storeGstin: _storeGstin, receiptFooter: _receiptFooter,
        taxLabel: _taxLabel,
        taxRate: _quoteApplyTax ? _taxRateDisplay : '0',
        currencySymbol: _currencySymbol, paperSize: _paperSize,
        orientation: _printOrientation, layout: _invoiceLayout,
        storeTerms: _storeTerms, logoPath: _logoPath,
        storeUpiId: _storeUpiId, docType: 'Quotation',
      );

  Future<void> _printQuotation() async {
    if (_validQuoteLines.isEmpty) {
      _showToast('Add at least one item with a price', isError: true);
      return;
    }
    await _printRecord(_quoteTx(), docType: 'Quotation', toPrinter: true);
  }

  Future<void> _saveQuotationPdf() async {
    if (_validQuoteLines.isEmpty) {
      _showToast('Add at least one item with a price', isError: true);
      return;
    }
    try {
      final bytes = await _quotePdfBytes();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Quotation PDF',
        fileName: '${_quoteNumber ?? 'Quotation'}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (path == null) return;
      final target = path.toLowerCase().endsWith('.pdf') ? path : '$path.pdf';
      await File(target).writeAsBytes(bytes);
      if (mounted) _showToast('Quotation saved');
    } catch (e) {
      if (mounted) _showToast('Could not save PDF: $e', isError: true);
    }
  }

  Future<void> _shareQuotation() async {
    if (_validQuoteLines.isEmpty) {
      _showToast('Add at least one item with a price', isError: true);
      return;
    }
    try {
      final bytes = await _quotePdfBytes();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${_quoteNumber ?? 'Quotation'}.pdf',
      );
    } catch (e) {
      if (mounted) _showToast('Could not share: $e', isError: true);
    }
  }

  void _clearQuotation() {
    setState(() {
      for (final l in _quoteLines) {
        l.dispose();
      }
      _quoteLines.clear();
      _quoteCustomerCtrl.clear();
      _quotePhoneCtrl.clear();
      _quoteNumber = null;
    });
  }

  void _addQuoteLineFromProducts() {
    String query = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final list = _products
            .where((p) =>
                p.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 420,
            height: 480,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setLocal(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      dense: true,
                      title: Text(p.name,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: Text(
                          '$_currencySymbol${p.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 13)),
                      onTap: () {
                        setState(() => _quoteLines.add(_QuoteLine(
                              initialName: p.name,
                              initialPrice: p.price.toStringAsFixed(2),
                            )));
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _quoteLineRow(int i) {
    final l = _quoteLines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: TextField(
            controller: l.name,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Item name',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: TextField(
            controller: l.price,
            onChanged: (_) => setState(() {}),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: _currencySymbol,
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          color: AppColors.textMuted,
          onPressed: l.qty > 1 ? () => setState(() => l.qty--) : null,
        ),
        SizedBox(
            width: 24,
            child: Center(
                child: Text('${l.qty}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700)))),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          color: AppColors.textMuted,
          onPressed: () => setState(() => l.qty++),
        ),
        SizedBox(
          width: 84,
          child: Text(
            '$_currencySymbol${l.total.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          color: AppColors.textMuted,
          onPressed: () => setState(() {
            final l = _quoteLines.removeAt(i);
            Future.delayed(const Duration(milliseconds: 400), l.dispose);
          }),
        ),
      ]),
    );
  }

  Widget _quoteActionButton(String label, IconData icon, VoidCallback onTap,
      {bool filled = false}) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16, color: AppColors.textDark),
              label: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
    );
  }

  Widget _buildQuotationView() {
    return Expanded(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Items editor ──
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _quoteCustomerCtrl,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Customer name',
                          prefixIcon: const Icon(Icons.person_outline, size: 16),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        controller: _quotePhoneCtrl,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Phone',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 16),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _quoteLines.isEmpty
                        ? Center(
                            child: Text(
                                'No items yet — type one below or pick from your products.',
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: AppColors.textMuted)))
                        : ListView.builder(
                            itemCount: _quoteLines.length,
                            itemBuilder: (_, i) => _quoteLineRow(i),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _quoteLines.add(_QuoteLine())),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('Add item',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _addQuoteLineFromProducts,
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: Text('From products',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
          ),
        ),
        const SizedBox(width: 16),
        // ── Summary + actions ──
        SizedBox(
          width: 300,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                if (_quoteNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Text('No.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted)),
                      const Spacer(),
                      Text(_quoteNumber!,
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                Row(children: [
                  Text('Subtotal',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textMuted)),
                  const Spacer(),
                  Text('$_currencySymbol${_quoteSubtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  SizedBox(
                    width: 22, height: 22,
                    child: Checkbox(
                      value: _quoteApplyTax,
                      onChanged: (v) =>
                          setState(() => _quoteApplyTax = v ?? true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('$_taxLabel ($_taxRateDisplay%)',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textMuted)),
                  const Spacer(),
                  Text('$_currencySymbol${_quoteTaxAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                const Divider(height: 24, color: AppColors.border),
                Row(children: [
                  Text('Total',
                      style: GoogleFonts.manrope(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                      '$_currencySymbol${(_quoteSubtotal + _quoteTaxAmount).toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            _quoteActionButton(
                'Print Quotation', Icons.print_outlined, _printQuotation,
                filled: true),
            const SizedBox(height: 8),
            _quoteActionButton(
                'Save as PDF', Icons.picture_as_pdf_outlined, _saveQuotationPdf),
            const SizedBox(height: 8),
            _quoteActionButton(
                'Send / Share', Icons.ios_share_outlined, _shareQuotation),
            const SizedBox(height: 8),
            _quoteActionButton('Clear', Icons.delete_outline, _clearQuotation),
          ]),
        ),
      ]),
    );
  }

  // ── Reports View ─────────────────────────────────────────────────────────────

  Future<void> _loadReportCustomers() async {
    final customers = await LocalDbService.getCustomers();
    if (mounted) setState(() => _reportCustomers = customers);
  }

  Future<void> _loadReportDealers() async {
    final dealers = await LocalDbService.getDealers();
    if (mounted) setState(() => _reportDealers = dealers);
  }

  Widget _buildReportsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_reportView, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text(_fmtDate(DateTime.now()), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w300, color: AppColors.textMuted)),
                ],
              ),
              const Spacer(),
              if (_reportView == 'Sales') ...[
                _reportPeriodBtn('Today'),
                const SizedBox(width: 6),
                _reportPeriodBtn('This Week'),
                const SizedBox(width: 6),
                _reportPeriodBtn('This Month'),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (_reportView == 'Sales')         _buildSalesReport()
          else if (_reportView == 'Customers') _buildCustomersReport()
          else if (_reportView == 'Dealers')   _buildDealersReport()
          else                                 _buildInventoryReport(),
        ],
      ),
    );
  }

  // ── Sales sub-view ─────────────────────────────────────────────────────────

  Widget _buildSalesReport() {
    final isToday = _reportSalesPeriod == 'Today';
    final isWeek  = _reportSalesPeriod == 'This Week';

    final revenue  = isToday ? _dashSales      : isWeek ? _dashWeekSales  : _dashMonthSales;
    final txCount  = isToday ? _dashTxCount    : isWeek ? _dashWeekTxCount : _dashMonthTxCount;
    final items    = isToday ? _dashItemsSold  : isWeek ? _dashWeekItems   : _dashMonthItems;
    final profit  = isToday ? _dashProfitToday : isWeek ? _dashProfitWeek  : _dashProfitMonth;
    final txList = isToday ? _txListToday : isWeek ? _txListWeek : _txListMonth;
    final periodLabel = isToday ? 'today' : isWeek ? 'this week' : 'this month';

    String fmtAmt(double v) {
      final parts = v.toStringAsFixed(2).split('.');
      final intPart = parts[0];
      final buf = StringBuffer();
      for (int i = 0; i < intPart.length; i++) {
        if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
        buf.write(intPart[i]);
      }
      return '$_currencySymbol$buf.${parts[1]}';
    }

    String fmtDate(DateTime dt) {
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final m = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour < 12 ? 'AM' : 'PM';
        return '$h:$m $ampm';
      }
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${(dt.hour % 12 == 0 ? 12 : dt.hour % 12)}:${dt.minute.toString().padLeft(2,'0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
    }

    return Column(
      children: [
        Row(children: [
          _reportSummaryCard('Total Sales', fmtAmt(revenue),  Icons.attach_money_rounded,  AppColors.accent,            currencyIcon: _currencySymbol),
          const SizedBox(width: 16),
          _reportSummaryCard('Transactions',  '$txCount',       Icons.receipt_long_rounded,  AppColors.accentBlue),
          const SizedBox(width: 16),
          _reportSummaryCard('Items Sold',    '$items',         Icons.shopping_bag_outlined, const Color(0xFFF59E0B)),
          const SizedBox(width: 16),
          _reportSummaryCard('Profit',          fmtAmt(profit),  Icons.trending_up_rounded,   const Color(0xFF8B5CF6),      currencyIcon: _currencySymbol),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Transaction History', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text('All transactions $periodLabel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.textMuted)),
                ])),
                const SizedBox(width: 16),
                SizedBox(
                  width: 240,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.search_rounded, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 7),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _salesSearchQuery = v),
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                          decoration: InputDecoration(
                            hintText: 'Search customer, items...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_salesSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _salesSearchQuery = ''),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.close_rounded, size: 13, color: AppColors.textMuted),
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                _printIconBtn(() => _printSalesTable(txList, periodLabel)),
              ]),
              const SizedBox(height: 16),
              if (txList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No transactions $periodLabel', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(children: [
                    Expanded(flex: 3, child: _dashColHeader('DATE / TIME')),
                    Expanded(flex: 3, child: _dashColHeader('INVOICE')),
                    Expanded(flex: 4, child: _dashColHeader('CUSTOMER')),
                    Expanded(flex: 2, child: _dashColHeader('ITEMS')),
                    Expanded(flex: 2, child: _dashColHeader('PAYMENT')),
                    Expanded(flex: 2, child: _dashColHeader('TOTAL', right: true)),
                  ]),
                ),
                const Divider(height: 1, color: AppColors.border),
                ...(() {
                  final filtered = txList.where((t) {
                    if (_salesSearchQuery.isEmpty) return true;
                    final q = _salesSearchQuery.toLowerCase();
                    final inv = billNo(t);
                    return (t.customerName?.toLowerCase().contains(q) ?? false) ||
                        t.items.any((i) => i.productName.toLowerCase().contains(q)) ||
                        t.paymentMethod.toLowerCase().contains(q) ||
                        inv.toLowerCase().contains(q) ||
                        '#$inv'.toLowerCase().contains(q);
                  }).toList();
                  return filtered.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    final invoiceNo = '#${billNo(t)}';
                    final isReturnRow = t.paymentMethod.toLowerCase() == 'refund' ||
                        t.paymentMethod.toLowerCase().startsWith('exchange-') ||
                        (t.invoiceNumber ?? '').startsWith('R-');
                    final hasExchangeItems = t.items.any((i) => i.quantity > 0);
                    // Returns carry negative quantities; show how many pieces
                    // moved rather than a confusing net of -1 or 0.
                    final itemCount = isReturnRow
                        ? t.items.fold(0, (s, i) => s + i.quantity.abs())
                        : t.items.fold(0, (s, i) => s + i.quantity);
                    final customer = (t.customerName?.isNotEmpty == true) ? t.customerName! : '—';
                    final payLabel = isReturnRow
                        ? (hasExchangeItems ? 'Exchange' : 'Refund')
                        : {'cash': 'Cash', 'card': 'Card', 'upi': 'UPI/QR', 'hybrid': 'Hybrid'}[t.paymentMethod] ?? t.paymentMethod;
                    return Column(children: [
                      InkWell(
                        onTap: () => _showTransactionDetail(t),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          child: Row(children: [
                            Expanded(flex: 3, child: Text(fmtDate(t.createdAt), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                            Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(invoiceNo,
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary)),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 3,
                                      children: [
                                        for (final badge
                                            in _billBadges(txList, t))
                                          _badgeChip(badge.$1, badge.$2),
                                      ],
                                    ),
                                  ],
                                )),
                            Expanded(flex: 4, child: Text(customer, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark), overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 2, child: Text('$itemCount item${itemCount == 1 ? '' : 's'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                            Expanded(flex: 2, child: Text(payLabel, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark))),
                            Expanded(flex: 2, child: Text(_fmtComma(t.total), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark))),
                          ]),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                    ]);
                  });
                })(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showTransactionDetail(TransactionRecord t) {
    final payLabel = {'cash': 'Cash', 'card': 'Card', 'upi': 'UPI/QR', 'hybrid': 'Hybrid'}[t.paymentMethod] ?? t.paymentMethod;
    final dt = t.createdAt;
    final dateStr = '${dt.day.toString().padLeft(2,'0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month-1]} ${dt.year}';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final timeStr = '$h:${dt.minute.toString().padLeft(2,'0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
    final invoiceNo = '#${billNo(t)}';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(invoiceNo, style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text('$dateStr · $timeStr', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)),
                    child: Text(payLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ]),
              ),
              // ── Customer row ─────────────────────────────────────────────
              if (t.customerName?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textMuted)),
                    const SizedBox(width: 10),
                    Text(t.customerName!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    if (t.customerPhone?.isNotEmpty == true) ...[
                      const SizedBox(width: 8),
                      Text(t.customerPhone!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ]),
                ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.border),
              // ── Items ────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  child: Column(children: [
                    // Column headers
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Row(children: [
                        Expanded(flex: 5, child: Text('Item', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                        SizedBox(width: 40, child: Text('Qty', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                        SizedBox(width: 80, child: Text('Price', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                        SizedBox(width: 80, child: Text('Amount', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    ...t.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(children: [
                        Expanded(flex: 5, child: Text(item.productName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark))),
                        SizedBox(width: 40, child: Text('×${item.quantity}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                        SizedBox(width: 80, child: Text('$_currencySymbol${item.price.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                        SizedBox(width: 80, child: Text('$_currencySymbol${item.total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark))),
                      ]),
                    )),
                  ]),
                ),
              ),
              // ── Totals ───────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: Column(children: [
                  _txDetailRow('Subtotal', '$_currencySymbol${t.subtotal.toStringAsFixed(2)}'),
                  if (t.discountAmount > 0) _txDetailRow('Discount', '-$_currencySymbol${t.discountAmount.toStringAsFixed(2)}', valueColor: Colors.green),
                  if (t.taxAmount > 0) _txDetailRow('Tax ($_taxLabel)', '$_currencySymbol${t.taxAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('Total', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark))),
                    Text('$_currencySymbol${t.total.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ]),
                ]),
              ),
              // ── Actions ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(children: [
                  IconButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (c2) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text('Delete Transaction?', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16)),
                          content: Text('This will permanently remove this transaction.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c2, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c2, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && ctx.mounted) {
                        Navigator.pop(ctx);
                        await _deleteTransaction(t.id);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                    tooltip: 'Delete',
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(10)),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text('Close', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _printRecord(t); },
                      icon: const Icon(Icons.print_outlined, size: 15),
                      label: Text('Print', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(String id) async {
    await LocalDbService.deleteTransaction(id);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('transactions')
            .delete()
            .eq('id', id)
            .eq('user_id', userId);
      }
    } catch (_) {}
    _loadDashboardData();
  }

  // ── Customer detail popup ─────────────────────────────────────────────────

  void _showCustomerDetail(Customer c) async {
    final txs = await LocalDbService.getTransactionsByCustomer(c.name, c.phone);
    final creditBalance = c.phone?.isNotEmpty == true
        ? await LocalDbService.getCustomerCredit(c.phone!)
        : c.creditBalance;
    if (!mounted) return;
    final totalSpent = txs.fold<double>(0, (s, t) => s + t.total);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.person_rounded, size: 22, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(
                      c.phone?.isNotEmpty == true ? c.phone! : 'No phone',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_fmtComma(totalSpent),
                        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Text('lifetime spent', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(children: [
                  _custStatChip(Icons.receipt_long_outlined, '${txs.length} orders'),
                  const SizedBox(width: 8),
                  _custStatChip(Icons.calendar_today_outlined, 'Since ${_fmtDate(c.createdAt)}'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: creditBalance > 0 ? const Color(0xFFFFF3E0) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 12,
                          color: creditBalance > 0 ? const Color(0xFFE65100) : AppColors.textMuted),
                      const SizedBox(width: 5),
                      Text('Due ${_fmtComma(creditBalance)}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                              color: creditBalance > 0 ? const Color(0xFFE65100) : AppColors.textMuted)),
                    ]),
                  ),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
              // ── Transaction list ──────────────────────────────────────────
              if (txs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No transactions found', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: SingleChildScrollView(
                    child: Column(
                      children: txs.map((t) {
                        final dt = t.createdAt;
                        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                        final dateStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
                        final timeStr = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
                        final payLabel = t.paymentMethod == 'cash' ? 'Cash'
                            : t.paymentMethod == 'card' ? 'Card'
                            : t.paymentMethod == 'upi'  ? 'UPI'
                            : t.paymentMethod.toUpperCase();
                        return Column(children: [
                          InkWell(
                            onTap: () => _showTransactionDetail(t),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('$dateStr · $timeStr',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                  const SizedBox(height: 3),
                                  Text(
                                    t.items.map((i) => i.productName).join(', '),
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ])),
                                const SizedBox(width: 12),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(_fmtComma(t.total),
                                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)),
                                    child: Text(payLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  ),
                                ]),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                              ]),
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              // ── Actions ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Row(children: [
                  IconButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (c2) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text('Delete Customer?', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16)),
                          content: Text('This will permanently remove ${c.name} and all their data.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c2, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c2, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && ctx.mounted) {
                        Navigator.pop(ctx);
                        await _deleteCustomer(c);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                    tooltip: 'Delete customer',
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(10)),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text('Close', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _custStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
      ]),
    );
  }

  Future<void> _deleteCustomer(Customer c) async {
    await LocalDbService.deleteCustomer(c.id);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('customers')
            .delete()
            .eq('id', c.id)
            .eq('user_id', userId);
      }
    } catch (_) {}
    _loadReportCustomers();
  }

  // ── Dealers: add / detail / persistence ────────────────────────────────────

  Future<void> _saveDealerAndSync(Dealer d) async {
    await LocalDbService.saveDealer(d);
    ConnectivityService.instance.syncNow();
    await _loadReportDealers();
  }

  Future<void> _deleteDealer(Dealer d) async {
    await LocalDbService.deleteDealer(d.id);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('dealers')
            .delete()
            .eq('id', d.id)
            .eq('user_id', userId);
      }
    } catch (_) {}
    await _loadReportDealers();
  }

  Widget _dealerDialogField(String label, TextEditingController ctrl,
      {String hint = '', TextInputType? keyboard}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        inputFormatters: keyboard == const TextInputType.numberWithOptions(decimal: true)
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
            : null,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
    ]);
  }

  void _showAddDealerDialog() {
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final openingCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text('Add Dealer', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                ),
              ]),
              const SizedBox(height: 20),
              _dealerDialogField('DEALER NAME', nameCtrl, hint: 'e.g. Metro Gadgetz'),
              const SizedBox(height: 14),
              _dealerDialogField('COMPANY (optional)', companyCtrl, hint: 'Distributor / firm name'),
              const SizedBox(height: 14),
              _dealerDialogField('PHONE (optional)', phoneCtrl, hint: 'Contact number', keyboard: TextInputType.phone),
              const SizedBox(height: 14),
              _dealerDialogField('OPENING BALANCE PAYABLE (optional)', openingCtrl,
                  hint: 'Amount you already owe', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 22),
              Row(children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Enter a dealer name', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    final opening = double.tryParse(openingCtrl.text) ?? 0;
                    Navigator.pop(ctx);
                    await _saveDealerAndSync(Dealer(
                      id: const Uuid().v4(),
                      name: name,
                      company: companyCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      balancePayable: opening,
                      createdAt: DateTime.now(),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text('Add Dealer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showDealerDetail(Dealer d) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 440,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                      style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  if (d.company?.isNotEmpty == true || d.phone?.isNotEmpty == true)
                    Text([d.company, d.phone].where((e) => e?.isNotEmpty == true).join(' · '),
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _dealerStatBox('Total Purchased', _fmtComma(d.totalPurchased), AppColors.textDark, AppColors.surface)),
                const SizedBox(width: 12),
                Expanded(child: _dealerStatBox('You Owe', _fmtComma(d.balancePayable),
                    d.balancePayable > 0 ? const Color(0xFFE65100) : AppColors.textDark,
                    d.balancePayable > 0 ? const Color(0xFFFFF3E0) : AppColors.surface)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _showDealerPurchaseDialog(d); },
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                  label: Text('Record Purchase', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                  onPressed: d.balancePayable > 0 ? () { Navigator.pop(ctx); _showDealerPaymentDialog(d); } : null,
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: Text('Pay Dealer', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF34C759).withValues(alpha: 0.4),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                )),
              ]),
              const SizedBox(height: 14),
              Center(child: TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _deleteDealer(d);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFFF3B30)),
                label: Text('Delete Dealer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFF3B30))),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dealerStatBox(String label, String value, Color valueColor, Color bg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: valueColor, letterSpacing: -0.5)),
    ]),
  );

  void _showDealerPurchaseDialog(Dealer d) {
    final amountCtrl = TextEditingController();
    final paidCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Record Purchase', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('from ${d.name}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 20),
              _dealerDialogField('PURCHASE AMOUNT', amountCtrl, hint: '0.00', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 14),
              _dealerDialogField('PAID NOW (optional)', paidCtrl, hint: '0.00 — leave blank if fully on credit', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 22),
              Row(children: [
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0) return;
                    final paid = (double.tryParse(paidCtrl.text) ?? 0).clamp(0, amount).toDouble();
                    Navigator.pop(ctx);
                    await LocalDbService.recordDealerPurchase(d.id, amount, paid);
                    ConnectivityService.instance.syncNow();
                    await _loadReportDealers();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  child: Text('Save', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showDealerPaymentDialog(Dealer d) {
    final amountCtrl = TextEditingController(text: d.balancePayable.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pay Dealer', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('${d.name} · you owe ${_fmtComma(d.balancePayable)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 20),
              _dealerDialogField('PAYMENT AMOUNT', amountCtrl, hint: '0.00', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 22),
              Row(children: [
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0) return;
                    Navigator.pop(ctx);
                    await LocalDbService.recordDealerPayment(d.id, amount);
                    ConnectivityService.instance.syncNow();
                    await _loadReportDealers();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF34C759), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  child: Text('Confirm Payment', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Owner / Staff access ──────────────────────────────────────────────────

  void _lockOwnerMode() {
    setState(() {
      _isOwnerMode = false;
      if (_selectedTab == 0 || _selectedTab == 3 || _selectedTab == 4) _selectedTab = 1;
    });
  }

  void _showOwnerPasscodeDialog() {
    if (_ownerPasscode.isEmpty) {
      _showSetPasscodeDialog(isFirstTime: true);
      return;
    }
    final enteredDigits = ValueNotifier<String>('');
    final keyboardFocus = FocusNode();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ValueListenableBuilder<String>(
        valueListenable: enteredDigits,
        builder: (ctx, entered, _) {
          if (entered.length == 4) {
            Future.microtask(() {
              if (entered == _ownerPasscode) {
                Navigator.pop(ctx);
                setState(() => _isOwnerMode = true);
              } else {
                enteredDigits.value = '';
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect passcode'), duration: Duration(seconds: 1)),
                );
              }
            });
          }
          return _buildPasscodeDialog('Owner Access', 'Enter 4-digit passcode', enteredDigits, ctx, keyboardFocus);
        },
      ),
    ).then((_) => keyboardFocus.dispose());
  }

  void _showSetPasscodeDialog({bool isFirstTime = false, VoidCallback? onSet}) {
    final firstDigits  = ValueNotifier<String>('');
    final secondDigits = ValueNotifier<String>('');
    final keyboardFocus = FocusNode();
    bool confirming = false;
    showDialog(
      context: context,
      barrierDismissible: !isFirstTime,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final current = confirming ? secondDigits : firstDigits;
          return ValueListenableBuilder<String>(
            valueListenable: current,
            builder: (ctx, entered, _) {
              if (entered.length == 4 && !confirming) {
                Future.microtask(() => setDialogState(() => confirming = true));
              }
              if (entered.length == 4 && confirming) {
                Future.microtask(() {
                  if (firstDigits.value == secondDigits.value) {
                    _saveNewPasscode(firstDigits.value);
                    Navigator.pop(ctx);
                    if (onSet != null) {
                      onSet();
                    } else if (isFirstTime) {
                      setState(() => _isOwnerMode = true);
                    }
                  } else {
                    secondDigits.value = '';
                    firstDigits.value  = '';
                    setDialogState(() => confirming = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passcodes did not match, try again'), duration: Duration(seconds: 2)),
                    );
                  }
                });
              }
              return _buildPasscodeDialog(
                confirming ? 'Confirm Passcode' : 'Set Owner Passcode',
                confirming ? 'Re-enter the same 4 digits' : 'Choose a 4-digit owner passcode',
                current, ctx, keyboardFocus,
              );
            },
          );
        },
      ),
    ).then((_) => keyboardFocus.dispose());
  }

  Future<void> _saveNewPasscode(String code) async {
    setState(() => _ownerPasscode = code);
    await LocalDbService.saveSettings({'owner_passcode': code});
    ConnectivityService.instance.syncNow();
  }

  Widget _buildPasscodeDialog(String title, String subtitle, ValueNotifier<String> digits, BuildContext ctx, FocusNode keyboardFocus) {
    return KeyboardListener(
      focusNode: keyboardFocus,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
          if (digits.value.isNotEmpty) {
            digits.value = digits.value.substring(0, digits.value.length - 1);
          }
        } else if (key == LogicalKeyboardKey.escape) {
          Navigator.pop(ctx);
        } else {
          final ch = event.character;
          if (ch != null && ch.length == 1 && '0123456789'.contains(ch) && digits.value.length < 4) {
            digits.value = digits.value + ch;
          }
        }
      },
      child: Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              // 4 dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < digits.value.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: filled ? AppColors.primary : const Color(0xFFCCCCCC), width: 2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.keyboard_outlined, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text('Type your passcode',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _txDetailRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
      Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? AppColors.textDark)),
    ]),
  );

  // ── Customers sub-view ─────────────────────────────────────────────────────

  Widget _buildCustomersReport() {
    final total = _reportCustomers.length;
    final withPhone = _reportCustomers.where((c) => c.phone != null && c.phone!.isNotEmpty).length;
    final now = DateTime.now();
    final newThisMonth = _reportCustomers.where((c) =>
        c.createdAt.year == now.year && c.createdAt.month == now.month).length;
    final totalCredit = _reportCustomers.fold<double>(0, (s, c) => s + c.creditBalance);

    return Column(
      children: [
        Row(children: [
          _reportSummaryCard('Total Customers',  '$total',        Icons.people_alt_outlined,     AppColors.accentBlue),
          const SizedBox(width: 16),
          _reportSummaryCard('With Phone',       '$withPhone',    Icons.phone_outlined,          AppColors.accent),
          const SizedBox(width: 16),
          _reportSummaryCard('New This Month',   '$newThisMonth', Icons.person_add_alt_1_outlined, const Color(0xFF8B5CF6)),
          if (totalCredit > 0) ...[
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showCreditOnly = !_showCreditOnly),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _showCreditOnly ? const Color(0xFFE65100) : AppColors.border, width: _showCreditOnly ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFE65100).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFFE65100)),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_fmtComma(totalCredit), style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5)),
                      Text('Total Credit Due', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textMuted)),
                    ]),
                  ]),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('All Customers', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text(_showCreditOnly ? 'Showing credit due customers' : '${_reportCustomers.length} records',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w300,
                          color: _showCreditOnly ? const Color(0xFFE65100) : AppColors.textMuted)),
                  if (_showCreditOnly) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _showCreditOnly = false),
                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE65100)),
                    ),
                  ],
                ])),
                const SizedBox(width: 16),
                SizedBox(
                  width: 240,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.search_rounded, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 7),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _customerSearchQuery = v),
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                          decoration: InputDecoration(
                            hintText: 'Search name or phone...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_customerSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _customerSearchQuery = ''),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.close_rounded, size: 13, color: AppColors.textMuted),
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                _printIconBtn(() => _printCustomersTable(_reportCustomers)),
              ]),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(children: [
                  Expanded(flex: 1, child: _dashColHeader('#')),
                  Expanded(flex: 4, child: _dashColHeader('NAME')),
                  Expanded(flex: 3, child: _dashColHeader('PHONE')),
                  Expanded(flex: 3, child: _dashColHeader('CREDIT DUE')),
                  Expanded(flex: 3, child: _dashColHeader('ADDED ON', right: true)),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
              if (_reportCustomers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No customers yet', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  ),
                )
              else
                ...(() {
                  var filtered = _showCreditOnly
                      ? _reportCustomers.where((c) => c.creditBalance > 0).toList()
                      : _reportCustomers;
                  if (_customerSearchQuery.isNotEmpty) {
                    final q = _customerSearchQuery.toLowerCase();
                    filtered = filtered.where((c) =>
                        c.name.toLowerCase().contains(q) ||
                        (c.phone?.toLowerCase().contains(q) ?? false)).toList();
                  }
                  if (filtered.isEmpty) return [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No results for "$_customerSearchQuery"', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                    )
                  ];
                  return filtered.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  return Column(children: [
                    InkWell(
                      onTap: () => _showCustomerDetail(c),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                        child: Row(children: [
                          Expanded(flex: 1, child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                          Expanded(flex: 4, child: Text(c.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark))),
                          Expanded(flex: 3, child: Text(
                            c.phone?.isNotEmpty == true ? c.phone! : '—',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                          )),
                          Expanded(flex: 3, child: c.creditBalance > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(_fmtComma(c.creditBalance),
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFE65100))),
                              )
                            : Text('—', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                          Expanded(flex: 3, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text(
                              _fmtDate(c.createdAt),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                          ])),
                        ]),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                  ]);
                }).toList();
                })(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Dealers sub-view (suppliers) ────────────────────────────────────────────

  Widget _buildDealersReport() {
    final total = _reportDealers.length;
    final totalPurchased = _reportDealers.fold<double>(0, (s, d) => s + d.totalPurchased);
    final totalPayable = _reportDealers.fold<double>(0, (s, d) => s + d.balancePayable);

    return Column(
      children: [
        Row(children: [
          _reportSummaryCard('Total Dealers',    '$total',                  Icons.local_shipping_outlined, AppColors.accentBlue),
          const SizedBox(width: 16),
          _reportSummaryCard('Total Purchased',  _fmtComma(totalPurchased), Icons.shopping_bag_outlined,   AppColors.accent),
          if (totalPayable > 0) ...[
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showPayableOnly = !_showPayableOnly),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _showPayableOnly ? const Color(0xFFE65100) : AppColors.border, width: _showPayableOnly ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFE65100).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFFE65100)),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_fmtComma(totalPayable), style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5)),
                      Text('You Owe (Payable)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textMuted)),
                    ]),
                  ]),
                ),
              ),
            ),
          ] else
            const Expanded(child: SizedBox()),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('All Dealers', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Row(children: [
                    Text(_showPayableOnly ? 'Showing dealers you owe' : '${_reportDealers.length} records',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w300,
                            color: _showPayableOnly ? const Color(0xFFE65100) : AppColors.textMuted)),
                    if (_showPayableOnly) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _showPayableOnly = false),
                        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE65100)),
                      ),
                    ],
                  ]),
                ])),
                const SizedBox(width: 16),
                SizedBox(
                  width: 240,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.search_rounded, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 7),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _dealerSearchQuery = v),
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                          decoration: InputDecoration(
                            hintText: 'Search name or company...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_dealerSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _dealerSearchQuery = ''),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.close_rounded, size: 13, color: AppColors.textMuted),
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showAddDealerDialog,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('Add Dealer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(children: [
                  Expanded(flex: 1, child: _dashColHeader('#')),
                  Expanded(flex: 4, child: _dashColHeader('DEALER')),
                  Expanded(flex: 3, child: _dashColHeader('PURCHASED')),
                  Expanded(flex: 3, child: _dashColHeader('YOU OWE')),
                  Expanded(flex: 2, child: _dashColHeader('', right: true)),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
              if (_reportDealers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(children: [
                      Text('No dealers yet', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      Text('Add suppliers you buy stock from', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    ]),
                  ),
                )
              else
                ...(() {
                  var filtered = _showPayableOnly
                      ? _reportDealers.where((d) => d.balancePayable > 0).toList()
                      : _reportDealers;
                  if (_dealerSearchQuery.isNotEmpty) {
                    final q = _dealerSearchQuery.toLowerCase();
                    filtered = filtered.where((d) =>
                        d.name.toLowerCase().contains(q) ||
                        (d.company?.toLowerCase().contains(q) ?? false) ||
                        (d.phone?.toLowerCase().contains(q) ?? false)).toList();
                  }
                  if (filtered.isEmpty) return [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No results for "$_dealerSearchQuery"', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))),
                    )
                  ];
                  return filtered.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    return Column(children: [
                      InkWell(
                        onTap: () => _showDealerDetail(d),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                          child: Row(children: [
                            Expanded(flex: 1, child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                            Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              if (d.company?.isNotEmpty == true)
                                Text(d.company!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            ])),
                            Expanded(flex: 3, child: Text(_fmtComma(d.totalPurchased), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark))),
                            Expanded(flex: 3, child: d.balancePayable > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)),
                                  child: Text(_fmtComma(d.balancePayable),
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFE65100))),
                                )
                              : Text('—', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                            Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                            ])),
                          ]),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                    ]);
                  }).toList();
                })(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Inventory sub-view ─────────────────────────────────────────────────────

  Widget _buildInventoryReport() {
    final totalProducts = _products.length;
    final totalStock = _products.fold<int>(0, (sum, p) => sum + p.stock);
    final totalValue = _products.fold<double>(0, (sum, p) => sum + p.price * p.stock);
    final lowStock = _products.where((p) => p.stock > 0 && p.stock <= 5).length;
    final outOfStock = _products.where((p) => p.stock == 0).length;

    return Column(
      children: [
        Row(children: [
          _reportSummaryCard('Total Products',  '$totalProducts',                     Icons.inventory_2_outlined,    AppColors.accentBlue),
          const SizedBox(width: 16),
          _reportSummaryCard('Total Stock',     '$totalStock units',                  Icons.layers_outlined,         AppColors.accent),
          const SizedBox(width: 16),
          _reportSummaryCard('Stock Value',     '$_currencySymbol${totalValue.toStringAsFixed(2)}', Icons.attach_money_rounded, const Color(0xFF059669), currencyIcon: _currencySymbol),
          const SizedBox(width: 16),
          _reportSummaryCard('Low / Out',       '$lowStock / $outOfStock',            Icons.warning_amber_rounded,   const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Product Inventory', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text('${_products.length} items', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.textMuted)),
                ])),
                _printIconBtn(() => _printInventoryTable(_products)),
              ]),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(children: [
                  Expanded(flex: 1, child: _dashColHeader('#')),
                  Expanded(flex: 4, child: _dashColHeader('PRODUCT')),
                  Expanded(flex: 2, child: _dashColHeader('CATEGORY')),
                  Expanded(flex: 2, child: _dashColHeader('SKU')),
                  Expanded(flex: 2, child: _dashColHeader('PRICE')),
                  Expanded(flex: 1, child: _dashColHeader('STOCK')),
                  Expanded(flex: 2, child: _dashColHeader('VALUE', right: true)),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
              if (_products.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No products yet', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  ),
                )
              else
                ..._products.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  final stockColor = p.stock == 0
                      ? AppColors.error
                      : p.stock <= 5
                          ? const Color(0xFFF59E0B)
                          : AppColors.accent;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      child: Row(children: [
                        Expanded(flex: 1, child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
                        Expanded(flex: 4, child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 22, height: 22,
                              child: p.emoji.startsWith('/')
                                  ? Image.file(File(p.emoji), fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _SmallInitialsBox(name: p.name))
                                  : _SmallInitialsBox(name: p.name),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(child: Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark), overflow: TextOverflow.ellipsis)),
                        ])),
                        Expanded(flex: 2, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(100)),
                          child: Text(p.category, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                        )),
                        Expanded(flex: 2, child: Text(p.sku, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))),
                        Expanded(flex: 2, child: Text('$_currencySymbol${p.price.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark))),
                        Expanded(flex: 1, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: stockColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text('${p.stock}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: stockColor)),
                        )),
                        Expanded(flex: 2, child: Text(
                          '$_currencySymbol${(p.price * p.stock).toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        )),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                  ]);
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ── Account sub-view ───────────────────────────────────────────────────────


  Widget _reportPeriodBtn(String label) {
    final active = _reportSalesPeriod == label;
    return GestureDetector(
      onTap: () => setState(() => _reportSalesPeriod = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textMuted)),
      ),
    );
  }

  Widget _reportSummaryCard(String label, String value, IconData icon, Color color, {String? currencyIcon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: currencyIcon != null
                ? Center(child: Text(currencyIcon, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)))
                : Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5)),
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textMuted)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Product Card ─────────────────────────────────────────────────────────────

String _productInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty) return '?';
  if (words.length == 1) return words[0].substring(0, words[0].length.clamp(1, 2)).toUpperCase();
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

Color _initialsColor(String name) => const Color(0xFFF1F5F9);

Color _initialsFgColor(Color bg) => const Color(0xFF1E293B);

// Hover shadow wrapper for search bar
class _HoverShadowBox extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  const _HoverShadowBox({required this.child, this.borderRadius = 14});
  @override
  State<_HoverShadowBox> createState() => _HoverShadowBoxState();
}
class _HoverShadowBoxState extends State<_HoverShadowBox> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _hovered
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 16, spreadRadius: 0, offset: const Offset(0, 4))]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}

// Hover-aware nav tab
class _NavHoverTab extends StatefulWidget {
  final bool selected;
  final VoidCallback onTap;
  final String label;
  const _NavHoverTab({required this.selected, required this.onTap, required this.label});
  @override
  State<_NavHoverTab> createState() => _NavHoverTabState();
}
class _NavHoverTabState extends State<_NavHoverTab> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.accentBlue.withValues(alpha: 0.1)
                : _hovered
                    ? Colors.black.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(widget.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: widget.selected
                    ? AppColors.accentBlue
                    : _hovered
                        ? AppColors.textDark
                        : AppColors.textMuted.withValues(alpha: 0.7),
              )),
        ),
      ),
    );
  }
}

// Hover-aware category chip
class _CategoryChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}
class _CategoryChipState extends State<_CategoryChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primary
                : _hovered
                    ? const Color(0xFFEEF2FF)
                    : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(widget.label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.8,
                color: widget.selected
                    ? Colors.white
                    : _hovered
                        ? AppColors.textDark
                        : AppColors.textMuted,
              )),
        ),
      ),
    );
  }
}

/// One editable quotation line: name + unit price + quantity.
class _QuoteLine {
  final TextEditingController name;
  final TextEditingController price;
  int qty;

  /// Set when the line came from the product picker (used by the
  /// Return/Exchange flow so stock adjusts on the right product/variant).
  String? productId;
  String? variantIdRef;

  _QuoteLine({String initialName = '', String initialPrice = '', this.qty = 1})
      : name = TextEditingController(text: initialName),
        price = TextEditingController(text: initialPrice);

  double get priceValue => double.tryParse(price.text.trim()) ?? 0;
  double get total => priceValue * qty;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

// Hover-aware dropdown nav tab (Reports / Utilities)
class _DropdownNavHover extends StatefulWidget {
  final bool selected;
  final String label;
  const _DropdownNavHover({required this.selected, required this.label});
  @override
  State<_DropdownNavHover> createState() => _DropdownNavHoverState();
}
class _DropdownNavHoverState extends State<_DropdownNavHover> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.accentBlue.withValues(alpha: 0.1)
              : _hovered
                  ? Colors.black.withValues(alpha: 0.05)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: widget.selected
                    ? AppColors.accentBlue
                    : _hovered
                        ? AppColors.textDark
                        : AppColors.textMuted.withValues(alpha: 0.7),
              )),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: widget.selected
                  ? AppColors.accentBlue
                  : _hovered
                      ? AppColors.textDark
                      : AppColors.textMuted.withValues(alpha: 0.7)),
        ]),
      ),
    );
  }
}

class _ProductInitialsBox extends StatelessWidget {
  final String name;
  final double radius;
  const _ProductInitialsBox({required this.name, this.radius = 15});

  @override
  Widget build(BuildContext context) {
    final bg = _initialsColor(name);
    final fg = _initialsFgColor(bg);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Center(
        child: Text(
          name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 52,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B).withValues(alpha: 0.12),
            height: 1,
          ),
        ),
      ),
    );
  }
}

// Small (22×22) initials used in inventory list rows.
class _SmallInitialsBox extends StatelessWidget {
  final String name;
  const _SmallInitialsBox({required this.name});

  @override
  Widget build(BuildContext context) {
    final bg = _initialsColor(name);
    final fg = _initialsFgColor(bg);
    return Container(
      color: bg,
      child: Center(
        child: Text(
          _productInitials(name),
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
        ),
      ),
    );
  }
}

// Medium (44×44) initials used in the product management grid.
class _MediumInitialsBox extends StatelessWidget {
  final String name;
  final double radius;
  const _MediumInitialsBox({required this.name, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final bg = _initialsColor(name);
    final fg = _initialsFgColor(bg);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          _productInitials(name),
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
        ),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final String currencySymbol;
  final bool variantsExpanded;
  final VoidCallback? onVariantArrowTap;
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.currencySymbol,
    this.variantsExpanded = false,
    this.onVariantArrowTap,
  });
  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final variants = widget.product.variants;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hovered ? AppColors.accentBlue : AppColors.border),
            boxShadow: _hovered
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
                : [BoxShadow(color: AppColors.cardShadow, blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji / image area
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: widget.product.emoji.startsWith('/')
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                              child: Image.file(File(widget.product.emoji),
                                  width: double.infinity, height: double.infinity, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _ProductInitialsBox(name: widget.product.name, radius: 15)))
                          : _ProductInitialsBox(name: widget.product.name, radius: 15),
                    ),
                    Consumer<CartProvider>(
                      builder: (_, cart, __) {
                        final hasVariants = variants.isNotEmpty;
                        final totalStock = hasVariants ? variants.fold<int>(0, (s, v) => s + v.stock) : widget.product.stock;
                        final inCart = cart.quantityInCart(widget.product.id);
                        final remaining = (totalStock - inCart).clamp(0, totalStock);
                        final outOfStock = remaining == 0;
                        return Stack(children: [
                          Positioned(
                            top: 10, right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: outOfStock ? AppColors.error : AppColors.primary, borderRadius: BorderRadius.circular(4)),
                              child: Text(outOfStock ? 'OUT OF STOCK' : 'STOCK: ${remaining.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.inter(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            ),
                          ),
                          // Add / tune button on hover
                          Positioned(
                            bottom: 10, right: 10,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _hovered ? 1.0 : 0.0,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: outOfStock ? AppColors.textMuted : AppColors.accentBlue,
                                  shape: BoxShape.circle,
                                  boxShadow: outOfStock ? [] : [BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                child: Icon(hasVariants ? Icons.tune_rounded : Icons.add, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                          // Variant name chips
                          if (hasVariants)
                            Positioned(
                              left: 8, bottom: 8, right: 52,
                              child: Wrap(spacing: 3, runSpacing: 3, children: [
                                ...variants.take(3).map((v) {
                                  final vInCart = cart.quantityInCartForVariant(widget.product.id, v.id);
                                  final vOut = (v.stock - vInCart) <= 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(color: vOut ? AppColors.error : AppColors.success, borderRadius: BorderRadius.circular(4)),
                                    child: Text(v.name.isEmpty ? 'Variant' : v.name, style: GoogleFonts.inter(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                                  );
                                }),
                                if (variants.length > 3)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(4)),
                                    child: Text('+${variants.length - 3}', style: GoogleFonts.inter(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                                  ),
                              ]),
                            ),
                          // Slide arrow to expand/collapse variant cards
                          if (hasVariants)
                            Positioned(
                              right: 6, top: 0, bottom: 0,
                              child: Center(
                                child: GestureDetector(
                                  onTap: widget.onVariantArrowTap,
                                  child: Container(
                                    width: 24, height: 24,
                                    decoration: BoxDecoration(
                                      color: widget.variantsExpanded ? AppColors.primary : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.border),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 1))],
                                    ),
                                    child: AnimatedRotation(
                                      turns: widget.variantsExpanded ? 0.5 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(Icons.chevron_right_rounded, size: 18, color: widget.variantsExpanded ? Colors.white : AppColors.primary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ]);
                      },
                    ),
                  ],
                ),
              ),
              // Info area
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.1)),
                    const SizedBox(height: 2),
                    Text('SKU: ${widget.product.sku}'.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w300, color: AppColors.textMuted.withValues(alpha: 0.7), letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    // Base price, or a price range when variants differ.
                    Text(() {
                      if (variants.isEmpty) return fmtMoney(widget.currencySymbol, widget.product.price);
                      final prices = variants.map((v) => v.price).toList()..sort();
                      return prices.first == prices.last
                          ? fmtMoney(widget.currencySymbol, prices.first)
                          : '${fmtMoney(widget.currencySymbol, prices.first, decimals: 0)}–${fmtMoney('', prices.last, decimals: 0)}';
                    }(), style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Variant Card (slides out beside its product in the grid) ────────────────

class _VariantCard extends StatefulWidget {
  final Product product;
  final ProductVariant variant;
  final String currencySymbol;
  const _VariantCard({
    required this.product,
    required this.variant,
    required this.currencySymbol,
  });
  @override
  State<_VariantCard> createState() => _VariantCardState();
}

class _VariantCardState extends State<_VariantCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCart = cart.quantityInCartForVariant(widget.product.id, widget.variant.id);
    final remaining = (widget.variant.stock - inCart).clamp(0, widget.variant.stock);
    final outOfStock = remaining == 0;
    final label = widget.variant.name.isEmpty ? 'Variant' : widget.variant.name;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(28 * (1 - t), 0), child: child)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          // Tap always adds (matches non-variant product cards, which aren't
          // stock-gated); the OUT OF STOCK badge stays as a visual warning.
          onTap: () => context.read<CartProvider>().addProduct(widget.product, variant: widget.variant),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _hovered ? AppColors.accentBlue : AppColors.border),
              boxShadow: _hovered
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
                  : [BoxShadow(color: AppColors.cardShadow, blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(
                      child: widget.product.emoji.startsWith('/')
                          ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                              child: Image.file(File(widget.product.emoji), width: double.infinity, height: double.infinity, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _ProductInitialsBox(name: label, radius: 15)))
                          : _ProductInitialsBox(name: label, radius: 15),
                    ),
                    Positioned(top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: outOfStock ? AppColors.error : AppColors.primary, borderRadius: BorderRadius.circular(4)),
                        child: Text(outOfStock ? 'OUT OF STOCK' : 'STOCK: ${remaining.toString().padLeft(2, '0')}',
                            style: GoogleFonts.inter(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    ),
                    Positioned(top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(4)),
                        child: Text('VARIANT', style: GoogleFonts.inter(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    ),
                    Positioned(bottom: 10, right: 10,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hovered ? 1.0 : 0.0,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: outOfStock ? AppColors.textMuted : AppColors.accentBlue, shape: BoxShape.circle,
                            boxShadow: outOfStock ? [] : [BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.1)),
                      const SizedBox(height: 2),
                      Text(widget.product.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w300, color: AppColors.textMuted.withValues(alpha: 0.7), letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Text(fmtMoney(widget.currencySymbol, widget.variant.price),
                          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cart Row ─────────────────────────────────────────────────────────────────

class _CartRow extends StatefulWidget {
  final CartItem item;
  final CartProvider cart;
  final String currencySymbol;
  const _CartRow({super.key, required this.item, required this.cart, required this.currencySymbol});
  @override
  State<_CartRow> createState() => _CartRowState();
}

class _CartRowState extends State<_CartRow> {
  bool _editing = false;
  late TextEditingController _qtyCtrl;
  final _qtyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '${widget.item.quantity}');
    _qtyFocus.addListener(() {
      if (!_qtyFocus.hasFocus && _editing) _commitEdit();
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  void _commitEdit() {
    final v = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (v > 0) {
      widget.cart.setQuantity(widget.item.lineId, v, stock: widget.item.availableStock);
    } else {
      widget.cart.removeItem(widget.item.lineId);
    }
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) _qtyCtrl.text = '${widget.item.quantity}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    widget.item.variant != null
                        ? '${widget.item.product.name} · ${widget.item.variant!.name}'
                        : widget.item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(height: 2),
                Text('SKU: ${widget.item.displaySku}'.toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w300,
                        color: AppColors.textMuted.withValues(alpha: 0.6), letterSpacing: 0.5)),
              ],
            ),
          ),
          // Qty controls
          Container(
            width: 90,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _editing ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _qtyBtn(Icons.remove, () => widget.cart.decrement(widget.item.lineId)),
                GestureDetector(
                  onTap: () {
                    setState(() => _editing = true);
                    _qtyCtrl.text = '${widget.item.quantity}';
                    _qtyCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _qtyCtrl.text.length);
                    Future.microtask(() => _qtyFocus.requestFocus());
                  },
                  child: SizedBox(
                    width: 32,
                    child: _editing
                        ? TextField(
                            controller: _qtyCtrl,
                            focusNode: _qtyFocus,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _commitEdit(),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                          )
                        : Text('${widget.item.quantity}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ),
                _qtyBtn(Icons.add, () => widget.cart.increment(widget.item.lineId, stock: widget.item.availableStock)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtMoney(widget.currencySymbol, widget.item.total),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                Text('${fmtMoney(widget.currencySymbol, widget.item.unitPrice)}/${widget.item.product.unit}',
                    style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted.withValues(alpha: 0.6), fontWeight: FontWeight.w300)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => widget.cart.removeItem(widget.item.lineId),
            child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 14, color: AppColors.primary),
      ),
    );
  }
}

// ── Discount Toggle ──────────────────────────────────────────────────────────

class _DiscountToggle extends StatefulWidget {
  final CartProvider cart;
  final String currencySymbol;
  final FocusNode focusNode;
  const _DiscountToggle({required this.cart, required this.currencySymbol, required this.focusNode});
  @override
  State<_DiscountToggle> createState() => _DiscountToggleState();
}

class _DiscountToggleState extends State<_DiscountToggle> {
  final _ctrl = TextEditingController();
  DiscountType _type = DiscountType.percent;
  bool _showInput = false;

  void _onTypeBtn(DiscountType type) {
    setState(() {
      if (_type == type && _showInput) {
        _showInput = false;
        widget.focusNode.unfocus();
      } else {
        _type = type;
        _showInput = true;
      }
    });
    if (_showInput) {
      Future.microtask(() => widget.focusNode.requestFocus());
    }
  }

  void _apply() {
    final v = double.tryParse(_ctrl.text) ?? 0;
    widget.cart.applyDiscount(v, _type);
    setState(() => _showInput = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // %/₹ toggle
        Container(
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _typeBtn('%', DiscountType.percent),
              _typeBtn(widget.currencySymbol, DiscountType.fixed),
            ],
          ),
        ),
        // Animated input + apply button
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _showInput
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 52,
                      height: 28,
                      child: TextField(
                        controller: _ctrl,
                        focusNode: widget.focusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        style: GoogleFonts.inter(fontSize: 12),
                        textAlign: TextAlign.center,
                        onSubmitted: (_) => _apply(),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                  color: AppColors.accentBlue, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _apply,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                            child: Text('APPLY',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5))),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _typeBtn(String label, DiscountType type) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => _onTypeBtn(type),
      child: Container(
        width: 26,
        height: 22,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: 0.1),
                      blurRadius: 2)
                ]
              : null,
          border: selected
              ? Border.all(
                  color: AppColors.border.withValues(alpha: 0.5))
              : null,
        ),
        child: Center(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textMuted
                            .withValues(alpha: 0.6)))),
      ),
    );
  }
}

// ── Premium Bar Chart ─────────────────────────────────────────────────────────

class _PremiumBarChart extends StatefulWidget {
  final List<(String, double)> bars;
  final String currencySymbol;
  const _PremiumBarChart({required this.bars, required this.currencySymbol});
  @override
  State<_PremiumBarChart> createState() => _PremiumBarChartState();
}

class _PremiumBarChartState extends State<_PremiumBarChart> {
  int? _hovered;
  static const _barH = 120.0;
  static const _tipH = 28.0;
  static const _lblH = 20.0;
  static const _yW   = 44.0;

  String _fmt(double v) {
    final s = widget.currencySymbol;
    if (v >= 10000000) return '$s${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '$s${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '$s${(v / 1000).toStringAsFixed(1)}K';
    return '$s${v.toStringAsFixed(0)}';
  }

  String _fmtFull(double v) {
    final s = widget.currencySymbol;
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$s$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    if (bars.isEmpty) {
      return SizedBox(
        height: _tipH + _barH + _lblH,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bar_chart_rounded, size: 36, color: AppColors.border),
            const SizedBox(height: 8),
            Text('No data for this period',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          ]),
        ),
      );
    }

    final maxVal = bars.fold(0.0, (m, b) => b.$2 > m ? b.$2 : m);
    final yTicks = List.generate(5, (i) => maxVal * (4 - i) / 4);

    return SizedBox(
      height: _tipH + _barH + _lblH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Y-axis labels
          SizedBox(
            width: _yW,
            child: Stack(
              children: yTicks.asMap().entries.map((e) {
                return Positioned(
                  top: _tipH + (e.key / 4) * _barH - 8,
                  right: 6,
                  child: Text(
                    e.key == 4 ? '0' : _fmt(e.value),
                    style: GoogleFonts.inter(fontSize: 8.5, color: AppColors.textMuted),
                    textAlign: TextAlign.right,
                  ),
                );
              }).toList(),
            ),
          ),
          // Chart area
          Expanded(
            child: Stack(
              children: [
                // Horizontal grid lines
                ...yTicks.asMap().entries.map((e) => Positioned(
                  top: _tipH + (e.key / 4) * _barH,
                  left: 0, right: 0,
                  height: e.key == 4 ? 1.5 : 1,
                  child: Container(
                    color: e.key == 4
                        ? const Color(0xFFDDDDDD)
                        : const Color(0xFFF2F2F2),
                  ),
                )),
                // Bars + labels
                Positioned.fill(
                  child: Row(
                    children: bars.asMap().entries.map((e) {
                      final idx   = e.key;
                      final label = e.value.$1;
                      final val   = e.value.$2;
                      final pct   = maxVal > 0 ? val / maxVal : 0.0;
                      final isHov = _hovered == idx;
                      final anyH  = _hovered != null;

                      return Expanded(
                        child: MouseRegion(
                          cursor: val > 0 ? SystemMouseCursors.click : MouseCursor.defer,
                          onEnter: (_) => setState(() => _hovered = idx),
                          onExit:  (_) => setState(() => _hovered = null),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Tooltip (fixed height slot, fades in/out)
                              SizedBox(
                                height: _tipH,
                                child: AnimatedOpacity(
                                  opacity: isHov && val > 0 ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 140),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _fmtFull(val),
                                        style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Bar body
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 300 + idx * 35),
                                  curve: Curves.easeOut,
                                  height: val > 0
                                      ? (_barH * pct).clamp(3.0, _barH)
                                      : 1.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: val > 0
                                          ? [
                                              isHov
                                                  ? const Color(0xFF1E3A8A)
                                                  : AppColors.primary.withValues(
                                                      alpha: anyH ? 0.28 : 1.0),
                                              isHov
                                                  ? const Color(0xFF60A5FA)
                                                  : AppColors.primary.withValues(
                                                      alpha: anyH ? 0.10 : 0.42),
                                            ]
                                          : [const Color(0xFFEEEEEE), const Color(0xFFEEEEEE)],
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6)),
                                  ),
                                ),
                              ),
                              // X label
                              SizedBox(
                                height: _lblH,
                                child: Center(
                                  child: Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: isHov ? FontWeight.w700 : FontWeight.w400,
                                      color: isHov ? AppColors.primary : AppColors.textMuted,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCatChip extends StatefulWidget {
  final String label;
  final bool selected;
  final bool editable;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _InventoryCatChip({required this.label, required this.selected, required this.editable, required this.onTap, required this.onEdit});

  @override
  State<_InventoryCatChip> createState() => _InventoryCatChipState();
}

class _InventoryCatChipState extends State<_InventoryCatChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected ? AppColors.textDark : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: widget.selected ? AppColors.textDark : AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label.toUpperCase(), style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: widget.selected ? Colors.white : AppColors.textDark,
                letterSpacing: 0.3)),
            if (widget.editable && _hovered) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onEdit,
                child: Icon(Icons.edit_rounded, size: 11,
                    color: widget.selected ? Colors.white60 : AppColors.textMuted),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}



class _BarcodePainter extends CustomPainter {
  final String data;
  _BarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final barcode = bc.Barcode.ean13();
      final elements = barcode.make(data, width: size.width, height: size.height, drawText: false);
      final paint = Paint()..color = Colors.black;
      for (final el in elements) {
        if (el is bc.BarcodeBar && el.black) {
          canvas.drawRect(Rect.fromLTWH(el.left, el.top, el.width, el.height), paint);
        }
      }
    } catch (_) {
      // Fallback for non-EAN data: draw placeholder bars
      final paint = Paint()..color = Colors.black;
      for (int i = 0; i < 30; i++) {
        if (i % 2 == 0) canvas.drawRect(Rect.fromLTWH(i * size.width / 30, 0, size.width / 60, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.data != data;
}

/// Editable draft of a product variant, backing the variants editor UI.
/// One printable barcode label: a product, or a single variant of one.
class _BarcodeTarget {
  final String key; // product id, or 'productId::variantId'
  final String name;
  final String sku;
  final String barcodeValue;
  final int stock;
  final double price;
  const _BarcodeTarget({
    required this.key,
    required this.name,
    required this.sku,
    required this.barcodeValue,
    required this.stock,
    required this.price,
  });
}

class _VariantDraft {
  final String id;
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController stock;
  final TextEditingController sku;
  final String barcodeNo;

  _VariantDraft({
    this.id = '',
    String name = '',
    String price = '',
    String stock = '',
    String sku = '',
    this.barcodeNo = '',
  })  : name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        stock = TextEditingController(text: stock),
        sku = TextEditingController(text: sku);

  static _VariantDraft fromVariant(ProductVariant v) => _VariantDraft(
        id: v.id,
        name: v.name,
        price: v.price > 0 ? v.price.toStringAsFixed(2) : '',
        stock: '${v.stock}',
        sku: v.sku,
        barcodeNo: v.barcodeNo,
      );
}
