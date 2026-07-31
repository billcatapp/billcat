import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/transaction_record.dart';

/// Builds a raw ESC/POS byte stream for a thermal receipt.
///
/// Sent to the printer with `lp -o raw`, so it bypasses the CUPS driver
/// entirely. This is deliberate: ESC/POS thermal printers are frequently
/// mis-installed with an incompatible driver (e.g. a Zebra ZPL driver that
/// prints raw PDF bytes as garbage). ESC/POS is the printer's own language, so
/// raw bytes render correctly no matter which driver the OS assigned.
///
/// Layout follows the hand-designed receipt model (July 2026): logo block,
/// centered store header with GSTIN/date/invoice id, customer block,
/// ITEM/QTY/PRICE table with names wrapping inside their column, right-aligned
/// totals, double-size GRAND TOTAL, payment row, QR code linking to the
/// digital invoice, and a centered footer.
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

  // Item table column widths (derived from [cols]).
  int get _priceW => cols >= 48 ? 12 : 10;
  int get _qtyW => 5;
  int get _nameW => cols - _qtyW - _priceW - 2; // 2 single-space gutters

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
    String qrLink = '',
    List<int>? logoRaster,
  }) {
    final b = <int>[];
    final cur = _asciiCurrency(currencySymbol);

    b.addAll(_init());

    // ── Logo: the store's uploaded image when available, else the solid
    // square mark from the design model ──
    b.addAll(_align(1));
    if (logoRaster != null && logoRaster.isNotEmpty) {
      b.addAll(logoRaster);
    } else {
      b.addAll(_logoBlock());
    }
    b.add(_lf);

    // ── Store header (centered, double size; double-width chars span two
    // columns so the name wraps at half the paper width) ──
    b.addAll(_bold(true));
    b.addAll(_size(0x11));
    for (final l in _wrapTo(
      storeName.isEmpty ? 'RECEIPT' : storeName.toUpperCase(),
      cols ~/ 2,
    )) {
      b.addAll(_text(l));
    }
    b.addAll(_size(0x00));
    b.addAll(_bold(false));
    b.add(_lf);
    for (final l in _wrap(storeAddress)) b.addAll(_text(l));
    if (storePhone.isNotEmpty) b.addAll(_text('Phone: $storePhone'));
    if (storeGstin.isNotEmpty) b.addAll(_text('GSTIN: $storeGstin'));
    b.addAll(_text(_fmtDate(tx.createdAt)));
    if (docType.toLowerCase() == 'quotation') {
      b.addAll(_bold(true));
      b.addAll(_text('QUOTATION'));
      b.addAll(_bold(false));
    }
    b.addAll(_text('INVOICE ID: ${_invoiceId(tx)}'));

    // ── Customer block (centered, only when present) ──
    if ((tx.customerName ?? '').isNotEmpty ||
        (tx.customerPhone ?? '').isNotEmpty) {
      b.addAll(_align(0));
      b.addAll(_rule());
      b.addAll(_align(1));
      if ((tx.customerName ?? '').isNotEmpty) {
        b.addAll(_text('Customer: ${tx.customerName}'));
      }
      if ((tx.customerPhone ?? '').isNotEmpty) {
        b.addAll(_text('Phone: ${tx.customerPhone}'));
      }
    }

    // ── Item table ──
    b.addAll(_align(0));
    b.addAll(_rule());
    b.addAll(_text(_tableRow('ITEM', 'QTY', 'PRICE')));
    b.add(_lf);
    for (final it in tx.items) {
      final nameLines = _wrapTo(it.productName, _nameW);
      for (var i = 0; i < nameLines.length; i++) {
        if (i == 0) {
          b.addAll(_text(_tableRow(
            nameLines[i],
            '${it.quantity}',
            '$cur${_money(it.total)}',
          )));
        } else {
          b.addAll(_text(nameLines[i]));
        }
      }
      b.add(_lf);
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
    b.add(_lf);
    b.addAll(_rule());

    // ── GRAND TOTAL — label normal, value double width+height ──
    b.addAll(_grandTotal('GRAND TOTAL', '$cur${_money(tx.total)}'));
    b.addAll(_rule());

    // ── Payment row ──
    b.addAll(_text(_row('Payment Method', _prettyPayment(tx.paymentMethod))));
    b.addAll(_rule());

    // ── QR code → digital invoice ──
    if (qrLink.isNotEmpty) {
      b.addAll(_align(1));
      b.add(_lf);
      b.addAll(_qr(qrLink));
      b.add(_lf);
      b.addAll(_text('SCAN FOR DIGITAL INVOICE'));
      b.add(_lf);
      b.add(_lf);
    }

    // ── Footer (centered) ──
    b.addAll(_align(1));
    for (final l in _wrap(receiptFooter)) b.addAll(_text(l));
    for (final l in _wrap(storeTerms)) b.addAll(_text(l));
    if (receiptFooter.trim().isEmpty && storeTerms.trim().isEmpty) {
      b.addAll(_text('Thank you for shopping with us.'));
    }

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

  // ── Layout pieces ─────────────────────────────────────────────────────────

  /// Solid square mark approximating the model's logo tile. Uses the PC437
  /// full-block character, emitted raw because it sits outside ASCII.
  List<int> _logoBlock() {
    const block = 0xDB; // █ in codepage 437 (ESC/POS default)
    final out = <int>[];
    for (var r = 0; r < 3; r++) {
      out.addAll(List.filled(8, block));
      out.add(_lf);
    }
    return out;
  }

  /// ITEM / QTY / PRICE columns: name left in its column, qty centered,
  /// price right-aligned to the paper edge.
  String _tableRow(String name, String qty, String price) {
    final n = name.length > _nameW
        ? name.substring(0, _nameW)
        : name.padRight(_nameW);
    final qPad = _qtyW - qty.length;
    final qLeft = qPad ~/ 2;
    final q = ' ' * qLeft + qty + ' ' * (qPad - qLeft);
    final p = price.length > _priceW
        ? price.substring(0, _priceW)
        : price.padLeft(_priceW);
    return '$n $q $p';
  }

  /// GRAND TOTAL line: label at normal size, value at double width+height
  /// on the same baseline, right edge aligned (double chars span 2 columns).
  List<int> _grandTotal(String label, String value) {
    final out = <int>[];
    final pad = (cols - label.length - value.length * 2).clamp(1, cols);
    out.addAll(_encode(label + ' ' * pad));
    out.addAll(_bold(true));
    out.addAll(_size(0x11));
    out.addAll(_encode(value));
    out.addAll(_size(0x00));
    out.addAll(_bold(false));
    out.add(_lf);
    return out;
  }

  /// Rasterises PNG/JPG bytes into an ESC/POS `GS v 0` image block:
  /// scaled to [maxWidthDots] wide, composited over white, luminance-
  /// thresholded to the printer's 1-bit format. Returns null when the
  /// bytes can't be decoded, so callers can fall back to the block mark.
  static List<int>? rasterFromImageBytes(
    List<int> imageBytes, {
    int maxWidthDots = 240,
  }) {
    final decoded = img.decodeImage(Uint8List.fromList(imageBytes));
    if (decoded == null) return null;
    final im = decoded.width > maxWidthDots
        ? img.copyResize(decoded, width: maxWidthDots)
        : decoded;
    final w = im.width, h = im.height;
    final wBytes = (w + 7) ~/ 8;
    final data = List<int>.filled(wBytes * h, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = im.getPixel(x, y);
        final mx = p.maxChannelValue;
        final a = mx == 0 ? 1.0 : p.a / mx;
        final r = (mx == 0 ? 0 : p.r / mx) * 255 * a + 255 * (1 - a);
        final g = (mx == 0 ? 0 : p.g / mx) * 255 * a + 255 * (1 - a);
        final bl = (mx == 0 ? 0 : p.b / mx) * 255 * a + 255 * (1 - a);
        final lum = 0.299 * r + 0.587 * g + 0.114 * bl;
        if (lum < 160) {
          data[y * wBytes + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
    }
    return [
      _gs, 0x76, 0x30, 0x00,
      wBytes & 0xFF, (wBytes >> 8) & 0xFF,
      h & 0xFF, (h >> 8) & 0xFF,
      ...data,
    ];
  }

  /// ESC/POS model-2 QR code, module size 5, error correction M.
  List<int> _qr(String data) {
    final bytes = _encode(data);
    final len = bytes.length + 3;
    return [
      _gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00, // model 2
      _gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x05, // module size 5
      _gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31, // EC level M
      _gs, 0x28, 0x6B, len & 0xFF, (len >> 8) & 0xFF, 0x31, 0x50, 0x30,
      ...bytes, // store data
      _gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30, // print
    ];
  }

  /// "9482-A84F-912C"-style id: invoice number when set, else the first 12
  /// hex characters of the transaction id grouped 4-4-4.
  static String _invoiceId(TransactionRecord tx) {
    final inv = tx.invoiceNumber ?? '';
    if (inv.isNotEmpty) return '#$inv';
    final hex = tx.id.replaceAll('-', '').toUpperCase();
    final h = hex.padRight(12, '0').substring(0, 12);
    return '${h.substring(0, 4)}-${h.substring(4, 8)}-${h.substring(8, 12)}';
  }

  static String _prettyPayment(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'upi':
        return 'UPI';
      case 'hybrid':
        return 'Hybrid';
      default:
        return method.toUpperCase();
    }
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
  List<String> _wrap(String s) => s.trim().isEmpty ? const [] : _wrapTo(s, cols);

  /// Greedy word-wrap to [width], hard-breaking any word longer than it.
  List<String> _wrapTo(String s, int width) {
    final out = <String>[];
    for (final rawLine in s.split('\n')) {
      var line = '';
      for (final word in rawLine.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        if (line.isEmpty) {
          line = word;
        } else if (line.length + 1 + word.length <= width) {
          line = '$line $word';
        } else {
          out.add(line);
          line = word;
        }
        while (line.length > width) {
          out.add(line.substring(0, width));
          line = line.substring(width);
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
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
