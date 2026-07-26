import '../models/transaction_record.dart';

/// Builds a raw ESC/POS byte stream for a thermal receipt.
///
/// Sent to the printer with `lp -o raw`, so it bypasses the CUPS driver
/// entirely. This is deliberate: ESC/POS thermal printers are frequently
/// mis-installed with an incompatible driver (e.g. a Zebra ZPL driver that
/// prints raw PDF bytes as garbage). ESC/POS is the printer's own language, so
/// raw bytes render correctly no matter which driver the OS assigned.
///
/// Configurable for reliability across the ESC/POS printer family:
///  - [cols]  character columns: 32 for 58mm, 48 for 80mm, 64 for 112mm.
///  - [cut]   emit an auto-cut at the end (printers without a cutter set false).
///
/// Not covered: printers that don't speak ESC/POS at all (Star Line Mode /
/// StarPRNT, Zebra ZPL/EPL, TSC TSPL). Those need a different command set.
class EscPosReceipt {
  /// Character columns for the paper width. 58mm≈32, 80mm≈48, 112mm≈64.
  final int cols;

  /// Whether to send an auto-cut command at the end of the receipt.
  final bool cut;

  const EscPosReceipt({this.cols = 48, this.cut = true});

  /// Columns for a paper size string like "2 inch" / "3 inch" / "4 inch".
  /// Falls back to 80mm (48) for anything unrecognised.
  static int colsForPaper(String paper) {
    final n = paper.trim().split(RegExp(r'\s+')).first;
    switch (n) {
      case '2':
        return 32; // 58mm
      case '4':
        return 64; // 112mm
      default:
        return 48; // 80mm (3 inch)
    }
  }

  // ── ESC/POS control codes ────────────────────────────────────────────────
  static const int _esc = 0x1B;
  static const int _gs = 0x1D;
  static const int _lf = 0x0A;

  static List<int> _init() => [_esc, 0x40]; // ESC @  — reset
  static List<int> _align(int n) => [_esc, 0x61, n]; // 0 left, 1 center, 2 right
  static List<int> _bold(bool on) => [_esc, 0x45, on ? 1 : 0];
  static List<int> _size(int n) => [_gs, 0x21, n]; // GS ! n  (0x11 = 2x w+h)
  List<int> _cutCmd() => [_gs, 0x56, 0x00]; // GS V 0 — full cut

  List<int> build(
    TransactionRecord tx, {
    required String storeName,
    String storeAddress = '',
    String storePhone = '',
    String storeGstin = '',
    String receiptFooter = '',
    String taxLabel = 'GST',
    String taxRate = '',
    String currencySymbol = '',
    String storeTerms = '',
    String docType = 'Invoice',
  }) {
    final b = <int>[];
    final cur = _asciiCurrency(currencySymbol);

    b.addAll(_init());

    // ── Header (printer-centred) ──
    b.addAll(_align(1));
    b.addAll(_bold(true));
    b.addAll(_size(0x11)); // double width + height
    b.addAll(_text(storeName.isEmpty ? 'RECEIPT' : storeName));
    b.addAll(_size(0x00));
    b.addAll(_bold(false));
    for (final l in _wrap(storeAddress)) b.addAll(_text(l));
    if (storePhone.isNotEmpty) b.addAll(_text('Ph: $storePhone'));
    if (storeGstin.isNotEmpty) b.addAll(_text('GSTIN: $storeGstin'));

    // ── Document title + meta ──
    b.addAll(_align(0));
    b.addAll(_rule());
    b.addAll(_align(1));
    b.addAll(_bold(true));
    b.addAll(_text(docType.toLowerCase() == 'quotation' ? 'QUOTATION' : 'TAX INVOICE'));
    b.addAll(_bold(false));
    b.addAll(_align(0));
    if ((tx.invoiceNumber ?? '').isNotEmpty) b.addAll(_text('Invoice: #${tx.invoiceNumber}'));
    b.addAll(_text('Date: ${_fmtDate(tx.createdAt)}'));
    if ((tx.customerName ?? '').isNotEmpty) b.addAll(_text('Customer: ${tx.customerName}'));
    if ((tx.customerPhone ?? '').isNotEmpty) b.addAll(_text('Phone: ${tx.customerPhone}'));
    b.addAll(_rule());

    // ── Items ──
    b.addAll(_text(_row('Item', 'Qty  Amount')));
    b.addAll(_rule());
    for (final it in tx.items) {
      for (final l in _wrapLeft(it.productName)) b.addAll(_text(l));
      final left = '  ${it.quantity} x ${_money(it.price)}';
      b.addAll(_text(_row(left, _money(it.total))));
    }
    b.addAll(_rule());

    // ── Totals ──
    b.addAll(_text(_row('Subtotal', '$cur${_money(tx.subtotal)}')));
    if (tx.discountAmount > 0) {
      b.addAll(_text(_row('Discount', '-$cur${_money(tx.discountAmount)}')));
    }
    if (tx.taxAmount > 0) {
      final label = taxRate.isNotEmpty ? '$taxLabel ($taxRate%)' : taxLabel;
      b.addAll(_text(_row(label, '$cur${_money(tx.taxAmount)}')));
    }
    b.addAll(_bold(true));
    b.addAll(_size(0x01)); // double height only — width stays [cols]
    b.addAll(_text(_row('TOTAL', '$cur${_money(tx.total)}')));
    b.addAll(_size(0x00));
    b.addAll(_bold(false));
    b.addAll(_rule());
    b.addAll(_text('Payment: ${tx.paymentMethod.toUpperCase()}'));

    // ── Footer (centred) ──
    b.addAll(_align(1));
    for (final l in _wrap(storeTerms)) { b.add(_lf); b.addAll(_text(l)); }
    for (final l in _wrap(receiptFooter)) b.addAll(_text(l));
    b.add(_lf);
    b.addAll(_text('Thank you!'));

    // ── Feed + optional cut ──
    b.addAll([_lf, _lf, _lf]);
    if (cut) {
      b.add(_lf); // extra feed so the cut clears the last line
      b.addAll(_cutCmd());
    } else {
      b.addAll([_lf, _lf]); // no cutter: feed enough to tear off cleanly
    }
    return b;
  }

  // ── Text helpers ──────────────────────────────────────────────────────────

  /// One text line terminated by LF, encoded to a printable single-byte set.
  List<int> _text(String s) => [..._encode(s), _lf];

  /// Left label + right value padded to [cols]; truncates the label if needed.
  String _row(String left, String right) {
    final space = cols - left.length - right.length;
    if (space >= 1) return left + ' ' * space + right;
    final keep = (cols - right.length - 1).clamp(0, left.length);
    return '${left.substring(0, keep)} $right';
  }

  List<int> _rule() => _text('-' * cols);

  /// Word-wrap for centred lines (skips empty input).
  List<String> _wrap(String s) => s.trim().isEmpty ? const [] : _wrapLeft(s);

  /// Greedy word-wrap to [cols], hard-breaking any word longer than the width.
  List<String> _wrapLeft(String s) {
    final out = <String>[];
    for (final rawLine in s.split('\n')) {
      var line = '';
      for (final word in rawLine.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        if (line.isEmpty) {
          line = word;
        } else if (line.length + 1 + word.length <= cols) {
          line = '$line $word';
        } else {
          out.add(line);
          line = word;
        }
        while (line.length > cols) {
          out.add(line.substring(0, cols));
          line = line.substring(cols);
        }
      }
      if (line.isNotEmpty) out.add(line);
    }
    return out;
  }

  static String _money(double v) => v.toStringAsFixed(2);

  /// ESC/POS printers use a single-byte codepage without the rupee glyph, so
  /// render it as "Rs ". Plain-ASCII symbols pass through unchanged.
  static String _asciiCurrency(String symbol) {
    if (symbol.isEmpty) return '';
    final ascii = symbol.codeUnits.every((c) => c < 128);
    return ascii ? symbol : 'Rs ';
  }

  /// Map to the printable ASCII range; anything else becomes '?'.
  static List<int> _encode(String s) =>
      s.runes.map((r) => r < 0x20 || r > 0x7E ? 0x3F : r).toList();

  static String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
