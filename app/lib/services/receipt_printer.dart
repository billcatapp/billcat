import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
export 'package:printing/printing.dart' show Printer;
import '../models/transaction_record.dart';

// Combines product name with description on a new line for table cells.
String _itemLabel(TransactionItem i) => i.description.trim().isEmpty
    ? i.productName
    : '${i.productName}\n${i.description.trim()}';

class ReceiptPrinter {
  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _poppinsRegular;
  static pw.Font? _poppinsBold;
  static pw.Font? _serifRegular;
  static pw.Font? _serifBold;

  // Cached future so concurrent callers all await the same load, never race.
  static Future<void>? _warmFuture;

  /// Load fonts from bundled assets (no network) so first print is instant.
  static Future<void> preWarm() {
    if (_regular != null) return Future.value();
    _warmFuture ??= _doWarm();
    return _warmFuture!;
  }

  static Future<void> _doWarm() async {
    final r  = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final b  = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final pr = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    final pb = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
    final sr = await rootBundle.load('assets/fonts/SourceSerif4-Regular.ttf');
    final sb = await rootBundle.load('assets/fonts/SourceSerif4-Bold.ttf');
    _regular        = pw.Font.ttf(r);
    _bold           = pw.Font.ttf(b);
    _poppinsRegular = pw.Font.ttf(pr);
    _poppinsBold    = pw.Font.ttf(pb);
    _serifRegular   = pw.Font.ttf(sr);
    _serifBold      = pw.Font.ttf(sb);
  }

  static Future<void> printReceipt(
    TransactionRecord tx, {
    Printer? printer,
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    required String paperSize,
    String orientation = 'Portrait',
    String layout = 'Classic',
    String storeTerms = '',
    String logoPath = '',
  }) async {
    final pdfBytes = await buildPdf(
      tx,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      storeGstin: storeGstin,
      receiptFooter: receiptFooter,
      taxLabel: taxLabel,
      taxRate: taxRate,
      currencySymbol: currencySymbol,
      paperSize: paperSize,
      orientation: orientation,
      layout: layout,
      storeTerms: storeTerms,
      logoPath: logoPath,
    );
    // Yield to the event loop so macOS finishes rendering the current frame
    // before the native print panel is presented — prevents spinning cursor.
    await Future.delayed(const Duration(milliseconds: 80));
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Receipt-${tx.id.substring(0, 6).toUpperCase()}',
    );
  }

  static Future<void> exportPdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    required String paperSize,
    String orientation = 'Portrait',
    String layout = 'Classic',
    String storeTerms = '',
    String logoPath = '',
  }) async {
    final pdfBytes = await buildPdf(
      tx,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      storeEmail: storeEmail,
      storeGstin: storeGstin,
      receiptFooter: receiptFooter,
      taxLabel: taxLabel,
      taxRate: taxRate,
      currencySymbol: currencySymbol,
      paperSize: paperSize,
      orientation: orientation,
      layout: layout,
      storeTerms: storeTerms,
      logoPath: logoPath,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Receipt-${tx.id.substring(0, 6).toUpperCase()}.pdf',
    );
  }

  static Future<Uint8List> buildPdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    required String paperSize,
    String orientation = 'Portrait',
    String layout = 'Classic',
    String storeTerms = '',
    String logoPath = '',
    String storeUpiId = '',
    String docType = 'Invoice',
  }) async {
    // ── Named-layout routers ──────────────────────────────────────────────
    final _sharedArgs = (
      storeName: storeName, storeAddress: storeAddress,
      storePhone: storePhone, storeEmail: storeEmail, storeGstin: storeGstin,
      receiptFooter: receiptFooter, taxLabel: taxLabel, taxRate: taxRate,
      currencySymbol: currencySymbol, storeTerms: storeTerms, logoPath: logoPath,
      storeUpiId: storeUpiId,
    );

    switch (layout) {
      case 'Classic':
        return _buildClassicInvoicePdf(tx, storeName: _sharedArgs.storeName, storeAddress: _sharedArgs.storeAddress, storePhone: _sharedArgs.storePhone, storeEmail: _sharedArgs.storeEmail, storeGstin: _sharedArgs.storeGstin, receiptFooter: _sharedArgs.receiptFooter, taxLabel: _sharedArgs.taxLabel, taxRate: _sharedArgs.taxRate, currencySymbol: _sharedArgs.currencySymbol, storeTerms: _sharedArgs.storeTerms, logoPath: _sharedArgs.logoPath, storeUpiId: _sharedArgs.storeUpiId, docType: docType);
      case 'Modern':
        return _buildModern4Pdf(tx, storeName: _sharedArgs.storeName, storeAddress: _sharedArgs.storeAddress, storePhone: _sharedArgs.storePhone, storeEmail: _sharedArgs.storeEmail, storeGstin: _sharedArgs.storeGstin, receiptFooter: _sharedArgs.receiptFooter, taxLabel: _sharedArgs.taxLabel, taxRate: _sharedArgs.taxRate, currencySymbol: _sharedArgs.currencySymbol, storeTerms: _sharedArgs.storeTerms, logoPath: _sharedArgs.logoPath, storeUpiId: _sharedArgs.storeUpiId);
      case 'GST':
        return _buildGstPdf(tx, storeName: _sharedArgs.storeName, storeAddress: _sharedArgs.storeAddress, storePhone: _sharedArgs.storePhone, storeEmail: _sharedArgs.storeEmail, storeGstin: _sharedArgs.storeGstin, receiptFooter: _sharedArgs.receiptFooter, taxLabel: _sharedArgs.taxLabel, taxRate: _sharedArgs.taxRate, currencySymbol: _sharedArgs.currencySymbol, storeTerms: _sharedArgs.storeTerms, logoPath: _sharedArgs.logoPath, docType: docType);
      case 'Landscape':
        return _buildLandscapePdf(tx, storeName: _sharedArgs.storeName, storeAddress: _sharedArgs.storeAddress, storePhone: _sharedArgs.storePhone, storeEmail: _sharedArgs.storeEmail, storeGstin: _sharedArgs.storeGstin, receiptFooter: _sharedArgs.receiptFooter, taxLabel: _sharedArgs.taxLabel, taxRate: _sharedArgs.taxRate, currencySymbol: _sharedArgs.currencySymbol, storeTerms: _sharedArgs.storeTerms, logoPath: _sharedArgs.logoPath);
      case 'Simple':
        return _buildSimplePdf(tx, storeName: _sharedArgs.storeName, storeAddress: _sharedArgs.storeAddress, storePhone: _sharedArgs.storePhone, storeEmail: _sharedArgs.storeEmail, storeGstin: _sharedArgs.storeGstin, receiptFooter: _sharedArgs.receiptFooter, taxLabel: _sharedArgs.taxLabel, taxRate: _sharedArgs.taxRate, currencySymbol: _sharedArgs.currencySymbol, storeTerms: _sharedArgs.storeTerms, logoPath: _sharedArgs.logoPath, docType: docType);
      case 'Theme 5':
        return _buildDetailedPdf(tx, storeName: _sharedArgs.storeName, storeAddress: _sharedArgs.storeAddress, storePhone: _sharedArgs.storePhone, storeGstin: _sharedArgs.storeGstin, receiptFooter: _sharedArgs.receiptFooter, taxLabel: _sharedArgs.taxLabel, taxRate: _sharedArgs.taxRate, currencySymbol: _sharedArgs.currencySymbol, paperSize: paperSize);
    }

    final doc = pw.Document();
    final _isThermalLayout = layout.startsWith('Theme');
    final isNarrow = paperSize.contains('inch') || _isThermalLayout;
    final isLandscape = (layout == 'Landscape' || orientation == 'Landscape') && !isNarrow;
    final isGst = layout == 'Theme 4';
    final isCompact = layout == 'Simple' || layout == 'Theme 2';
    final isBold = layout == 'Theme 3';
    final isMinimal = false;
    final isElegant = false;
    final isReceiptStyle = false;

    var pageFormat = _pageFormat(paperSize, tx.items.length);
    if (isLandscape) {
      pageFormat = pageFormat.landscape;
    }

    await preWarm();
    final regular = _regular!;
    final bold    = _bold!;

    final double fs = isCompact ? 7.5 : (isNarrow ? 8.5 : paperSize == 'A5' ? 9.0 : 10.0);
    final double titleFs = isNarrow ? 13.0 : paperSize == 'A5' ? 15.0 : 18.0;
    final pw.Widget sep = isMinimal
        ? pw.SizedBox(height: 6)
        : pw.Divider(color: PdfColors.grey400, thickness: isElegant ? 1.0 : 0.5);

    // Receipt Style: narrow content centered on A4
    if (isReceiptStyle) {
      pageFormat = PdfPageFormat.a4;
    }

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: isNarrow
            ? const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12)
            : const pw.EdgeInsets.all(28),
        build: (_) {
          // Receipt Style wraps content in a centered narrow container
          pw.Widget buildContent() => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Store header ──────────────────────────────────────────────
            if (isElegant) ...[
              pw.Divider(color: PdfColors.grey600, thickness: 1),
              pw.SizedBox(height: 2),
            ],
            pw.Center(child: pw.Text(storeName,
                style: pw.TextStyle(font: bold, fontSize: titleFs),
                textAlign: pw.TextAlign.center)),
            if (storeAddress.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Center(child: pw.Text(storeAddress,
                  style: pw.TextStyle(font: regular, fontSize: fs - 1, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center)),
            ],
            if (storePhone.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text('Tel: $storePhone',
                  style: pw.TextStyle(font: regular, fontSize: fs - 1, color: PdfColors.grey600))),
            ],
            if (storeEmail.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text(storeEmail,
                  style: pw.TextStyle(font: regular, fontSize: fs - 1, color: PdfColors.grey600))),
            ],
            if (isGst && storeGstin.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text('GSTIN: $storeGstin',
                  style: pw.TextStyle(font: regular, fontSize: fs - 1, color: PdfColors.grey700))),
            ],
            pw.SizedBox(height: 6),
            sep,
            pw.SizedBox(height: 5),

            // ── Bill metadata ─────────────────────────────────────────────
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Bill #${tx.id.substring(0, 6).toUpperCase()}',
                  style: pw.TextStyle(font: regular, fontSize: fs - 1, color: PdfColors.grey600)),
              pw.Text(_fmt(tx.createdAt),
                  style: pw.TextStyle(font: regular, fontSize: fs - 1, color: PdfColors.grey600)),
            ]),
            if (tx.customerName != null && tx.customerName!.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'Customer: ${tx.customerName}${tx.customerPhone != null && tx.customerPhone!.isNotEmpty ? "  |  ${tx.customerPhone}" : ""}',
                style: pw.TextStyle(font: regular, fontSize: fs - 1, color: PdfColors.grey600),
              ),
            ],
            pw.SizedBox(height: 6),
            sep,
            pw.SizedBox(height: 5),

            // ── Column headers ────────────────────────────────────────────
            pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Text('ITEM',
                  style: pw.TextStyle(font: bold, fontSize: fs - 1.5, color: PdfColors.grey500))),
              pw.Container(width: 28, child: pw.Text('QTY',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: bold, fontSize: fs - 1.5, color: PdfColors.grey500))),
              pw.Expanded(flex: 2, child: pw.Text('UNIT',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: bold, fontSize: fs - 1.5, color: PdfColors.grey500))),
              pw.Expanded(flex: 2, child: pw.Text('TOTAL',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: bold, fontSize: fs - 1.5, color: PdfColors.grey500))),
            ]),
            pw.SizedBox(height: 4),

            // ── Line items ────────────────────────────────────────────────
            ...tx.items.map((item) => pw.Padding(
                  padding: pw.EdgeInsets.symmetric(vertical: isCompact ? 1.5 : 2.5),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 5, child: pw.Text(_itemLabel(item),
                        style: pw.TextStyle(font: regular, fontSize: fs))),
                    pw.Container(width: 28, child: pw.Text('x${item.quantity}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: regular, fontSize: fs))),
                    pw.Expanded(flex: 2, child: pw.Text(
                        '$currencySymbol${item.price.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: regular, fontSize: fs))),
                    pw.Expanded(flex: 2, child: pw.Text(
                        '$currencySymbol${item.total.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: bold, fontSize: fs))),
                  ]),
                )),

            pw.SizedBox(height: 6),
            sep,
            pw.SizedBox(height: 5),

            // ── Totals ────────────────────────────────────────────────────
            _totalRow('Subtotal', '$currencySymbol${tx.subtotal.toStringAsFixed(2)}', regular, fs),
            if (tx.discountAmount > 0)
              _totalRow('Discount', '-$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', regular, fs,
                  valueColor: PdfColors.green800),
            if (tx.taxAmount > 0) _totalRow('$taxLabel ($taxRate%)', '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', regular, fs),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL', style: pw.TextStyle(font: bold, fontSize: fs + 3)),
              pw.Text('$currencySymbol${tx.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: bold, fontSize: fs + 3)),
            ]),
            pw.SizedBox(height: 4),
            _totalRow('Payment', tx.paymentMethod.toUpperCase(), regular, fs),

            // ── GST tax summary table (GST Invoice layout) ────────────────
            if (isGst && tx.taxAmount > 0) ...[
              pw.SizedBox(height: 8),
              sep,
              pw.SizedBox(height: 4),
              pw.Text('Tax Summary',
                  style: pw.TextStyle(font: bold, fontSize: fs - 0.5, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: ['HSN/SAC', 'Taxable', 'CGST', 'SGST', 'Total Tax'],
                data: [
                  [
                    '—',
                    '$currencySymbol${tx.subtotal.toStringAsFixed(2)}',
                    '$currencySymbol${(tx.taxAmount / 2).toStringAsFixed(2)}',
                    '$currencySymbol${(tx.taxAmount / 2).toStringAsFixed(2)}',
                    '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}',
                  ]
                ],
                headerStyle: pw.TextStyle(font: bold, fontSize: fs - 1.5, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
                cellStyle: pw.TextStyle(font: regular, fontSize: fs - 1.5),
                cellHeight: 16,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              ),
            ],

            // ── Bold: extra-large total ───────────────────────────────────
            if (isBold) ...[
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 2, color: PdfColors.black),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL', style: pw.TextStyle(font: bold, fontSize: fs + 8)),
                pw.Text('$currencySymbol${tx.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: bold, fontSize: fs + 8)),
              ]),
              pw.Divider(thickness: 2, color: PdfColors.black),
            ],

            pw.SizedBox(height: 12),
            sep,
            pw.SizedBox(height: 8),

            // ── Footer ────────────────────────────────────────────────────
            if (isElegant) pw.Divider(color: PdfColors.grey600, thickness: 1),
            pw.Center(child: pw.Text(receiptFooter,
                style: pw.TextStyle(font: regular, fontSize: fs - 0.5, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center)),
          ]);

          if (isReceiptStyle) {
            return pw.Center(
              child: pw.SizedBox(
                width: 240,
                child: buildContent(),
              ),
            );
          }
          return buildContent();
        },
      ),
    );

    return doc.save();
  }

  // ── Modern (dark header band) ────────────────────────────────────────────
  static Future<Uint8List> _buildModernPdf(TransactionRecord tx, {
    required String storeName, required String storeAddress,
    String storePhone = '', String storeEmail = '', String storeGstin = '',
    required String receiptFooter, required String taxLabel,
    required String taxRate, required String currencySymbol, required String paperSize,
    String docType = 'Invoice',
  }) async {
    await preWarm();
    final r = _regular!; final b = _bold!;
    const fs = 9.5;
    final fmt = _pageFormat(paperSize, tx.items.length);
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: fmt == PdfPageFormat.a4 ? fmt : PdfPageFormat.a4, margin: const pw.EdgeInsets.all(0), build: (_) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        // Dark header band
        pw.Container(
          color: const PdfColor.fromInt(0xFF2D2D2D),
          padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(storeName.isNotEmpty ? storeName : 'Company', style: pw.TextStyle(font: b, fontSize: 20, color: PdfColors.white)),
              if (storeAddress.isNotEmpty) pw.Text(storeAddress, style: pw.TextStyle(font: r, fontSize: fs - 1.5, color: PdfColors.grey300)),
              if (storePhone.isNotEmpty) pw.Text('Tel: $storePhone', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey300)),
              if (storeGstin.isNotEmpty) pw.Text('GSTIN: $storeGstin', style: pw.TextStyle(font: b, fontSize: fs - 1, color: PdfColors.grey100)),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(docType.toUpperCase(), style: pw.TextStyle(font: b, fontSize: 16, color: PdfColors.grey300, letterSpacing: 2)),
              pw.SizedBox(height: 4),
              pw.Text('#${tx.id.substring(0, 6).toUpperCase()}', style: pw.TextStyle(font: b, fontSize: fs, color: PdfColors.white)),
              pw.Text(_fmt(tx.createdAt), style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey300)),
              if (tx.customerName?.isNotEmpty == true) pw.Text(tx.customerName!, style: pw.TextStyle(font: b, fontSize: fs - 0.5, color: PdfColors.white)),
            ]),
          ]),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            // Items
            pw.TableHelper.fromTextArray(
              headers: ['ITEM', 'QTY', 'UNIT PRICE', 'TOTAL'],
              data: tx.items.map((i) => [_itemLabel(i), '${i.quantity}', '$currencySymbol${i.price.toStringAsFixed(2)}', '$currencySymbol${i.total.toStringAsFixed(2)}']).toList(),
              headerStyle: pw.TextStyle(font: b, fontSize: fs - 1.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
              cellStyle: pw.TextStyle(font: r, fontSize: fs - 0.5),
              cellHeight: 20,
              cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
            pw.SizedBox(height: 16),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.SizedBox(width: 200, child: pw.Column(children: [
                _totalRow('Subtotal', '$currencySymbol${tx.subtotal.toStringAsFixed(2)}', r, fs),
                if (tx.discountAmount > 0) _totalRow('Discount', '-$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', r, fs, valueColor: PdfColors.green800),
                if (tx.taxAmount > 0) _totalRow('$taxLabel ($taxRate%)', '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', r, fs),
                pw.Divider(thickness: 1.5, color: const PdfColor.fromInt(0xFF2D2D2D)),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL', style: pw.TextStyle(font: b, fontSize: fs + 4, color: const PdfColor.fromInt(0xFF2D2D2D))),
                  pw.Text('$currencySymbol${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(font: b, fontSize: fs + 4, color: const PdfColor.fromInt(0xFF2D2D2D))),
                ]),
                pw.SizedBox(height: 2),
                _totalRow('Payment', tx.paymentMethod.toUpperCase(), r, fs),
              ])),
            ]),
            if (receiptFooter.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.Center(child: pw.Text(receiptFooter, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600))),
            ],
          ]),
        ),
      ]);
    }));
    return doc.save();
  }

  // ── Professional (two-col header, full borders) ───────────────────────────
  static Future<Uint8List> _buildProfessionalPdf(TransactionRecord tx, {
    required String storeName, required String storeAddress,
    String storePhone = '', String storeEmail = '', String storeGstin = '',
    required String receiptFooter, required String taxLabel,
    required String taxRate, required String currencySymbol, required String paperSize,
    String docType = 'Invoice',
  }) async {
    await preWarm();
    final r = _regular!; final b = _bold!;
    const fs = 9.0;
    const grey4 = pw.BorderSide(color: PdfColors.grey400, width: 0.5);
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (_) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text(docType.toUpperCase(), style: pw.TextStyle(font: b, fontSize: 18, letterSpacing: 3))),
        pw.SizedBox(height: 12),
        pw.Table(border: const pw.TableBorder(bottom: grey4, verticalInside: grey4),
          columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
          children: [pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(storeName.isNotEmpty ? storeName : 'Company', style: pw.TextStyle(font: b, fontSize: 13)),
              if (storeAddress.isNotEmpty) ...[pw.SizedBox(height: 2), pw.Text(storeAddress, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700))],
              if (storePhone.isNotEmpty) ...[pw.SizedBox(height: 2), pw.Text('Phone: $storePhone', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700))],
              if (storeEmail.isNotEmpty) ...[pw.SizedBox(height: 2), pw.Text(storeEmail, style: pw.TextStyle(font: r, fontSize: fs - 1.5, color: PdfColors.grey700))],
              if (storeGstin.isNotEmpty) ...[pw.SizedBox(height: 2), pw.Text('GSTIN: $storeGstin', style: pw.TextStyle(font: b, fontSize: fs - 1))],
            ])),
            pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _tiTotalRow('Invoice No.', tx.id.substring(0, 6).toUpperCase(), r, fs - 1),
              _tiTotalRow('Date', _fmtDate(tx.createdAt), r, fs - 1),
              _tiTotalRow('Time', _fmtTime(tx.createdAt), r, fs - 1),
              if (tx.customerName?.isNotEmpty == true) _tiTotalRow('Bill To', tx.customerName!, b, fs - 1),
            ])),
          ])],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Item Name', 'Qty', 'Unit Price', 'Amount'],
          data: tx.items.asMap().entries.map((e) => ['${e.key+1}', _itemLabel(e.value), '${e.value.quantity}', '$currencySymbol${e.value.price.toStringAsFixed(2)}', '$currencySymbol${e.value.total.toStringAsFixed(2)}']).toList(),
          headerStyle: pw.TextStyle(font: b, fontSize: fs - 1.5, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
          cellStyle: pw.TextStyle(font: r, fontSize: fs - 0.5),
          cellHeight: 20,
          cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        ),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(
            width: 220,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(children: [
              _totalRow('Subtotal', '$currencySymbol${tx.subtotal.toStringAsFixed(2)}', r, fs),
              if (tx.discountAmount > 0) _totalRow('Discount', '-$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', r, fs, valueColor: PdfColors.green800),
              if (tx.taxAmount > 0) _totalRow('$taxLabel ($taxRate%)', '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', r, fs),
              pw.Divider(thickness: 0.5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL', style: pw.TextStyle(font: b, fontSize: fs + 3)),
                pw.Text('$currencySymbol${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(font: b, fontSize: fs + 3)),
              ]),
              _totalRow('Payment', tx.paymentMethod.toUpperCase(), r, fs),
            ]),
          ),
        ]),
        pw.SizedBox(height: 16),
        if (receiptFooter.isNotEmpty) pw.Center(child: pw.Text(receiptFooter, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600))),
      ]);
    }));
    return doc.save();
  }

  // ── Detailed (extra item columns: HSN, discount, tax per item) ────────────
  static Future<Uint8List> _buildDetailedPdf(TransactionRecord tx, {
    required String storeName, required String storeAddress,
    String storePhone = '', String storeGstin = '',
    required String receiptFooter, required String taxLabel,
    required String taxRate, required String currencySymbol, required String paperSize,
  }) async {
    await preWarm();
    final r = _regular!; final b = _bold!;
    final isNarrow = paperSize.contains('inch');
    final double fs = isNarrow ? 7.5 : 8.5;
    final fmt = _pageFormat(paperSize, tx.items.length);
    final taxRateVal = double.tryParse(taxRate) ?? 18.0;
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: isNarrow ? fmt : PdfPageFormat.a4, margin: isNarrow ? const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10) : const pw.EdgeInsets.all(24), build: (_) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text(storeName.isNotEmpty ? storeName : 'Company', style: pw.TextStyle(font: b, fontSize: isNarrow ? 13 : 16))),
        if (storeAddress.isNotEmpty) pw.Center(child: pw.Text(storeAddress, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600))),
        if (storeGstin.isNotEmpty) pw.Center(child: pw.Text('GSTIN: $storeGstin', style: pw.TextStyle(font: b, fontSize: fs - 1))),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Bill: ${tx.id.substring(0, 6).toUpperCase()}', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
          pw.Text(_fmt(tx.createdAt), style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
        ]),
        if (tx.customerName?.isNotEmpty == true) pw.Text('Customer: ${tx.customerName}', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: isNarrow ? ['Item', 'Qty', 'Rate', 'Tax', 'Amt'] : ['#', 'Item Name', 'HSN/SAC', 'Qty', 'Rate', 'Disc', 'Tax%', 'Amount'],
          data: isNarrow
              ? tx.items.map((i) => [_itemLabel(i), '${i.quantity}', '$currencySymbol${i.price.toStringAsFixed(2)}', '$currencySymbol${(i.price * i.quantity * taxRateVal / 100).toStringAsFixed(2)}', '$currencySymbol${i.total.toStringAsFixed(2)}']).toList()
              : tx.items.asMap().entries.map((e) => ['${e.key+1}', _itemLabel(e.value), '—', '${e.value.quantity}', '$currencySymbol${e.value.price.toStringAsFixed(2)}', '${currencySymbol}0.00', '$taxRate%', '$currencySymbol${e.value.total.toStringAsFixed(2)}']).toList(),
          headerStyle: pw.TextStyle(font: b, fontSize: fs - 2, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
          cellStyle: pw.TextStyle(font: r, fontSize: fs - 1.5),
          cellHeight: 18,
          cellAlignments: isNarrow
              ? {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight}
              : {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight, 6: pw.Alignment.center, 7: pw.Alignment.centerRight},
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        _totalRow('Subtotal', '$currencySymbol${tx.subtotal.toStringAsFixed(2)}', r, fs),
        if (tx.discountAmount > 0) _totalRow('Discount', '-$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', r, fs, valueColor: PdfColors.green800),
        if (tx.taxAmount > 0) _totalRow('$taxLabel ($taxRate%)', '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', r, fs),
        pw.Divider(thickness: 1, color: PdfColors.black),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL', style: pw.TextStyle(font: b, fontSize: fs + 3)),
          pw.Text('$currencySymbol${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(font: b, fontSize: fs + 3)),
        ]),
        _totalRow('Payment', tx.paymentMethod.toUpperCase(), r, fs),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Center(child: pw.Text(receiptFooter, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600), textAlign: pw.TextAlign.center)),
      ]);
    }));
    return doc.save();
  }

  // ── Two Column (items split in two columns) ───────────────────────────────
  static Future<Uint8List> _buildTwoColumnPdf(TransactionRecord tx, {
    required String storeName, required String storeAddress,
    String storePhone = '',
    required String receiptFooter, required String taxLabel,
    required String taxRate, required String currencySymbol, required String paperSize,
  }) async {
    await preWarm();
    final r = _regular!; final b = _bold!;
    const fs = 9.0;
    final doc = pw.Document();
    final half = (tx.items.length / 2).ceil();
    final leftItems = tx.items.sublist(0, half);
    final rightItems = tx.items.sublist(half);

    pw.Widget itemList(List<TransactionItem> items) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FixedColumnWidth(24), 2: pw.FlexColumnWidth(2)},
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey700), children: [
            for (final h in ['ITEM', 'QTY', 'AMT'])
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3), child: pw.Text(h, style: pw.TextStyle(font: b, fontSize: fs - 2, color: PdfColors.white))),
          ]),
          ...items.map((i) => pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3), child: pw.Text(_itemLabel(i), style: pw.TextStyle(font: r, fontSize: fs - 1.5))),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3), child: pw.Text('${i.quantity}', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: r, fontSize: fs - 1.5))),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3), child: pw.Text('$currencySymbol${i.total.toStringAsFixed(0)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: b, fontSize: fs - 1.5))),
          ])),
        ],
      ),
    ]);

    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (_) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text(storeName.isNotEmpty ? storeName : 'Company', style: pw.TextStyle(font: b, fontSize: 18))),
        if (storeAddress.isNotEmpty) pw.Center(child: pw.Text(storeAddress, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600))),
        if (storePhone.isNotEmpty) pw.Center(child: pw.Text('Tel: $storePhone', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600))),
        pw.SizedBox(height: 6), pw.Divider(color: PdfColors.grey400, thickness: 0.5), pw.SizedBox(height: 5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Bill #${tx.id.substring(0, 6).toUpperCase()}', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
          pw.Text(_fmt(tx.createdAt), style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
        ]),
        if (tx.customerName?.isNotEmpty == true) pw.Text('Customer: ${tx.customerName}', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
        pw.SizedBox(height: 8),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: itemList(leftItems)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: rightItems.isNotEmpty ? itemList(rightItems) : pw.SizedBox()),
        ]),
        pw.SizedBox(height: 12), pw.Divider(color: PdfColors.grey400, thickness: 0.5), pw.SizedBox(height: 6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.SizedBox(width: 200, child: pw.Column(children: [
            _totalRow('Subtotal', '$currencySymbol${tx.subtotal.toStringAsFixed(2)}', r, fs),
            if (tx.discountAmount > 0) _totalRow('Discount', '-$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', r, fs, valueColor: PdfColors.green800),
            if (tx.taxAmount > 0) _totalRow('$taxLabel ($taxRate%)', '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', r, fs),
            pw.Divider(thickness: 1, color: PdfColors.black),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL', style: pw.TextStyle(font: b, fontSize: fs + 3)),
              pw.Text('$currencySymbol${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(font: b, fontSize: fs + 3)),
            ]),
            _totalRow('Payment', tx.paymentMethod.toUpperCase(), r, fs),
          ])),
        ]),
        if (receiptFooter.isNotEmpty) ...[pw.SizedBox(height: 12), pw.Center(child: pw.Text(receiptFooter, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)))],
      ]);
    }));
    return doc.save();
  }

  // ── Summary (stats box first, then full items) ────────────────────────────
  static Future<Uint8List> _buildSummaryPdf(TransactionRecord tx, {
    required String storeName, required String storeAddress,
    String storePhone = '',
    required String receiptFooter, required String taxLabel,
    required String taxRate, required String currencySymbol, required String paperSize,
  }) async {
    await preWarm();
    final r = _regular!; final b = _bold!;
    const fs = 9.0;
    final totalQty = tx.items.fold<int>(0, (s, i) => s + i.quantity);
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (_) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text(storeName.isNotEmpty ? storeName : 'Company', style: pw.TextStyle(font: b, fontSize: 18))),
        if (storeAddress.isNotEmpty) pw.Center(child: pw.Text(storeAddress, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600))),
        pw.SizedBox(height: 4),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Bill #${tx.id.substring(0, 6).toUpperCase()}', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
          pw.Text(_fmt(tx.createdAt), style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
        ]),
        pw.SizedBox(height: 12),
        // Summary stats boxes
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
              for (final item in [('Items', '${tx.items.length}'), ('Total Qty', '$totalQty'), ('Subtotal', '$currencySymbol${tx.subtotal.toStringAsFixed(2)}'), if (tx.taxAmount > 0) ('Tax', '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}'), ('Total', '$currencySymbol${tx.total.toStringAsFixed(2)}')])
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: pw.Column(children: [
                  pw.Text(item.$1, style: pw.TextStyle(font: r, fontSize: fs - 2, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                  pw.Text(item.$2, style: pw.TextStyle(font: b, fontSize: fs + 1)),
                ])),
            ]),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Item Name', 'Qty', 'Unit Price', 'Amount'],
          data: tx.items.asMap().entries.map((e) => ['${e.key+1}', _itemLabel(e.value), '${e.value.quantity}', '$currencySymbol${e.value.price.toStringAsFixed(2)}', '$currencySymbol${e.value.total.toStringAsFixed(2)}']).toList(),
          headerStyle: pw.TextStyle(font: b, fontSize: fs - 1.5, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
          cellStyle: pw.TextStyle(font: r, fontSize: fs - 0.5),
          cellHeight: 18,
          cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        ),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Payment: ${tx.paymentMethod.toUpperCase()}', style: pw.TextStyle(font: b, fontSize: fs)),
            if (tx.customerName?.isNotEmpty == true) pw.Text('Customer: ${tx.customerName}', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
          ]),
          pw.Container(
            decoration: pw.BoxDecoration(color: PdfColors.grey800, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: pw.Row(children: [
              pw.Text('TOTAL  ', style: pw.TextStyle(font: b, fontSize: fs + 4, color: PdfColors.white)),
              pw.Text('$currencySymbol${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(font: b, fontSize: fs + 4, color: PdfColors.white)),
            ]),
          ),
        ]),
        if (receiptFooter.isNotEmpty) ...[pw.SizedBox(height: 12), pw.Divider(color: PdfColors.grey400, thickness: 0.5), pw.Center(child: pw.Text(receiptFooter, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)))],
      ]);
    }));
    return doc.save();
  }

  // ── Official (government/formal style, two signature blocks) ─────────────
  static Future<Uint8List> _buildOfficialPdf(TransactionRecord tx, {
    required String storeName, required String storeAddress,
    String storePhone = '', String storeGstin = '',
    required String receiptFooter, required String taxLabel,
    required String taxRate, required String currencySymbol,
    String storeTerms = '', required String paperSize,
    String docType = 'Invoice',
  }) async {
    await preWarm();
    final r = _regular!; final b = _bold!;
    const fs = 9.0;
    const grey4 = pw.BorderSide(color: PdfColors.grey400, width: 0.5);
    final invoiceNo = 'INV-${tx.id.substring(0, 6).toUpperCase()}';
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (_) {
      return pw.Container(
        decoration: const pw.BoxDecoration(border: pw.Border(top: grey4, bottom: grey4, left: grey4, right: grey4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(storeName.isNotEmpty ? storeName : 'Company', style: pw.TextStyle(font: b, fontSize: 14)),
                if (storeAddress.isNotEmpty) pw.Text(storeAddress, style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                if (storePhone.isNotEmpty) pw.Text('Phone: $storePhone', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                if (storeGstin.isNotEmpty) pw.Text('GSTIN: $storeGstin', style: pw.TextStyle(font: b, fontSize: fs - 1)),
              ])),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(docType == 'Quotation' ? 'QUOTATION' : 'TAX INVOICE', style: pw.TextStyle(font: b, fontSize: 14, letterSpacing: 1)),
                pw.SizedBox(height: 4),
                pw.Text('No.: $invoiceNo', style: pw.TextStyle(font: r, fontSize: fs - 1)),
                pw.Text('Date: ${_fmtDate(tx.createdAt)}', style: pw.TextStyle(font: r, fontSize: fs - 1)),
                pw.Text('ORIGINAL FOR RECIPIENT', style: pw.TextStyle(font: r, fontSize: fs - 2, color: PdfColors.grey600)),
              ]),
            ]),
          ),
          if (tx.customerName?.isNotEmpty == true)
            pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: pw.Row(children: [
                pw.Text('Consignee/Buyer: ', style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
                pw.Text('${tx.customerName}${tx.customerPhone?.isNotEmpty == true ? "  |  ${tx.customerPhone}" : ""}', style: pw.TextStyle(font: r, fontSize: fs - 0.5)),
              ]),
            ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(0),
            child: pw.TableHelper.fromTextArray(
              headers: ['Sl.', 'Description of Goods', 'HSN/SAC', 'Qty', 'Rate', 'Disc.', 'Amount'],
              data: tx.items.asMap().entries.map((e) => ['${e.key+1}', _itemLabel(e.value), '—', '${e.value.quantity}', '$currencySymbol${e.value.price.toStringAsFixed(2)}', '—', '$currencySymbol${e.value.total.toStringAsFixed(2)}']).toList(),
              headerStyle: pw.TextStyle(font: b, fontSize: fs - 1.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
              cellStyle: pw.TextStyle(font: r, fontSize: fs - 0.5),
              cellHeight: 18,
              cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.centerRight, 5: pw.Alignment.center, 6: pw.Alignment.centerRight},
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(top: grey4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.SizedBox(width: 220, child: pw.Column(children: [
                _totalRow('Taxable Value', '$currencySymbol${tx.subtotal.toStringAsFixed(2)}', r, fs - 0.5),
                if (tx.discountAmount > 0) _totalRow('Discount', '-$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', r, fs - 0.5, valueColor: PdfColors.green800),
                if (tx.taxAmount > 0) _totalRow('$taxLabel ($taxRate%)', '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', r, fs - 0.5),
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Grand Total', style: pw.TextStyle(font: b, fontSize: fs + 2)),
                  pw.Text('$currencySymbol${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(font: b, fontSize: fs + 2)),
                ]),
              ])),
            ]),
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(top: grey4, bottom: grey4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: pw.Text('Amount in Words: ${_numberToWords(tx.total)}', style: pw.TextStyle(font: b, fontSize: fs - 1)),
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: pw.Row(children: [
              pw.Text('Payment Mode: ', style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
              pw.Text(tx.paymentMethod.toUpperCase(), style: pw.TextStyle(font: r, fontSize: fs - 0.5)),
              if (receiptFooter.isNotEmpty) ...[
                pw.Text('    E. & O. E.    ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey600)),
                pw.Expanded(child: pw.Text(receiptFooter, style: pw.TextStyle(font: r, fontSize: fs - 1.5, color: PdfColors.grey600))),
              ],
            ]),
          ),
          // Signature blocks
          pw.Table(
            border: const pw.TableBorder(verticalInside: grey4),
            children: [pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("Receiver's Seal & Signature:", style: pw.TextStyle(font: b, fontSize: fs - 1, color: PdfColors.grey700)),
                pw.SizedBox(height: 28),
                pw.Text('Name & Signature', style: pw.TextStyle(font: r, fontSize: fs - 2, color: PdfColors.grey500)),
              ])),
              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('For: ${storeName.isNotEmpty ? storeName : "Company"}', style: pw.TextStyle(font: b, fontSize: fs - 1, color: PdfColors.grey700)),
                pw.SizedBox(height: 28),
                pw.Center(child: pw.Text('Authorised Signatory', style: pw.TextStyle(font: r, fontSize: fs - 2, color: PdfColors.grey500))),
              ])),
            ])],
          ),
        ]),
      );
    }));
    return doc.save();
  }

  // ── Classic Invoice (Vyapar Classic / Tally Theme layout) ────────────────
  static Future<Uint8List> _buildClassicInvoicePdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    String storeTerms = '',
    String logoPath = '',
    String storeUpiId = '',
    String docType = 'Invoice',
  }) async {
    await preWarm();
    final r = _serifRegular!;
    final b = _serifBold!;
    pw.ImageProvider? logoImage;
    if (logoPath.isNotEmpty) {
      try {
        final bytes = await File(logoPath).readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      } catch (_) {}
    }
    const fs = 8.5;
    final totalQty   = tx.items.fold<int>(0, (s, i) => s + i.quantity);
    final invoiceNo  = tx.invoiceNumber != null ? '${tx.invoiceNumber}' : tx.id.substring(0, 6).toUpperCase();

    const grey4 = pw.BorderSide(color: PdfColors.grey400, width: 0.5);
    const grey6 = pw.BorderSide(color: PdfColors.grey600, width: 0.8);

    pw.Widget tx_(String v, {pw.Font? f, double? s, PdfColor? c,
        pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Text(v, textAlign: a,
            style: pw.TextStyle(font: f ?? r, fontSize: s ?? fs, color: c));

    pw.Widget pd(pw.Widget w, [pw.EdgeInsets? e]) =>
        pw.Padding(
            padding: e ?? const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: w);

    // "Label: Value" detail row used in Invoice Details and totals
    pw.Widget detRow(String lbl, String val) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(children: [
        tx_(lbl, s: fs - 1, c: PdfColors.grey700),
        tx_(': ', s: fs - 1, c: PdfColors.grey700),
        pw.Expanded(child: tx_(val, s: fs - 1)),
      ]),
    );

    // Totals right-panel row
    pw.Widget totRow(String lbl, String val, {bool bold = false,
        double? fs2, PdfColor? vc}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        tx_(lbl, f: bold ? b : r, s: fs2 ?? (fs - 0.5), c: bold ? null : PdfColors.grey700),
        pw.Row(children: [
          tx_(':', f: bold ? b : r, s: fs2 ?? (fs - 0.5), c: bold ? null : PdfColors.grey700),
          pw.SizedBox(width: 6),
          tx_(val, f: bold ? b : r, s: fs2 ?? (fs - 0.5), c: vc),
        ]),
      ]),
    );

    // Items table rows
    final itemRows = tx.items.asMap().entries.map((e) {
      final disc = e.value.price * e.value.quantity * (0.0 / 100);
      final hasDesc = e.value.description.trim().isNotEmpty;
      return pw.TableRow(children: [
        pd(tx_('${e.key + 1}', a: pw.TextAlign.center, s: fs - 1)),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            tx_(e.value.productName, f: b, s: fs - 1),
            if (hasDesc) ...[
              pw.SizedBox(height: 1),
              tx_(e.value.description.trim(), s: fs - 2.5, c: PdfColors.grey500),
            ],
          ]),
        ),
        pd(tx_('—', a: pw.TextAlign.center, s: fs - 1)),
        pd(tx_('${e.value.quantity}', a: pw.TextAlign.center, s: fs - 1)),
        pd(tx_('-', a: pw.TextAlign.center, s: fs - 1)),
        pd(tx_('₹ ${e.value.price.toStringAsFixed(2)}', a: pw.TextAlign.right, s: fs - 1)),
        pd(tx_('₹ ${disc.toStringAsFixed(2)}', a: pw.TextAlign.right, s: fs - 1)),
        pd(tx_('₹ ${e.value.total.toStringAsFixed(2)}', f: b, a: pw.TextAlign.right, s: fs - 1)),
      ]);
    }).toList();

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(top: grey6, bottom: grey6, left: grey6, right: grey6),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

          // ── Title ──────────────────────────────────────────────────────
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Center(child: tx_('Tax Invoice', f: b, s: fs + 1)),
          ),

          // ── Company info — full width (logo left, store info right) ──
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              // Logo
              pw.Container(
                width: 60, height: 60,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
                child: logoImage != null
                    ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                    : pw.Center(child: tx_('Image', s: 7, c: PdfColors.grey500)),
              ),
              pw.SizedBox(width: 10),
              // Store info
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                tx_(storeName.isNotEmpty ? storeName : 'Company', f: b, s: 22),
                pw.SizedBox(height: 2),
                if (storeAddress.isNotEmpty) ...[
                  tx_(storeAddress, s: fs - 1, c: PdfColors.grey700),
                  pw.SizedBox(height: 3),
                ],
                // Phone left | Email right
                if (storePhone.isNotEmpty || storeEmail.isNotEmpty) ...[
                  pw.Row(children: [
                    if (storePhone.isNotEmpty) pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Phone: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                      pw.TextSpan(text: storePhone, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                    ])),
                    pw.Spacer(),
                    if (storeEmail.isNotEmpty) pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Email: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                      pw.TextSpan(text: storeEmail, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                    ])),
                  ]),
                  pw.SizedBox(height: 2),
                ],
                // GSTIN left | State right (if GSTIN has state prefix)
                if (storeGstin.isNotEmpty) pw.Row(children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'GSTIN: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                    pw.TextSpan(text: storeGstin, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                  ])),
                  pw.Spacer(),
                ]),
              ])),
            ]),
          ),

          // ── Bill To (left) | Invoice Details (right) ──────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: grey4, verticalInside: grey4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('Bill To:', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 4),
                  tx_(tx.customerName?.isNotEmpty == true ? tx.customerName! : 'Walk-In Customer', f: b, s: fs + 1),
                  if (tx.customerPhone != null && tx.customerPhone!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    tx_('Contact No: ${tx.customerPhone}', s: fs - 1, c: PdfColors.grey700),
                  ],
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('Invoice Details:', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 4),
                  detRow('No', invoiceNo),
                  detRow('Date', _fmtDate(tx.createdAt)),
                  detRow('Time', _fmtTime(tx.createdAt)),
                ]),
              ),
            ])],
          ),

          // ── Items table ────────────────────────────────────────────────
          pw.Table(
            border: const pw.TableBorder(
              bottom: grey4, horizontalInside: grey4, verticalInside: grey4,
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(14),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FixedColumnWidth(42),
              3: pw.FixedColumnWidth(48),
              4: pw.FixedColumnWidth(20),
              5: pw.FixedColumnWidth(60),
              6: pw.FixedColumnWidth(60),
              7: pw.FixedColumnWidth(58),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  for (final h in [
                    ('#', pw.TextAlign.center), ('Item name', pw.TextAlign.left),
                    ('HSN/SAC', pw.TextAlign.center), ('Quantity', pw.TextAlign.center),
                    ('Unit', pw.TextAlign.center),
                    ('Price/Unit(₹)', pw.TextAlign.right), ('Discount(₹)', pw.TextAlign.right),
                    ('Amount(₹)', pw.TextAlign.right),
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: tx_(h.$1, f: b, s: fs - 2, a: h.$2),
                    ),
                ],
              ),
              ...itemRows,
              // TOTAL row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.SizedBox(),
                  pd(tx_('Total', f: b, s: fs - 1)),
                  pw.SizedBox(),
                  pd(tx_('$totalQty', f: b, a: pw.TextAlign.center, s: fs - 1)),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  pd(tx_('₹ ${tx.discountAmount.toStringAsFixed(2)}',
                      f: b, a: pw.TextAlign.right, s: fs - 1)),
                  pd(tx_('₹ ${tx.total.toStringAsFixed(2)}',
                      f: b, a: pw.TextAlign.right, s: fs - 1)),
                ],
              ),
            ],
          ),

          // ── Payment Mode (left) | Totals (right) ──────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: grey4, verticalInside: grey4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              // Left: Payment Mode + optional UPI QR
              pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(top: grey4)),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Payment Mode: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                    pw.TextSpan(text: tx.paymentMethod.toUpperCase(), style: pw.TextStyle(font: b, fontSize: fs - 1)),
                  ])),
                  if (storeUpiId.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'upi://pay?pa=${Uri.encodeComponent(storeUpiId)}&pn=${Uri.encodeComponent(storeName)}&cu=INR',
                      width: 60, height: 60, drawText: false,
                    ),
                    pw.SizedBox(height: 3),
                    tx_(storeUpiId, s: fs - 2, c: PdfColors.grey600),
                  ],
                ]),
              ),
              // Right: Totals breakdown
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                  totRow('Sub Total', '$currencySymbol ${tx.subtotal.toStringAsFixed(2)}'),
                  if (tx.discountAmount > 0)
                    totRow('Discount', '$currencySymbol ${tx.discountAmount.toStringAsFixed(2)}', vc: PdfColors.green800),
                  if (tx.taxAmount > 0) totRow('Tax ($taxRate%)', '$currencySymbol ${tx.taxAmount.toStringAsFixed(2)}'),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  totRow('Total', '$currencySymbol ${tx.total.toStringAsFixed(2)}',
                      bold: true, fs2: fs + 0.5),
                  pw.SizedBox(height: 5),
                  tx_('Invoice Amount In Words :', f: b, s: fs - 2, c: PdfColors.grey600),
                  pw.SizedBox(height: 2),
                  tx_(_numberToWords(tx.total), s: fs - 2.5, c: PdfColors.grey600),
                  pw.SizedBox(height: 4),
                  totRow('Received', '$currencySymbol ${tx.total.toStringAsFixed(2)}'),
                  totRow('Balance', '$currencySymbol 0.00'),
                  if (tx.discountAmount > 0)
                    totRow('You Saved', '$currencySymbol ${tx.discountAmount.toStringAsFixed(2)}',
                        bold: true, vc: PdfColors.green800),
                ]),
              ),
            ])],
          ),

          // ── Footer: Description+Bank+CustomerSig (left) | Terms+Signatory (right) ──
          pw.Table(
            border: const pw.TableBorder(verticalInside: grey4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: grey4)),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: tx_('Description:', f: b, s: fs - 0.5),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: tx_(receiptFooter.isNotEmpty ? receiptFooter : 'Sale Description',
                      s: fs - 1.5, c: PdfColors.grey600),
                ),
                // Customer Signature
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: grey4)),
                  padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 0),
                  child: tx_('Customer Signature:', f: b, s: fs - 0.5),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(8, 36, 8, 10),
                  child: pw.Container(height: 0.5, color: PdfColors.grey400),
                ),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: grey4)),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: tx_('Terms & Conditions:', f: b, s: fs - 0.5),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: tx_(storeTerms.isNotEmpty ? storeTerms : 'Thanks for doing business with us!',
                      s: fs - 1.5, c: PdfColors.grey600),
                ),
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: grey4)),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: tx_('For: ${storeName.isNotEmpty ? storeName : "Company"}', f: b, s: fs - 0.5),
                ),
                // Authorized Signatory — blank space, no image box
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(8, 32, 8, 6),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.Container(height: 0.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 3),
                    tx_('Authorized Signatory', s: fs - 1.5, c: PdfColors.grey600,
                        a: pw.TextAlign.center),
                  ]),
                ),
              ]),
            ])],
          ),

        ]),
      ),
    ));
    return doc.save();
  }

  // ── Tax Invoice (A4, Vyapar-style layout) ────────────────────────────────
  static Future<Uint8List> _buildTaxInvoicePdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    String storeTerms = '',
  }) async {
    await preWarm();
    final regular = _regular!;
    final bold    = _bold!;

    const double fs = 8.5;
    const double headerFs = 13.0;

    final cgst = tx.taxAmount / 2;
    final sgst = tx.taxAmount / 2;
    final halfRate = (double.tryParse(taxRate) ?? 18.0) / 2;
    final totalQty = tx.items.fold<int>(0, (s, i) => s + i.quantity);
    final invoiceNo = 'INV-${tx.id.substring(0, 6).toUpperCase()}';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) {
          // ── Local helpers ──────────────────────────────────────────────
          const grey4 = pw.BorderSide(color: PdfColors.grey400, width: 0.5);
          const grey5 = pw.BorderSide(color: PdfColors.grey500, width: 0.8);

          pw.Widget t(String v, {pw.Font? f, double? s, PdfColor? c, pw.TextAlign a = pw.TextAlign.left}) =>
              pw.Text(v, textAlign: a, style: pw.TextStyle(font: f ?? regular, fontSize: s ?? fs, color: c));

          pw.Widget pad(pw.Widget w, [pw.EdgeInsets? e]) =>
              pw.Padding(padding: e ?? const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4), child: w);

          pw.Widget taxCell(String v, {pw.Font? f, pw.TextAlign a = pw.TextAlign.right}) =>
              pad(t(v, f: f, s: fs - 3, a: a), const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3));

          pw.Widget detailRow(String lbl, String val) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2.5),
            child: pw.Row(children: [
              pw.SizedBox(width: 62, child: t(lbl, s: fs - 1.5, c: PdfColors.grey600)),
              t(': ', s: fs - 1.5, c: PdfColors.grey600),
              pw.Expanded(child: t(val, f: bold, s: fs - 1.5)),
            ]),
          );

          // Items rows
          final itemRows = [
            ...tx.items.asMap().entries.map((e) => pw.TableRow(children: [
              pad(t('${e.key + 1}', a: pw.TextAlign.center)),
              pad(t(_itemLabel(e.value), s: fs - 0.5)),
              pad(t('—', a: pw.TextAlign.center)),
              pad(t('${e.value.quantity}', a: pw.TextAlign.center)),
              pad(t('$currencySymbol${e.value.price.toStringAsFixed(2)}', a: pw.TextAlign.right)),
              pad(t('${currencySymbol}0.00', a: pw.TextAlign.right)),
              pad(t('$taxRate%', a: pw.TextAlign.center)),
              pad(t('$currencySymbol${e.value.total.toStringAsFixed(2)}', f: bold, a: pw.TextAlign.right)),
            ])),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.SizedBox(),
                pad(t('TOTAL', f: bold)),
                pw.SizedBox(),
                pad(t('$totalQty', f: bold, a: pw.TextAlign.center)),
                pw.SizedBox(), pw.SizedBox(), pw.SizedBox(),
                pad(t('$currencySymbol${tx.subtotal.toStringAsFixed(2)}', f: bold, a: pw.TextAlign.right)),
              ],
            ),
          ];

          const colWidths = {
            0: pw.FixedColumnWidth(18),
            1: pw.FlexColumnWidth(4.0),
            2: pw.FixedColumnWidth(46),
            3: pw.FixedColumnWidth(30),
            4: pw.FixedColumnWidth(52),
            5: pw.FixedColumnWidth(44),
            6: pw.FixedColumnWidth(34),
            7: pw.FixedColumnWidth(52),
          };

          // ── Page ─────────────────────────────────────────────────────────
          return pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: grey5, bottom: grey5, left: grey5, right: grey5),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

              // ─ Title ─────────────────────────────────────────────────────
              pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
                padding: const pw.EdgeInsets.symmetric(vertical: 7),
                child: pw.Center(child: t('Tax Invoice', f: bold, s: 14)),
              ),

              // ─ Company header (logo + info | invoice details) ─────────────
              pw.Table(
                border: const pw.TableBorder(
                  bottom: grey4,
                  verticalInside: grey4,
                ),
                columnWidths: const {0: pw.FlexColumnWidth(58), 1: pw.FlexColumnWidth(42)},
                children: [
                  pw.TableRow(children: [
                    // Logo + company
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Container(
                          width: 52, height: 52,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                            color: PdfColors.grey100,
                          ),
                          child: pw.Center(child: t('Image', s: 7, c: PdfColors.grey500)),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          t(storeName.isNotEmpty ? storeName : 'Company', f: bold, s: headerFs),
                          if (storeAddress.isNotEmpty) ...[pw.SizedBox(height: 2), t(storeAddress, s: fs - 1.5, c: PdfColors.grey700)],
                          if (storePhone.isNotEmpty) ...[pw.SizedBox(height: 2), t('Phone: $storePhone', s: fs - 1, c: PdfColors.grey700)],
                          if (storeEmail.isNotEmpty) ...[pw.SizedBox(height: 1), t(storeEmail, s: fs - 1.5, c: PdfColors.grey700)],
                          if (storeGstin.isNotEmpty) ...[pw.SizedBox(height: 2), t('GSTIN: $storeGstin', f: bold, s: fs - 1)],
                        ])),
                      ]),
                    ),
                    // Invoice details
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        detailRow('Invoice No.', invoiceNo),
                        detailRow('Date', _fmtDate(tx.createdAt)),
                        detailRow('Time', _fmtTime(tx.createdAt)),
                      ]),
                    ),
                  ]),
                ],
              ),

              // ─ Bill To ───────────────────────────────────────────────────
              pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  t('Bill To:', f: bold, s: fs - 0.5, c: PdfColors.grey600),
                  pw.SizedBox(height: 3),
                  t(tx.customerName?.isNotEmpty == true ? tx.customerName! : 'Walk-In Customer',
                      f: bold, s: fs + 0.5),
                  if (tx.customerPhone != null && tx.customerPhone!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    t('Contact No.: ${tx.customerPhone}', s: fs - 1, c: PdfColors.grey700),
                  ],
                ]),
              ),

              // ─ Items table ───────────────────────────────────────────────
              pw.Table(
                border: const pw.TableBorder(
                  bottom: grey4,
                  horizontalInside: grey4,
                  verticalInside: grey4,
                ),
                columnWidths: colWidths,
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey800),
                    children: [
                      for (final h in [
                        ('#', pw.TextAlign.center), ('Item Name', pw.TextAlign.left),
                        ('HSC/SAC', pw.TextAlign.center), ('Qty', pw.TextAlign.center),
                        ('Price/Unit', pw.TextAlign.right), ('Discount', pw.TextAlign.right),
                        ('GST', pw.TextAlign.center), ('Amount', pw.TextAlign.right),
                      ])
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: t(h.$1, f: bold, s: fs - 2.5, c: PdfColors.white, a: h.$2),
                        ),
                    ],
                  ),
                  ...itemRows,
                ],
              ),

              // ─ Summary line (Sub Total | Discount | Tax | Total) ──────────
              pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Row(children: [
                  t('Sub Total', s: fs - 0.5),
                  t(': ', s: fs - 0.5, c: PdfColors.grey600),
                  t('$currencySymbol${tx.subtotal.toStringAsFixed(2)}', f: bold, s: fs - 0.5),
                  if (tx.discountAmount > 0) ...[
                    pw.SizedBox(width: 12),
                    t('Discount', s: fs - 0.5),
                    t(': ', s: fs - 0.5, c: PdfColors.grey600),
                    t('-$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', f: bold, s: fs - 0.5, c: PdfColors.green800),
                  ],
                  if (tx.taxAmount > 0) ...[
                    pw.SizedBox(width: 12),
                    t('Tax ($taxRate%)', s: fs - 0.5),
                    t(': ', s: fs - 0.5, c: PdfColors.grey600),
                    t('$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', f: bold, s: fs - 0.5),
                  ],
                  pw.Spacer(),
                  t('Total', f: bold, s: fs - 0.5),
                  t(': ', f: bold, s: fs - 0.5, c: PdfColors.grey600),
                  t('$currencySymbol${tx.total.toStringAsFixed(2)} (${_numberToWords(tx.total)})',
                      f: bold, s: fs - 0.5),
                ]),
              ),

              // ─ Tax Summary (left) | Totals (right) ───────────────────────
              pw.Table(
                border: const pw.TableBorder(
                  bottom: grey4,
                  verticalInside: grey4,
                ),
                columnWidths: const {0: pw.FlexColumnWidth(58), 1: pw.FlexColumnWidth(42)},
                children: [
                  pw.TableRow(children: [
                    // Tax Summary
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                      if (tx.taxAmount > 0)
                      pw.Table(
                        border: const pw.TableBorder(
                          horizontalInside: grey4,
                          verticalInside: grey4,
                          bottom: grey4,
                        ),
                        children: [
                          // Header
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey700),
                            children: [
                              for (final h in ['HSN/\nSAC', 'Taxable\nAmt', 'CGST\nRate%', 'CGST\nAmt', 'SGST\nRate%', 'SGST\nAmt', 'Total\nTax'])
                                taxCell(h, f: bold, a: pw.TextAlign.center),
                            ],
                          ),
                          // Data row
                          pw.TableRow(children: [
                            taxCell('—', a: pw.TextAlign.center),
                            taxCell('$currencySymbol${tx.subtotal.toStringAsFixed(2)}'),
                            taxCell('${halfRate}%', a: pw.TextAlign.center),
                            taxCell('$currencySymbol${cgst.toStringAsFixed(2)}'),
                            taxCell('${halfRate}%', a: pw.TextAlign.center),
                            taxCell('$currencySymbol${sgst.toStringAsFixed(2)}'),
                            taxCell('$currencySymbol${tx.taxAmount.toStringAsFixed(2)}'),
                          ]),
                          // Total row
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: [
                              taxCell('Total', f: bold, a: pw.TextAlign.left),
                              taxCell('$currencySymbol${tx.subtotal.toStringAsFixed(2)}', f: bold),
                              taxCell(''),
                              taxCell('$currencySymbol${cgst.toStringAsFixed(2)}', f: bold),
                              taxCell(''),
                              taxCell('$currencySymbol${sgst.toStringAsFixed(2)}', f: bold),
                              taxCell('$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', f: bold),
                            ],
                          ),
                        ],
                      ),
                    ]),
                    // Totals
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                        _tiTotalRow('Sub Total', '$currencySymbol${tx.subtotal.toStringAsFixed(2)}', regular, fs - 0.5),
                        if (tx.discountAmount > 0)
                          _tiTotalRow('Discount', '-$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', regular, fs - 0.5, valueColor: PdfColors.green800),
                        if (tx.taxAmount > 0) _tiTotalRow('Tax ($taxRate%)', '$currencySymbol${tx.taxAmount.toStringAsFixed(2)}', regular, fs - 0.5),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        _tiTotalRow('Total', '$currencySymbol${tx.total.toStringAsFixed(2)}', bold, fs + 1),
                        pw.SizedBox(height: 4),
                        pw.Text('Invoice Amount In Words:',
                            style: pw.TextStyle(font: bold, fontSize: fs - 2.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text(_numberToWords(tx.total),
                            style: pw.TextStyle(font: regular, fontSize: fs - 2.5, color: PdfColors.grey700)),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        _tiTotalRow('Received', '$currencySymbol${tx.total.toStringAsFixed(2)}', regular, fs - 0.5),
                        _tiTotalRow('Balance', '${currencySymbol}0.00', regular, fs - 0.5),
                        if (tx.discountAmount > 0)
                          _tiTotalRow('You Saved', '$currencySymbol${tx.discountAmount.toStringAsFixed(2)}', regular, fs - 0.5, valueColor: PdfColors.green800),
                      ]),
                    ),
                  ]),
                ],
              ),

              // ─ Payment mode ───────────────────────────────────────────────
              pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: grey4)),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: pw.Row(children: [
                  t('Payment Mode:', f: bold, s: fs - 0.5),
                  pw.SizedBox(width: 6),
                  t(tx.paymentMethod.toUpperCase(), s: fs - 0.5),
                ]),
              ),

              // ─ Footer 3-column ────────────────────────────────────────────
              pw.Table(
                border: const pw.TableBorder(verticalInside: grey4),
                children: [
                  pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        t('Description:', f: bold, s: fs - 1, c: PdfColors.grey700),
                        pw.SizedBox(height: 3),
                        t(receiptFooter.isNotEmpty ? receiptFooter : 'Sale Description',
                            s: fs - 1.5, c: PdfColors.grey600),
                        pw.SizedBox(height: 18),
                      ]),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        t('Terms & Conditions:', f: bold, s: fs - 1, c: PdfColors.grey700),
                        pw.SizedBox(height: 3),
                        t(storeTerms.isNotEmpty ? storeTerms : 'Thanks for doing business with us!',
                            s: fs - 1.5, c: PdfColors.grey600),
                        pw.SizedBox(height: 18),
                      ]),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        t('For: ${storeName.isNotEmpty ? storeName : "Company"}',
                            f: bold, s: fs - 1, c: PdfColors.grey700),
                        pw.SizedBox(height: 24),
                        pw.Center(child: t('Authorized Signatory', s: fs - 2, c: PdfColors.grey600)),
                      ]),
                    ),
                  ]),
                ],
              ),

            ]),
          );
        },
      ),
    );

    return doc.save();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _taxDataRow({
    required String hsn, required String taxable,
    required String cgstRate, required String cgstAmt,
    required String sgstRate, required String sgstAmt,
    required String total,
    required pw.Font font, required double fs,
    required pw.BorderSide grey4, PdfColor? bg,
  }) {
    pw.Widget cell(String v, int flex, {bool last = false, bool center = false}) =>
        pw.Expanded(
          flex: flex,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: bg,
              border: last ? null : pw.Border(right: grey4),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Text(v,
                textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
                style: pw.TextStyle(font: font, fontSize: fs - 3)),
          ),
        );
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: grey4),
        color: bg,
      ),
      child: pw.Row(children: [
        cell(hsn,      12, center: true),
        cell(taxable,  16),
        cell(cgstRate, 11, center: true),
        cell(cgstAmt,  13),
        cell(sgstRate, 11, center: true),
        cell(sgstAmt,  13),
        cell(total,    15, last: true),
      ]),
    );
  }

  static pw.Widget _tiTotalRow(String label, String value, pw.Font font, double fs,
      {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: fs, color: PdfColors.grey700)),
        pw.Text(value,
            style: pw.TextStyle(font: font, fontSize: fs, color: valueColor)),
      ]),
    );
  }

  static pw.Widget _totalRow(String label, String value, pw.Font font, double fs,
      {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: fs, color: PdfColors.grey700)),
        pw.Text(value,
            style: pw.TextStyle(font: font, fontSize: fs, color: valueColor ?? PdfColors.grey700)),
      ]),
    );
  }

  static PdfPageFormat _pageFormat(String paperSize, int itemCount) {
    if (paperSize == 'A4') return PdfPageFormat.a4;
    if (paperSize == 'A5') return PdfPageFormat.a5;
    final double widthMm = paperSize == '2 inch' ? 48.0
        : paperSize == '4 inch' ? 104.0
        : 79.5; // 3 inch, Custom, or fallback
    final heightMm = 95.0 + (itemCount * 7.0);
    return PdfPageFormat(widthMm * PdfPageFormat.mm, heightMm * PdfPageFormat.mm, marginAll: 0);
  }

  static String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year}  $h:$mi';
  }

  static String _fmtDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year}';
  }

  // ── Vyapar-style Tax Invoice ──────────────────────────────────────────────
  static Future<Uint8List> _buildVyaparPdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    String storeTerms = '',
    String logoPath = '',
  }) async {
    await preWarm();
    final r = _regular!;
    final b = _bold!;

    pw.ImageProvider? logoImage;
    if (logoPath.isNotEmpty) {
      try {
        final bytes = await File(logoPath).readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    const fs = 8.5;
    final taxRateVal = double.tryParse(taxRate) ?? 0.0;
    final halfRate   = taxRateVal / 2;
    final cgst       = tx.taxAmount / 2;
    final sgst       = tx.taxAmount / 2;
    final totalQty   = tx.items.fold<int>(0, (s, i) => s + i.quantity);
    final invoiceNo  = tx.id.length >= 6 ? tx.id.substring(0, 6).toUpperCase() : tx.id.toUpperCase();

    const border4   = pw.BorderSide(color: PdfColors.grey400, width: 0.5);
    const border6   = pw.BorderSide(color: PdfColors.grey600, width: 0.8);
    const outerBox  = pw.BoxDecoration(border: pw.Border(top: border6, bottom: border6, left: border6, right: border6));
    const divBottom = pw.BoxDecoration(border: pw.Border(bottom: border4));
    const greyBg    = pw.BoxDecoration(color: PdfColors.grey200, border: pw.Border(bottom: border4));

    // Helper: text widget
    pw.Widget t(String v, {pw.Font? f, double? s, PdfColor? c,
        pw.TextAlign a = pw.TextAlign.left, int? ml}) =>
        pw.Text(v, maxLines: ml, textAlign: a,
            style: pw.TextStyle(font: f ?? r, fontSize: s ?? fs, color: c));

    // Padded cell helper
    pw.Widget cell(pw.Widget w, [pw.EdgeInsets? pad]) =>
        pw.Padding(padding: pad ?? const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3), child: w);

    // Right-panel totals row
    pw.Widget totRow(String lbl, String val, {bool bold = false, double? sz, PdfColor? vc}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            t(lbl, f: bold ? b : r, s: sz ?? (fs - 0.5), c: bold ? null : PdfColors.grey700),
            pw.Row(children: [
              t(':', f: bold ? b : r, s: sz ?? (fs - 0.5), c: bold ? null : PdfColors.grey700),
              pw.SizedBox(width: 6),
              t(val, f: bold ? b : r, s: sz ?? (fs - 0.5), c: vc),
            ]),
          ]),
        );

    // Items table rows
    final itemRows = tx.items.asMap().entries.map((e) {
      final item = e.value;
      return pw.TableRow(children: [
        cell(t('${e.key + 1}', a: pw.TextAlign.center, s: fs - 1)),
        cell(t(_itemLabel(item), f: b, s: fs - 1)),
        cell(t('—', a: pw.TextAlign.center, s: fs - 1)),
        cell(t('${item.quantity}', a: pw.TextAlign.center, s: fs - 1)),
        cell(t('—', a: pw.TextAlign.center, s: fs - 1)),
        cell(t('$currencySymbol ${item.price.toStringAsFixed(2)}', a: pw.TextAlign.right, s: fs - 1)),
        cell(t('$currencySymbol ${item.total.toStringAsFixed(2)}', f: b, a: pw.TextAlign.right, s: fs - 1)),
      ]);
    }).toList();

    // CGST/SGST tax summary rows
    pw.Widget taxRow({required String hsn, required String taxable,
        required String cgstR, required String cgstA,
        required String sgstR, required String sgstA,
        required String total, pw.Font? font, PdfColor? bg}) {
      final f2 = font ?? r;
      return pw.Container(
        color: bg,
        child: pw.Row(children: [
          pw.Expanded(flex: 12, child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: border4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: t(hsn, f: f2, s: fs - 3),
          )),
          pw.Expanded(flex: 16, child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: border4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: t(taxable, f: f2, s: fs - 3, a: pw.TextAlign.right),
          )),
          pw.Expanded(flex: 12, child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: border4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: t(cgstR, f: f2, s: fs - 3, a: pw.TextAlign.right),
          )),
          pw.Expanded(flex: 12, child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: border4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: t(cgstA, f: f2, s: fs - 3, a: pw.TextAlign.right),
          )),
          pw.Expanded(flex: 12, child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: border4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: t(sgstR, f: f2, s: fs - 3, a: pw.TextAlign.right),
          )),
          pw.Expanded(flex: 12, child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(right: border4)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: t(sgstA, f: f2, s: fs - 3, a: pw.TextAlign.right),
          )),
          pw.Expanded(flex: 14, child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: t(total, f: f2, s: fs - 3, a: pw.TextAlign.right),
          )),
        ]),
      );
    }

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => pw.Container(
        decoration: outerBox,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

          // ── Title ─────────────────────────────────────────────────────────
          pw.Container(
            decoration: divBottom,
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            child: pw.Center(child: t('Tax Invoice', f: b, s: fs + 2)),
          ),

          // ── Company info (full width) ──────────────────────────────────────
          pw.Container(
            decoration: divBottom,
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              // Logo
              pw.Container(
                width: 62, height: 62,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
                child: logoImage != null
                    ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                    : pw.Center(child: t('IMG', s: 7, c: PdfColors.grey500)),
              ),
              pw.SizedBox(width: 12),
              // Company details
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                t(storeName.isNotEmpty ? storeName : 'Company', f: b, s: 18),
                pw.SizedBox(height: 3),
                if (storeAddress.isNotEmpty) t(storeAddress, s: fs - 1, c: PdfColors.grey700),
                if (storePhone.isNotEmpty || storeEmail.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Row(children: [
                    if (storePhone.isNotEmpty) pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Phone: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                      pw.TextSpan(text: storePhone, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                    ])),
                    if (storePhone.isNotEmpty && storeEmail.isNotEmpty) t('    ', s: fs - 1),
                    if (storeEmail.isNotEmpty) pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Email: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                      pw.TextSpan(text: storeEmail, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                    ])),
                  ]),
                ],
                if (storeGstin.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'GSTIN: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                    pw.TextSpan(text: storeGstin, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                  ])),
                ],
              ])),
            ]),
          ),

          // ── Bill To (left) | Invoice Details (right) ──────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                pw.Container(decoration: greyBg,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: t('Bill To:', f: b, s: fs - 0.5)),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    t(tx.customerName?.isNotEmpty == true ? tx.customerName! : 'Walk-In Customer', f: b, s: fs - 0.5),
                    if (tx.customerPhone != null && tx.customerPhone!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      t('Contact No: ${tx.customerPhone}', s: fs - 1.5, c: PdfColors.grey700),
                    ],
                  ]),
                ),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                pw.Container(decoration: greyBg,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: t('Invoice Details:', f: b, s: fs - 0.5)),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'No: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                      pw.TextSpan(text: invoiceNo, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                    ])),
                    pw.SizedBox(height: 3),
                    pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Date: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                      pw.TextSpan(text: _fmtDate(tx.createdAt), style: pw.TextStyle(font: b, fontSize: fs - 1)),
                    ])),
                  ]),
                ),
              ]),
            ])],
          ),

          // ── Ship To (full width) ───────────────────────────────────────────
          pw.Container(
            decoration: divBottom,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              pw.Container(decoration: greyBg,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: t('Ship To:', f: b, s: fs - 0.5)),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: t(tx.customerName?.isNotEmpty == true ? tx.customerName! : '—', s: fs - 1, c: PdfColors.grey700),
              ),
            ]),
          ),

          // ── Items table ────────────────────────────────────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, horizontalInside: border4, verticalInside: border4),
            columnWidths: const {
              0: pw.FixedColumnWidth(14),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FixedColumnWidth(44),
              3: pw.FixedColumnWidth(38),
              4: pw.FixedColumnWidth(30),
              5: pw.FixedColumnWidth(68),
              6: pw.FixedColumnWidth(60),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  for (final h in [
                    ('#', pw.TextAlign.center),
                    ('Item name', pw.TextAlign.left),
                    ('HSN/ SAC', pw.TextAlign.center),
                    ('Quantity', pw.TextAlign.center),
                    ('Unit', pw.TextAlign.center),
                    ('Price/ Unit($currencySymbol)', pw.TextAlign.right),
                    ('Amount($currencySymbol)', pw.TextAlign.right),
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: t(h.$1, f: b, s: fs - 2.5, a: h.$2),
                    ),
                ],
              ),
              ...itemRows,
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.SizedBox(),
                  cell(t('Total', f: b, s: fs - 1)),
                  pw.SizedBox(),
                  cell(t('$totalQty', f: b, a: pw.TextAlign.center, s: fs - 1)),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  cell(t('$currencySymbol ${tx.total.toStringAsFixed(2)}', f: b, a: pw.TextAlign.right, s: fs - 1)),
                ],
              ),
            ],
          ),

          // ── Payment Mode (left) | Totals (right) ──────────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              // Left: payment mode + tax summary
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                if (tx.taxAmount > 0) ...[
                // CGST/SGST header
                pw.Container(
                  color: PdfColors.grey100,
                  child: pw.Row(children: [
                    pw.Expanded(flex: 12, child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(right: border4, bottom: border4)),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      child: t('HSN', f: b, s: fs - 3, a: pw.TextAlign.center),
                    )),
                    pw.Expanded(flex: 16, child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(right: border4, bottom: border4)),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      child: t('Taxable', f: b, s: fs - 3, a: pw.TextAlign.center),
                    )),
                    pw.Expanded(flex: 24, child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(right: border4, bottom: border4)),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                        pw.Container(
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: border4)),
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Center(child: t('CGST', f: b, s: fs - 3)),
                        ),
                        pw.Row(children: [
                          pw.Expanded(flex: 1, child: pw.Container(
                            decoration: const pw.BoxDecoration(border: pw.Border(right: border4)),
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: t('Rate(%)', f: b, s: fs - 3.5, a: pw.TextAlign.center),
                          )),
                          pw.Expanded(flex: 1, child: pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: t('Amt', f: b, s: fs - 3.5, a: pw.TextAlign.center),
                          )),
                        ]),
                      ]),
                    )),
                    pw.Expanded(flex: 24, child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: border4)),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                        pw.Container(
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: border4)),
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Center(child: t('SGST', f: b, s: fs - 3)),
                        ),
                        pw.Row(children: [
                          pw.Expanded(flex: 1, child: pw.Container(
                            decoration: const pw.BoxDecoration(border: pw.Border(right: border4)),
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: t('Rate(%)', f: b, s: fs - 3.5, a: pw.TextAlign.center),
                          )),
                          pw.Expanded(flex: 1, child: pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: t('Amt', f: b, s: fs - 3.5, a: pw.TextAlign.center),
                          )),
                        ]),
                      ]),
                    )),
                  ]),
                ),
                taxRow(
                  hsn: '—', taxable: tx.subtotal.toStringAsFixed(2),
                  cgstR: '${halfRate.toStringAsFixed(1)}%', cgstA: cgst.toStringAsFixed(2),
                  sgstR: '${halfRate.toStringAsFixed(1)}%', sgstA: sgst.toStringAsFixed(2),
                  total: tx.taxAmount.toStringAsFixed(2),
                ),
                taxRow(
                  hsn: 'TOTAL', taxable: tx.subtotal.toStringAsFixed(2),
                  cgstR: '', cgstA: cgst.toStringAsFixed(2),
                  sgstR: '', sgstA: sgst.toStringAsFixed(2),
                  total: tx.taxAmount.toStringAsFixed(2),
                  font: b, bg: PdfColors.grey100,
                ),
                ],
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: border4)),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Payment Mode:\n', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                    pw.TextSpan(text: tx.paymentMethod, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                  ])),
                ),
              ]),
              // Right: totals
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                  totRow('Sub Total', '$currencySymbol ${tx.subtotal.toStringAsFixed(2)}'),
                  if (tx.discountAmount > 0)
                    totRow('Discount', '- $currencySymbol ${tx.discountAmount.toStringAsFixed(2)}', vc: PdfColors.green800),
                  totRow('Tax ($taxRate%)', '$currencySymbol ${tx.taxAmount.toStringAsFixed(2)}'),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  totRow('Total', '$currencySymbol ${tx.total.toStringAsFixed(2)}', bold: true, sz: fs + 1),
                  pw.SizedBox(height: 6),
                  t('Invoice Amount in Words :', f: b, s: fs - 1.5, c: PdfColors.grey600),
                  pw.SizedBox(height: 2),
                  t(_numberToWords(tx.total), s: fs - 2, c: PdfColors.grey600),
                  pw.SizedBox(height: 6),
                  totRow('Received', '$currencySymbol ${tx.total.toStringAsFixed(2)}'),
                  totRow('Balance', '$currencySymbol 0.00'),
                ]),
              ),
            ])],
          ),

          // ── Terms & Conditions (left) | Authorized Signatory (right) ──────
          pw.Table(
            border: const pw.TableBorder(verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: border4)),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: t('Terms & Conditions:', f: b, s: fs - 0.5),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: t(storeTerms.isNotEmpty ? storeTerms : 'Thanks for doing business with us!',
                      s: fs - 1.5, c: PdfColors.grey600),
                ),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: border4)),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: t('For ${storeName.isNotEmpty ? storeName : "Company"}:', f: b, s: fs - 0.5),
                ),
                pw.SizedBox(height: 40),
                pw.Center(child: t('Authorized Signatory', s: fs - 1.5, c: PdfColors.grey600)),
                pw.SizedBox(height: 8),
              ]),
            ])],
          ),

        ]),
      ),
    ));
    return doc.save();
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$h:$mi';
  }

  // ── Number to words (Indian format) ──────────────────────────────────────
  static String _numberToWords(double amount) {
    final n = amount.toInt();
    final paise = ((amount - n) * 100).round();
    var result = '${_toWords(n)} Rupees';
    if (paise > 0) result += ' and ${_toWords(paise)} Paise';
    return '$result Only';
  }

  static String _toWords(int n) {
    if (n == 0) return 'Zero';
    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
                   'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
                   'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    final buf = StringBuffer();
    var rem = n;

    if (rem >= 10000000) {
      buf.write('${_toWords(rem ~/ 10000000)} Crore ');
      rem %= 10000000;
    }
    if (rem >= 100000) {
      buf.write('${_toWords(rem ~/ 100000)} Lakh ');
      rem %= 100000;
    }
    if (rem >= 1000) {
      buf.write('${_toWords(rem ~/ 1000)} Thousand ');
      rem %= 1000;
    }
    if (rem >= 100) {
      buf.write('${ones[rem ~/ 100]} Hundred ');
      rem %= 100;
    }
    if (rem >= 20) {
      buf.write('${tens[rem ~/ 10]} ');
      rem %= 10;
    }
    if (rem > 0) buf.write(ones[rem]);

    return buf.toString().trim();
  }

  // ── Modern 4 — exact replica of Metro Gadgetz invoice ───────────────────
  static Future<Uint8List> _buildModern4Pdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    String storeTerms = '',
    String logoPath = '',
    String storeUpiId = '',
  }) async {
    await preWarm();
    final r = _poppinsRegular ?? _regular!;
    final b = _poppinsBold   ?? _bold!;

    pw.ImageProvider? logoImage;
    if (logoPath.isNotEmpty) {
      try {
        final bytes = await File(logoPath).readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    const fs = 10.0;
    final invoiceNo = tx.id.length >= 6 ? tx.id.substring(0, 6).toUpperCase() : tx.id.toUpperCase();
    final dateStr = () {
      final d = tx.createdAt;
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    }();

    String fmt(double v) {
      final parts = v.toStringAsFixed(2).split('.');
      final intStr = parts[0];
      final buf = StringBuffer();
      for (int i = 0; i < intStr.length; i++) {
        if (i > 0 && (intStr.length - i) % 3 == 0) buf.write(',');
        buf.write(intStr[i]);
      }
      return '$currencySymbol$buf.${parts[1]}';
    }

    pw.Widget tx_(String v, {pw.Font? f, double? s, PdfColor? c,
        pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Text(v, textAlign: a,
            style: pw.TextStyle(font: f ?? r, fontSize: s ?? fs, color: c));

    pw.Widget cell(pw.Widget w, [pw.EdgeInsets? e]) => pw.Padding(
        padding: e ?? const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: w);

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

        // ── 1. Black header ───────────────────────────────────────────────────
        pw.Container(
          color: PdfColors.black,
          padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            if (logoImage != null)
              pw.Container(width: 80, height: 80,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain))
            else
              pw.Container(
                width: 80, height: 80,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600, width: 0.5)),
                child: pw.Center(child: tx_(
                    storeName.isNotEmpty ? storeName.substring(0, 1) : 'M',
                    f: b, s: 28, c: PdfColors.white)),
              ),
            pw.SizedBox(width: 20),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              if (storeAddress.isNotEmpty)
                tx_(storeAddress, s: fs - 1, c: PdfColors.white, a: pw.TextAlign.right),
              if (storePhone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                tx_(storePhone, s: fs - 1, c: PdfColors.white, a: pw.TextAlign.right),
              ],
              if (storeEmail.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                tx_(storeEmail, s: fs - 1, c: PdfColors.white, a: pw.TextAlign.right),
              ],
            ])),
          ]),
        ),

        // ── 2. Bill To (left) | Total Due (right) ────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 20, 28, 14),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              tx_('invoice to :', s: fs - 2, c: PdfColors.grey600),
              pw.SizedBox(height: 4),
              tx_(tx.customerName?.isNotEmpty == true ? tx.customerName! : 'Walk-in Customer',
                  f: b, s: fs + 10),
              if (tx.customerPhone?.isNotEmpty == true) ...[
                pw.SizedBox(height: 3),
                tx_(tx.customerPhone!, s: fs, c: PdfColors.grey700),
              ],
              pw.SizedBox(height: 3),
              tx_('Invoice no : $invoiceNo', s: fs, c: PdfColors.grey700),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              tx_('Total due', s: fs - 1, c: PdfColors.grey600, a: pw.TextAlign.right),
              pw.SizedBox(height: 4),
              tx_(fmt(tx.total), f: b, s: fs + 13, a: pw.TextAlign.right),
              pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 5),
                  height: 1.5, width: 150, color: PdfColors.black),
              pw.SizedBox(height: 4),
              tx_('Date : $dateStr', s: fs, c: PdfColors.grey700, a: pw.TextAlign.right),
            ]),
          ]),
        ),

        // ── 3. Items table ────────────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(4.0),
              1: pw.FixedColumnWidth(60),
              2: pw.FixedColumnWidth(80),
              3: pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.black),
                children: [
                  for (final h in [
                    ('Description', pw.TextAlign.left),
                    ('Qty',         pw.TextAlign.center),
                    ('Price',       pw.TextAlign.right),
                    ('Total',       pw.TextAlign.right),
                  ])
                    cell(tx_(h.$1, f: b, s: fs, c: PdfColors.white, a: h.$2),
                        const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
                ],
              ),
              ...tx.items.asMap().entries.map((e) {
                final item = e.value;
                final bg = e.key.isEven ? PdfColors.white : PdfColors.grey100;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell(tx_(_itemLabel(item), s: fs),
                        const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
                    cell(tx_('${item.quantity}', s: fs, a: pw.TextAlign.center),
                        const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
                    cell(tx_(fmt(item.price), s: fs, a: pw.TextAlign.right),
                        const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
                    cell(tx_(fmt(item.total), f: b, s: fs, a: pw.TextAlign.right),
                        const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
                  ],
                );
              }),
            ],
          ),
        ),

        // ── Thin divider after items ──────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Container(height: 0.8, color: PdfColors.grey400),
        ),
        pw.SizedBox(height: 14),

        // ── 4a. Sub-total + Tax on RIGHT only ─────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Row(children: [
            pw.Expanded(child: pw.SizedBox()),
            pw.SizedBox(
              width: 195,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                _modernTotRow('Sub-total :', fmt(tx.subtotal), r, b, fs, bold: false),
                if (tx.discountAmount > 0)
                  _modernTotRow('Discount :', '- ${fmt(tx.discountAmount)}', r, b, fs, bold: false),
                _modernTotRow(
                    tx.taxAmount > 0 ? '${taxLabel.isNotEmpty ? taxLabel : 'Tax'} :' : 'Tax :',
                    tx.taxAmount > 0 ? fmt(tx.taxAmount) : fmt(0),
                    r, b, fs, bold: false),
              ]),
            ),
          ]),
        ),

        // ── 4b. "UPI Method:" (left) | Total black box (right) ───────────────
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 6, 28, 0),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Expanded(child: tx_('UPI Method :', f: b, s: fs + 1)),
            pw.SizedBox(
              width: 195,
              child: pw.Container(
                color: PdfColors.black,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  tx_('Total :', f: b, s: fs + 1, c: PdfColors.white),
                  tx_(fmt(tx.total), f: b, s: fs + 1, c: PdfColors.white, a: pw.TextAlign.right),
                ]),
              ),
            ),
          ]),
        ),

        // ── 4c. QR code below UPI label ───────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 0),
          child: storeUpiId.isNotEmpty
              ? pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'upi://pay?pa=${Uri.encodeComponent(storeUpiId)}&pn=${Uri.encodeComponent(storeName)}&cu=INR',
                  width: 65, height: 65, drawText: false,
                )
              : pw.Container(
                  width: 58, height: 58,
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                  child: pw.Center(child: tx_('QR', s: 9, c: PdfColors.grey600)),
                ),
        ),

        // ── 4d. Thanks For Choosing ───────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            tx_('Thanks For Choosing', f: b, s: fs + 6),
            tx_('${storeName.isNotEmpty ? storeName : 'Us'}!', f: b, s: fs + 6),
          ]),
        ),

        pw.Expanded(child: pw.SizedBox()),

        // ── 5. Footer: Terms (left) | Signatory (right) ──────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 10, 28, 28),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              tx_('Terms and Conditions', f: b, s: fs),
              pw.SizedBox(height: 5),
              tx_(storeTerms.isNotEmpty ? storeTerms : receiptFooter,
                  s: fs - 2, c: PdfColors.grey600),
            ])),
            pw.SizedBox(width: 30),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Container(width: 130, height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 5),
              tx_(storeName.isNotEmpty ? storeName : 'Authorized Signatory',
                  f: b, s: fs, a: pw.TextAlign.center),
              tx_('Owner', s: fs - 1.5, c: PdfColors.grey600, a: pw.TextAlign.center),
            ]),
          ]),
        ),
      ]),
    ));

    return doc.save();
  }

  static pw.Widget _modernTotRow(String lbl, String val,
      pw.Font r, pw.Font b, double fs, {required bool bold}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(lbl, style: pw.TextStyle(font: bold ? b : r, fontSize: fs - 0.5,
              color: bold ? PdfColors.black : PdfColors.grey700)),
          pw.SizedBox(width: 40),
          pw.Text(val, style: pw.TextStyle(font: bold ? b : r, fontSize: fs - 0.5)),
        ]),
      );

  // ── Landscape Tax Invoice ─────────────────────────────────────────────────
  static Future<Uint8List> _buildLandscapePdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    String storeTerms = '',
    String logoPath = '',
  }) async {
    await preWarm();
    final r = _regular!;
    final b = _bold!;

    pw.ImageProvider? logoImage;
    if (logoPath.isNotEmpty) {
      try {
        final bytes = await File(logoPath).readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    const double fs = 8.5;
    final invoiceNo = 'Inv. ${tx.id.substring(0, 6).toUpperCase()}';
    final totalQty  = tx.items.fold<int>(0, (s, i) => s + i.quantity);
    final dateStr   = '${tx.createdAt.day.toString().padLeft(2, '0')}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.year}';

    String fmtAmt(double v) {
      final parts = v.toStringAsFixed(2).split('.');
      final buf = StringBuffer();
      final s2 = parts[0];
      for (int i = 0; i < s2.length; i++) {
        if (i > 0 && (s2.length - i) % 3 == 0) buf.write(',');
        buf.write(s2[i]);
      }
      return '$currencySymbol$buf.${parts[1]}';
    }

    const border4  = pw.BorderSide(color: PdfColors.grey400, width: 0.5);
    const border6  = pw.BorderSide(color: PdfColors.grey600, width: 0.8);
    const outerBox = pw.BoxDecoration(border: pw.Border(top: border6, bottom: border6, left: border6, right: border6));
    const divB     = pw.BoxDecoration(border: pw.Border(bottom: border4));

    pw.Widget tx_(String v, {pw.Font? f, double? s, PdfColor? c,
        pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Text(v, textAlign: a,
            style: pw.TextStyle(font: f ?? r, fontSize: s ?? fs, color: c));

    pw.Widget pad(pw.Widget w, [pw.EdgeInsets? e]) =>
        pw.Padding(padding: e ?? const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3), child: w);

    // Items table rows
    final itemRows = tx.items.asMap().entries.map((e) {
      final item = e.value;
      return pw.TableRow(children: [
        pad(tx_('${e.key + 1}', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_(_itemLabel(item), f: b, s: fs - 1)),
        pad(tx_('—', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_('${item.quantity}', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_('—', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_(fmtAmt(item.price), a: pw.TextAlign.right, s: fs - 1)),
        pad(tx_(fmtAmt(item.total), f: b, a: pw.TextAlign.right, s: fs - 1)),
      ]);
    }).toList();

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => pw.Container(
        decoration: outerBox,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

          // ── Title ──────────────────────────────────────────────────────
          pw.Container(
            decoration: divB,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Center(child: tx_('Tax Invoice', f: b, s: fs + 1)),
          ),

          // ── Company info (left) | Invoice details (right) ──────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(60), 1: pw.FlexColumnWidth(40)},
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(
                    width: 56, height: 56,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    ),
                    child: logoImage != null
                        ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                        : pw.Center(child: tx_('Image', s: 7, c: PdfColors.grey500)),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    tx_(storeName.isNotEmpty ? storeName : 'Company', f: b, s: 16),
                    pw.SizedBox(height: 3),
                    if (storeAddress.isNotEmpty) tx_(storeAddress, s: fs - 1, c: PdfColors.grey700),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      if (storePhone.isNotEmpty) ...[
                        tx_('Phone: ', s: fs - 1, c: PdfColors.grey700),
                        tx_(storePhone, f: b, s: fs - 1),
                        pw.SizedBox(width: 8),
                      ],
                      if (storeEmail.isNotEmpty) ...[
                        tx_('Email: ', s: fs - 1, c: PdfColors.grey700),
                        tx_(storeEmail, f: b, s: fs - 1),
                      ],
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      if (storeGstin.isNotEmpty) ...[
                        tx_('GSTIN: ', s: fs - 1, c: PdfColors.grey700),
                        tx_(storeGstin, f: b, s: fs - 1),
                        pw.SizedBox(width: 8),
                      ],
                    ]),
                  ])),
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Invoice No.: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                    pw.TextSpan(text: invoiceNo, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                  ])),
                  pw.SizedBox(height: 4),
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Date: ', style: pw.TextStyle(font: r, fontSize: fs - 1, color: PdfColors.grey700)),
                    pw.TextSpan(text: dateStr, style: pw.TextStyle(font: b, fontSize: fs - 1)),
                  ])),
                ]),
              ),
            ])],
          ),

          // ── Bill To (left) | Ship To (right) ──────────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(50), 1: pw.FlexColumnWidth(50)},
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('Bill To:', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 3),
                  tx_(tx.customerName?.isNotEmpty == true ? tx.customerName! : 'Walk-In Customer', s: fs - 1),
                  if (tx.customerPhone != null && tx.customerPhone!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    tx_(tx.customerPhone!, s: fs - 1.5, c: PdfColors.grey700),
                  ],
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('Ship To:', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 3),
                  tx_(tx.customerName?.isNotEmpty == true ? tx.customerName! : '—', s: fs - 1, c: PdfColors.grey700),
                ]),
              ),
            ])],
          ),

          // ── Items table ────────────────────────────────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, horizontalInside: border4, verticalInside: border4),
            columnWidths: const {
              0: pw.FixedColumnWidth(16),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FixedColumnWidth(46),
              3: pw.FixedColumnWidth(38),
              4: pw.FixedColumnWidth(32),
              5: pw.FixedColumnWidth(74),
              6: pw.FixedColumnWidth(68),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  for (final h in [
                    ('#',                         pw.TextAlign.center),
                    ('Item name',                 pw.TextAlign.left),
                    ('HSN/SAC',                   pw.TextAlign.center),
                    ('Qty',                       pw.TextAlign.center),
                    ('Unit',                      pw.TextAlign.center),
                    ('Price/Unit($currencySymbol)', pw.TextAlign.right),
                    ('Amount($currencySymbol)',    pw.TextAlign.right),
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: tx_(h.$1, f: b, s: fs - 2.5, a: h.$2),
                    ),
                ],
              ),
              ...itemRows,
              // TOTAL row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.SizedBox(),
                  pad(tx_('Total', f: b, s: fs - 1)),
                  pw.SizedBox(),
                  pad(tx_('$totalQty', f: b, a: pw.TextAlign.center, s: fs - 1)),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  pad(tx_(fmtAmt(tx.total), f: b, a: pw.TextAlign.right, s: fs - 1)),
                ],
              ),
            ],
          ),

          // ── Sub Total (left) | Total+words (right) ─────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(50), 1: pw.FlexColumnWidth(50)},
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Sub Total: ', style: pw.TextStyle(font: r, fontSize: fs - 0.5, color: PdfColors.grey700)),
                    pw.TextSpan(text: fmtAmt(tx.subtotal), style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
                  ])),
                  if (tx.discountAmount > 0) ...[
                    pw.SizedBox(height: 2),
                    pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Discount: ', style: pw.TextStyle(font: r, fontSize: fs - 0.5, color: PdfColors.grey700)),
                      pw.TextSpan(text: '-${fmtAmt(tx.discountAmount)}', style: pw.TextStyle(font: b, fontSize: fs - 0.5, color: PdfColors.green800)),
                    ])),
                  ],
                  if (tx.taxAmount > 0) ...[
                    pw.SizedBox(height: 2),
                    pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: '$taxLabel ($taxRate%): ', style: pw.TextStyle(font: r, fontSize: fs - 0.5, color: PdfColors.grey700)),
                      pw.TextSpan(text: fmtAmt(tx.taxAmount), style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
                    ])),
                  ],
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Total: ', style: pw.TextStyle(font: r, fontSize: fs - 0.5, color: PdfColors.grey700)),
                    pw.TextSpan(text: fmtAmt(tx.total), style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
                  ])),
                  pw.SizedBox(height: 2),
                  tx_('(${_numberToWords(tx.total)})', s: fs - 2, c: PdfColors.grey600),
                ]),
              ),
            ])],
          ),

          // ── Received | Balance ─────────────────────────────────────────
          pw.Container(
            decoration: divB,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: pw.Row(children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Received: ', style: pw.TextStyle(font: r, fontSize: fs - 0.5, color: PdfColors.grey700)),
                pw.TextSpan(text: fmtAmt(tx.total), style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
              ])),
              pw.SizedBox(width: 24),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Balance: ', style: pw.TextStyle(font: r, fontSize: fs - 0.5, color: PdfColors.grey700)),
                pw.TextSpan(text: fmtAmt(0.0), style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
              ])),
            ]),
          ),

          // ── Payment Mode ───────────────────────────────────────────────
          pw.Container(
            decoration: divB,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Payment Mode: ', style: pw.TextStyle(font: r, fontSize: fs - 0.5, color: PdfColors.grey700)),
              pw.TextSpan(text: tx.paymentMethod, style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
            ])),
          ),

          // ── Terms (left) | For: StoreName + Signatory (right) ─────────
          pw.Table(
            border: const pw.TableBorder(verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('Terms & Conditions:', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 3),
                  tx_(storeTerms.isNotEmpty ? storeTerms : receiptFooter.isNotEmpty ? receiptFooter : 'Thanks for doing business with us!',
                      s: fs - 1.5, c: PdfColors.grey600),
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('For ${storeName.isNotEmpty ? storeName : "Company"}:', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 36),
                  pw.Center(child: tx_('Authorized Signatory', s: fs - 1.5, c: PdfColors.grey600)),
                  pw.SizedBox(height: 8),
                ]),
              ),
            ])],
          ),

        ]),
      ),
    ));
    return doc.save();
  }

  // ── GST Tax Invoice (structured layout with amount-in-words section) ───────
  static Future<Uint8List> _buildGstPdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    String storeTerms = '',
    String logoPath = '',
    String docType = 'Invoice',
  }) async {
    await preWarm();
    final r = _regular!;
    final b = _bold!;

    pw.ImageProvider? logoImage;
    if (logoPath.isNotEmpty) {
      try {
        final bytes = await File(logoPath).readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    const double fs = 8.5;
    final invoiceNo = tx.id.substring(0, 6).toUpperCase();
    final totalQty  = tx.items.fold<int>(0, (s, i) => s + i.quantity);
    final dateStr   = '${tx.createdAt.day.toString().padLeft(2, '0')}-${tx.createdAt.month.toString().padLeft(2, '0')}-${tx.createdAt.year}';

    String fmtAmt(double v) {
      final parts = v.toStringAsFixed(2).split('.');
      final buf = StringBuffer();
      final s2 = parts[0];
      for (int i = 0; i < s2.length; i++) {
        if (i > 0 && (s2.length - i) % 3 == 0) buf.write(',');
        buf.write(s2[i]);
      }
      return '$currencySymbol$buf.${parts[1]}';
    }

    const border4  = pw.BorderSide(color: PdfColors.grey400, width: 0.5);
    const border6  = pw.BorderSide(color: PdfColors.grey600, width: 0.8);
    const outerBox = pw.BoxDecoration(border: pw.Border(top: border6, bottom: border6, left: border6, right: border6));
    const divB     = pw.BoxDecoration(border: pw.Border(bottom: border4));

    pw.Widget tx_(String v, {pw.Font? f, double? s, PdfColor? c,
        pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Text(v, textAlign: a,
            style: pw.TextStyle(font: f ?? r, fontSize: s ?? fs, color: c));

    pw.Widget pad(pw.Widget w, [pw.EdgeInsets? e]) =>
        pw.Padding(padding: e ?? const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3), child: w);

    pw.Widget amtRow(String lbl, String val, {bool bold = false, PdfColor? vc}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            tx_(lbl, f: bold ? b : r, s: fs - 0.5, c: bold ? null : PdfColors.grey700),
            tx_(val, f: bold ? b : r, s: fs - 0.5, c: vc),
          ]),
        );

    // Items table rows
    final itemRows = tx.items.asMap().entries.map((e) {
      final item = e.value;
      return pw.TableRow(children: [
        pad(tx_('${e.key + 1}', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_(_itemLabel(item), f: b, s: fs - 1)),
        pad(tx_('—', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_('${item.quantity}', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_('—', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_(fmtAmt(item.price), a: pw.TextAlign.right, s: fs - 1)),
        pad(tx_(fmtAmt(item.total), f: b, a: pw.TextAlign.right, s: fs - 1)),
      ]);
    }).toList();

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => pw.Container(
        decoration: outerBox,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

          // ── Title ──────────────────────────────────────────────────────
          pw.Container(
            decoration: divB,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Center(child: tx_('Tax Invoice', f: b, s: fs + 2)),
          ),

          // ── Company info (left) | Invoice No. (mid) | Date (right) ────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, verticalInside: border4),
            columnWidths: const {
              0: pw.FlexColumnWidth(58),
              1: pw.FlexColumnWidth(21),
              2: pw.FlexColumnWidth(21),
            },
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(
                    width: 52, height: 52,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    ),
                    child: logoImage != null
                        ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                        : pw.Center(child: tx_('IMG', s: 7, c: PdfColors.grey500)),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    tx_(storeName.isNotEmpty ? storeName : 'Company', f: b, s: 13),
                    pw.SizedBox(height: 3),
                    if (storeAddress.isNotEmpty) tx_(storeAddress, s: fs - 1.5, c: PdfColors.grey700),
                    if (storePhone.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      tx_('Phone no.: $storePhone', s: fs - 1.5, c: PdfColors.grey700),
                    ],
                    if (storeEmail.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      tx_('Email: $storeEmail', s: fs - 1.5, c: PdfColors.grey700),
                    ],
                    if (storeGstin.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      tx_('GSTIN: $storeGstin', f: b, s: fs - 1.5),
                    ],
                  ])),
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  tx_('Invoice No.', f: b, s: fs - 1, a: pw.TextAlign.center),
                  pw.SizedBox(height: 6),
                  tx_(invoiceNo, s: fs - 1, a: pw.TextAlign.center),
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  tx_('Date', f: b, s: fs - 1, a: pw.TextAlign.center),
                  pw.SizedBox(height: 6),
                  tx_(dateStr, s: fs - 1, a: pw.TextAlign.center),
                ]),
              ),
            ])],
          ),

          // ── Bill To (left) | Ship To (right) ──────────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(50), 1: pw.FlexColumnWidth(50)},
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('Bill To', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 3),
                  tx_(tx.customerName?.isNotEmpty == true ? tx.customerName! : 'Walk-In Customer', f: b, s: fs - 0.5),
                  if (tx.customerPhone != null && tx.customerPhone!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    tx_(tx.customerPhone!, s: fs - 1.5, c: PdfColors.grey700),
                  ],
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('Ship To', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 3),
                  tx_(tx.customerName?.isNotEmpty == true ? tx.customerName! : '—', s: fs - 1.5, c: PdfColors.grey700),
                ]),
              ),
            ])],
          ),

          // ── Items table ────────────────────────────────────────────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, horizontalInside: border4, verticalInside: border4),
            columnWidths: const {
              0: pw.FixedColumnWidth(16),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FixedColumnWidth(44),
              3: pw.FixedColumnWidth(36),
              4: pw.FixedColumnWidth(28),
              5: pw.FixedColumnWidth(64),
              6: pw.FixedColumnWidth(60),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  for (final h in [
                    ('#',             pw.TextAlign.center),
                    ('Item name',     pw.TextAlign.left),
                    ('HSN/SAC',       pw.TextAlign.center),
                    ('Qty',           pw.TextAlign.center),
                    ('Unit',          pw.TextAlign.center),
                    ('Price/Unit',    pw.TextAlign.right),
                    ('Amount',        pw.TextAlign.right),
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: tx_(h.$1, f: b, s: fs - 2.5, a: h.$2),
                    ),
                ],
              ),
              ...itemRows,
              // TOTAL row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.SizedBox(),
                  pad(tx_('Total', f: b, s: fs - 1)),
                  pw.SizedBox(),
                  pad(tx_('$totalQty', f: b, a: pw.TextAlign.center, s: fs - 1)),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  pad(tx_(fmtAmt(tx.total), f: b, a: pw.TextAlign.right, s: fs - 1)),
                ],
              ),
            ],
          ),

          // ── Invoice in Words + payment (left) | Amounts (right) ────────
          pw.Table(
            border: const pw.TableBorder(bottom: border4, verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('Invoice Amount in Words', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 4),
                  tx_(_numberToWords(tx.total), s: fs - 1.5, c: PdfColors.grey700),
                  pw.SizedBox(height: 8),
                  tx_('Payment mode', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 3),
                  tx_(tx.paymentMethod.isNotEmpty
                      ? '${tx.paymentMethod[0].toUpperCase()}${tx.paymentMethod.substring(1)}'
                      : '—',
                      s: fs - 1, c: PdfColors.grey700),
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                  amtRow('Sub Total', fmtAmt(tx.subtotal)),
                  if (tx.discountAmount > 0)
                    amtRow('Discount', '-${fmtAmt(tx.discountAmount)}', vc: PdfColors.green800),
                  if (tx.taxAmount > 0)
                    amtRow('$taxLabel ($taxRate%)', fmtAmt(tx.taxAmount)),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  amtRow('Total', fmtAmt(tx.total), bold: true),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  amtRow('Received', fmtAmt(tx.total)),
                  amtRow('Balance', fmtAmt(0.0)),
                ]),
              ),
            ])],
          ),

          // ── Terms & Conditions ─────────────────────────────────────────
          pw.Container(
            decoration: divB,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              tx_('Terms and conditions', f: b, s: fs - 0.5),
              pw.SizedBox(height: 3),
              tx_(storeTerms.isNotEmpty ? storeTerms : receiptFooter.isNotEmpty ? receiptFooter : 'Thanks for doing business with us!',
                  s: fs - 1.5, c: PdfColors.grey600),
            ]),
          ),

          // ── For: StoreName (left) | Authorized Signatory (right) ───────
          pw.Table(
            border: const pw.TableBorder(verticalInside: border4),
            columnWidths: const {0: pw.FlexColumnWidth(55), 1: pw.FlexColumnWidth(45)},
            children: [pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  tx_('For : ${storeName.isNotEmpty ? storeName : "Company"}', f: b, s: fs - 0.5),
                  pw.SizedBox(height: 32),
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  pw.SizedBox(height: 28),
                  pw.Center(child: tx_('Authorized Signatory', f: b, s: fs - 0.5, c: PdfColors.grey700)),
                  pw.SizedBox(height: 8),
                ]),
              ),
            ])],
          ),

        ]),
      ),
    ));
    return doc.save();
  }

  // ── Simple / Jhon-Company style modern invoice ────────────────────────────
  static Future<Uint8List> _buildSimplePdf(
    TransactionRecord tx, {
    required String storeName,
    required String storeAddress,
    String storePhone = '',
    String storeEmail = '',
    String storeGstin = '',
    required String receiptFooter,
    required String taxLabel,
    required String taxRate,
    required String currencySymbol,
    String storeTerms = '',
    String logoPath = '',
    String docType = 'Invoice',
  }) async {
    await preWarm();
    final r = _regular!;
    final b = _bold!;

    pw.ImageProvider? logoImage;
    if (logoPath.isNotEmpty) {
      try {
        final bytes = await File(logoPath).readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    const double fs = 8.5;
    final invoiceNo = tx.id.substring(0, 6).toUpperCase();
    final dateStr   = '${tx.createdAt.day.toString().padLeft(2, '0')}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.year}';

    // Long date: DD MMMM YYYY
    const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final longDate = '${tx.createdAt.day.toString().padLeft(2,'0')} ${monthNames[tx.createdAt.month - 1]} ${tx.createdAt.year}';

    String fmtAmt(double v) {
      final parts = v.toStringAsFixed(2).split('.');
      final buf = StringBuffer();
      final s2 = parts[0];
      for (int i = 0; i < s2.length; i++) {
        if (i > 0 && (s2.length - i) % 3 == 0) buf.write(',');
        buf.write(s2[i]);
      }
      return '$currencySymbol$buf.${parts[1]}';
    }

    const darkColor = PdfColor.fromInt(0xFF1A1A2E);

    pw.Widget tx_(String v, {pw.Font? f, double? s, PdfColor? c,
        pw.TextAlign a = pw.TextAlign.left}) =>
        pw.Text(v, textAlign: a,
            style: pw.TextStyle(font: f ?? r, fontSize: s ?? fs, color: c));

    pw.Widget pad(pw.Widget w, [pw.EdgeInsets? e]) =>
        pw.Padding(padding: e ?? const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: w);

    pw.Widget summaryRow(String lbl, String val, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            tx_(lbl, f: bold ? b : r, s: fs - 0.5, c: bold ? darkColor : PdfColors.grey700),
            tx_(val, f: bold ? b : r, s: fs - 0.5, c: bold ? darkColor : null),
          ]),
        );

    // Items rows
    final itemRows = tx.items.asMap().entries.map((e) {
      final item = e.value;
      return pw.TableRow(children: [
        pad(tx_('${e.key + 1}', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_(_itemLabel(item), s: fs - 1)),
        pad(tx_(fmtAmt(item.price), a: pw.TextAlign.right, s: fs - 1)),
        pad(tx_('${item.quantity}', a: pw.TextAlign.center, s: fs - 1)),
        pad(tx_(fmtAmt(item.total), f: b, a: pw.TextAlign.right, s: fs - 1)),
      ]);
    }).toList();

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

        // ── 1. Top header: logo + company | INVOICE label ──────────────
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          // Logo box
          pw.Container(
            width: 48, height: 48,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: logoImage != null
                ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                : pw.Center(child: tx_('IMG', s: 7, c: PdfColors.grey500)),
          ),
          pw.SizedBox(width: 10),
          // Company details
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            tx_(storeName.isNotEmpty ? storeName : 'Company', f: b, s: fs + 5),
            pw.SizedBox(height: 3),
            if (storeAddress.isNotEmpty) tx_(storeAddress, s: fs - 1.5, c: PdfColors.grey600),
            pw.Row(children: [
              if (storePhone.isNotEmpty) ...[
                tx_(storePhone, s: fs - 1.5, c: PdfColors.grey600),
                if (storeEmail.isNotEmpty) tx_('  |  ', s: fs - 1.5, c: PdfColors.grey500),
              ],
              if (storeEmail.isNotEmpty) tx_(storeEmail, s: fs - 1.5, c: PdfColors.grey600),
            ]),
          ])),
          // INVOICE label + date
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            tx_(docType.toUpperCase(), f: b, s: fs + 12, c: darkColor),
            pw.SizedBox(height: 4),
            tx_('DATE. $dateStr', s: fs - 1, c: PdfColors.grey600),
          ]),
        ]),

        pw.SizedBox(height: 12),
        pw.Divider(color: darkColor, thickness: 1.0),
        pw.SizedBox(height: 8),

        // ── 2. INVOICE TO | SHIP TO ───────────────────────────────────
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
          children: [pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                tx_('INVOICE TO', f: b, s: fs - 2, c: PdfColors.grey600),
                pw.SizedBox(height: 4),
                tx_(tx.customerName?.isNotEmpty == true ? tx.customerName! : 'Walk-In Customer',
                    f: b, s: fs + 0.5),
                if (storeAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  tx_(storeAddress, s: fs - 1.5, c: PdfColors.grey600),
                ],
                if (tx.customerPhone?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 2),
                  tx_(tx.customerPhone!, s: fs - 1.5, c: PdfColors.grey600),
                ],
              ]),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                tx_('SHIP TO', f: b, s: fs - 2, c: PdfColors.grey600),
                pw.SizedBox(height: 4),
                tx_(tx.customerName?.isNotEmpty == true ? tx.customerName! : 'Walk-In Customer',
                    f: b, s: fs + 0.5),
                if (storeAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  tx_(storeAddress, s: fs - 1.5, c: PdfColors.grey600),
                ],
                if (tx.customerPhone?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 2),
                  tx_(tx.customerPhone!, s: fs - 1.5, c: PdfColors.grey600),
                ],
              ]),
            ),
          ])],
        ),

        pw.SizedBox(height: 10),

        // ── 3. DATE left | INVOICE NO right ───────────────────────────
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          tx_('DATE: $longDate', s: fs - 0.5, c: PdfColors.grey700),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'INVOICE NO: ', style: pw.TextStyle(font: r, fontSize: fs - 0.5, color: PdfColors.grey700)),
            pw.TextSpan(text: invoiceNo, style: pw.TextStyle(font: b, fontSize: fs - 0.5)),
          ])),
        ]),

        pw.SizedBox(height: 4),
        pw.Divider(color: darkColor, thickness: 1.0),

        // ── 4. Items table header ──────────────────────────────────────
        pw.Table(
          columnWidths: const {
            0: pw.FixedColumnWidth(20),
            1: pw.FlexColumnWidth(4),
            2: pw.FixedColumnWidth(70),
            3: pw.FixedColumnWidth(56),
            4: pw.FixedColumnWidth(66),
          },
          children: [
            pw.TableRow(children: [
              for (final h in [
                ('NO',       pw.TextAlign.center),
                ('ITEM DESCRIPTION', pw.TextAlign.left),
                ('PRICE',    pw.TextAlign.right),
                ('QUANTITY', pw.TextAlign.center),
                ('TOTAL',    pw.TextAlign.right),
              ])
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  child: tx_(h.$1, f: b, s: fs - 1.5, a: h.$2),
                ),
            ]),
          ],
        ),

        pw.Divider(color: darkColor, thickness: 0.8),

        // Items
        pw.Table(
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.3)),
          columnWidths: const {
            0: pw.FixedColumnWidth(20),
            1: pw.FlexColumnWidth(4),
            2: pw.FixedColumnWidth(70),
            3: pw.FixedColumnWidth(56),
            4: pw.FixedColumnWidth(66),
          },
          children: itemRows,
        ),

        pw.Divider(color: darkColor, thickness: 0.8),

        pw.SizedBox(height: 6),

        // ── 5. TOTAL DUE (left) | Summary (right) ─────────────────────
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            tx_('TOTAL DUE', f: b, s: fs - 0.5, c: PdfColors.grey600),
            pw.SizedBox(height: 3),
            tx_(fmtAmt(tx.total), f: b, s: fs + 7, c: darkColor),
          ])),
          pw.SizedBox(width: 16),
          pw.SizedBox(
            width: 180,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              summaryRow('SUBTOTAL:', fmtAmt(tx.subtotal)),
              if (tx.discountAmount > 0)
                summaryRow('DISCOUNT:', '-${fmtAmt(tx.discountAmount)}'),
              if (tx.taxAmount > 0)
                summaryRow('TAX ($taxRate%):', fmtAmt(tx.taxAmount)),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              summaryRow('GRAND TOTAL:', fmtAmt(tx.total), bold: true),
            ]),
          ),
        ]),

        pw.SizedBox(height: 12),
        pw.Divider(color: darkColor, thickness: 1.0),
        pw.SizedBox(height: 8),

        // ── 6. Payment Info | Terms | For: StoreName ──────────────────
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            tx_('Payment Info:', f: b, s: fs - 0.5),
            pw.SizedBox(height: 4),
            if (storeName.isNotEmpty) tx_(storeName, s: fs - 1, c: PdfColors.grey700),
            if (storePhone.isNotEmpty) tx_(storePhone, s: fs - 1, c: PdfColors.grey700),
            if (storeEmail.isNotEmpty) tx_(storeEmail, s: fs - 1, c: PdfColors.grey700),
          ])),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            tx_('Terms & Conditions:', f: b, s: fs - 0.5),
            pw.SizedBox(height: 4),
            tx_(storeTerms.isNotEmpty ? storeTerms : receiptFooter.isNotEmpty ? receiptFooter : 'Thanks for doing business with us!',
                s: fs - 1.5, c: PdfColors.grey600),
          ])),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            tx_('For: ${storeName.isNotEmpty ? storeName : "Company"}', f: b, s: fs - 0.5),
            pw.SizedBox(height: 36),
            pw.Center(child: tx_('Authorized Signatory', s: fs - 1.5, c: PdfColors.grey600)),
          ])),
        ]),

        pw.SizedBox(height: 8),
        pw.Divider(color: darkColor, thickness: 1.0),
        pw.SizedBox(height: 6),

        // ── 7. Bottom bar: address | phone | email ────────────────────
        pw.Center(
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            if (storeAddress.isNotEmpty) tx_(storeAddress, s: fs - 2, c: PdfColors.grey600),
            if (storeAddress.isNotEmpty && (storePhone.isNotEmpty || storeEmail.isNotEmpty))
              tx_('   |   ', s: fs - 2, c: PdfColors.grey500),
            if (storePhone.isNotEmpty) tx_(storePhone, s: fs - 2, c: PdfColors.grey600),
            if (storePhone.isNotEmpty && storeEmail.isNotEmpty)
              tx_('   |   ', s: fs - 2, c: PdfColors.grey500),
            if (storeEmail.isNotEmpty) tx_(storeEmail, s: fs - 2, c: PdfColors.grey600),
          ]),
        ),

      ]),
    ));
    return doc.save();
  }
}
