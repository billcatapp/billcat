import 'dart:convert';
import 'dart:io';

/// Raw label-printer command language. Covers the vast majority of thermal
/// barcode printers: TSPL for GODEX / TSC / TVS-LP, ZPL for Zebra.
enum LabelLanguage { tspl, zpl }

/// How labels are delivered to the printer.
/// [pdf] uses the OS print system (the fallback path). [network] sends raw
/// TSPL/ZPL bytes over TCP :9100. [usb] sends raw bytes to a USB printer via
/// the CUPS queue with `lp -o raw`, which bypasses the (often wrong/missing)
/// driver entirely — the reliable path for USB GODEX/TSC/TVS on macOS.
enum LabelTransport { pdf, network, usb }

extension LabelLanguageX on LabelLanguage {
  String get label => this == LabelLanguage.zpl ? 'ZPL (Zebra)' : 'TSPL (GODEX / TSC / TVS)';
  String get code => this == LabelLanguage.zpl ? 'zpl' : 'tspl';
  static LabelLanguage fromCode(String? c) =>
      c == 'zpl' ? LabelLanguage.zpl : LabelLanguage.tspl;
}

/// Per-device printer configuration. Stored locally (never synced to the cloud)
/// so each machine keeps its own printer/IP without clashing with other devices
/// on the same account.
class LabelPrinterProfile {
  final LabelTransport transport;
  final LabelLanguage language;
  final String host; // IP / hostname for network printers
  final int port; // raw port, almost always 9100
  final int dpi; // 203 (common) or 300
  final String queue; // CUPS queue name for USB printers (e.g. GODEX_G500)

  const LabelPrinterProfile({
    this.transport = LabelTransport.pdf,
    this.language = LabelLanguage.tspl,
    this.host = '',
    this.port = 9100,
    this.dpi = 203,
    this.queue = '',
  });

  bool get isNetwork => transport == LabelTransport.network && host.trim().isNotEmpty;
  bool get isUsb => transport == LabelTransport.usb && queue.trim().isNotEmpty;
  bool get isRaw => isNetwork || isUsb;

  LabelPrinterProfile copyWith({
    LabelTransport? transport,
    LabelLanguage? language,
    String? host,
    int? port,
    int? dpi,
    String? queue,
  }) =>
      LabelPrinterProfile(
        transport: transport ?? this.transport,
        language: language ?? this.language,
        host: host ?? this.host,
        port: port ?? this.port,
        dpi: dpi ?? this.dpi,
        queue: queue ?? this.queue,
      );

  static String _t(LabelTransport t) => switch (t) {
        LabelTransport.network => 'network',
        LabelTransport.usb => 'usb',
        LabelTransport.pdf => 'pdf',
      };

  Map<String, dynamic> toJson() => {
        'transport': _t(transport),
        'language': language.code,
        'host': host,
        'port': port,
        'dpi': dpi,
        'queue': queue,
      };

  static LabelPrinterProfile fromJson(Map<String, dynamic> m) => LabelPrinterProfile(
        transport: switch (m['transport']) {
          'network' => LabelTransport.network,
          'usb' => LabelTransport.usb,
          _ => LabelTransport.pdf,
        },
        language: LabelLanguageX.fromCode(m['language'] as String?),
        host: (m['host'] as String?) ?? '',
        port: (m['port'] as num?)?.toInt() ?? 9100,
        dpi: (m['dpi'] as num?)?.toInt() ?? 203,
        queue: (m['queue'] as String?) ?? '',
      );
}

/// Physical label geometry, in millimetres.
class LabelSpec {
  final double labelWmm; // one label width
  final double labelHmm; // one label height
  final int columns; // labels across the liner (Per Row)
  final double gapMm; // vertical gap between label rows

  const LabelSpec({
    required this.labelWmm,
    required this.labelHmm,
    this.columns = 1,
    this.gapMm = 2.0,
  });

  double get fullWidthMm => labelWmm * columns;
}

/// A product to encode onto labels.
class LabelItem {
  final String barcodeValue;
  final String name;
  final String price;
  final int count;

  const LabelItem({
    required this.barcodeValue,
    required this.name,
    required this.price,
    this.count = 1,
  });
}

class LabelPrinterService {
  // ── Device-local persistence ────────────────────────────────────────────
  static Future<String> _configDir() async {
    String base;
    if (Platform.isWindows) {
      base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    } else {
      final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
      base = '$home/Library/Application Support';
    }
    final dir = Directory('$base/BillCat');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  static Future<File> _profileFile() async =>
      File('${await _configDir()}/label_printer.json');

  static LabelPrinterProfile _cached = const LabelPrinterProfile();
  static LabelPrinterProfile get cached => _cached;

  static Future<LabelPrinterProfile> load() async {
    try {
      final f = await _profileFile();
      if (await f.exists()) {
        final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _cached = LabelPrinterProfile.fromJson(map);
      }
    } catch (_) {}
    return _cached;
  }

  static Future<void> save(LabelPrinterProfile p) async {
    _cached = p;
    try {
      final f = await _profileFile();
      await f.writeAsString(jsonEncode(p.toJson()));
    } catch (_) {}
  }

  // ── Device-local barcode settings (printer name, label size, per-row) ──────
  // Kept out of the synced cloud settings so each machine remembers its OWN
  // printer/label stock without clashing with other devices on the account.
  static Future<File> _barcodeFile() async =>
      File('${await _configDir()}/barcode_settings.json');

  static Map<String, dynamic> _barcode = {};
  static Map<String, dynamic> get barcodeSettings => _barcode;

  static Future<Map<String, dynamic>> loadBarcodeSettings() async {
    try {
      final f = await _barcodeFile();
      if (await f.exists()) {
        _barcode = (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    return _barcode;
  }

  static Future<void> saveBarcodeSettings(Map<String, dynamic> patch) async {
    _barcode = {..._barcode, ...patch};
    try {
      final f = await _barcodeFile();
      await f.writeAsString(jsonEncode(_barcode));
    } catch (_) {}
  }

  // ── Command generation ──────────────────────────────────────────────────
  static int _dots(double mm, int dpi) => (mm * dpi / 25.4).round();

  /// Sanitise text for a raw label command (ASCII only, no quotes/control).
  static String _clean(String s) => s
      .replaceAll('"', ' ')
      .replaceAll('^', ' ')
      .replaceAll('~', '-')
      .replaceAll(RegExp(r'[\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'[^\x20-\x7e]'), '')
      .trim();

  /// Flatten items into a single list honouring each item's [count].
  static List<LabelItem> _flatten(List<LabelItem> items) {
    final out = <LabelItem>[];
    for (final it in items) {
      final n = it.count < 1 ? 1 : it.count;
      for (var i = 0; i < n; i++) out.add(it);
    }
    return out;
  }

  /// True for values printable as native EAN-13 (the app's generated
  /// product barcodes): exactly 12 or 13 digits. EAN-13 has a FIXED width
  /// of 95 modules, so its printed size is exact — never estimated.
  static bool _isEan13(String value) => RegExp(r'^\d{12,13}$').hasMatch(value);

  static const int _ean13Modules = 95;

  /// Approximate printed width of a Code 128 barcode in dots. Conservative
  /// per-character estimate — printer firmwares differ in how they pack
  /// digits, so never assume subset-C compression.
  static int _code128Dots(String value, int narrow) =>
      (11 * value.length + 35) * narrow;

  /// Largest narrow-module width (3 → 2 → 1) whose barcode fits [availDots]:
  /// the boldest bars the sticker allows. 1 dot (0.125mm at 203dpi) is the
  /// readable minimum for direct thermal.
  static int _fitNarrow(String value, int availDots) {
    for (var n = 3; n > 1; n--) {
      if (_code128Dots(value, n) <= availDots) return n;
    }
    return 1;
  }

  static String buildTspl(List<LabelItem> items, LabelSpec spec, int dpi) {
    final flat = _flatten(items);
    final b = StringBuffer();
    // Stickers sit side by side with the same gap BETWEEN columns as between
    // rows: the column pitch must include it, or every sticker off-center
    // drifts a little more (only the middle one looks aligned).
    final fullW =
        (spec.labelWmm * spec.columns + spec.gapMm * (spec.columns - 1))
            .toStringAsFixed(1);
    final labelH = spec.labelHmm.toStringAsFixed(1);
    final gap = spec.gapMm.toStringAsFixed(1);

    final colWDots = _dots(spec.labelWmm, dpi);
    final colPitch = _dots(spec.labelWmm + spec.gapMm, dpi);
    final margin = _dots(2.0, dpi); // quiet zone kept clear on BOTH sides
    final availW = colWDots - margin * 2;
    final barH = _dots(spec.labelHmm * 0.55, dpi).clamp(20, 100000);
    // Center the whole block (barcode + two text lines) vertically so the
    // top and bottom margins match — "placed perfect" on every sticker.
    final labelHDots = _dots(spec.labelHmm, dpi);
    final lineGap = _dots(1.0, dpi);
    final priceDrop = (dpi ~/ 12) + 14;
    const textH = 24; // TSPL font "1" line height incl. breathing room
    final contentH = barH + lineGap + priceDrop + textH;
    final yBar = ((labelHDots - contentH) ~/ 2).clamp(_dots(1.0, dpi), labelHDots);
    final yName = yBar + barH + lineGap;
    final yPrice = yName + priceDrop;
    const charW = 8; // TSPL font "1" character width in dots

    b.writeln('SIZE $fullW mm,$labelH mm');
    b.writeln('GAP $gap mm,0 mm');
    b.writeln('DIRECTION 1');
    b.writeln('CLS');

    for (var start = 0; start < flat.length; start += spec.columns) {
      b.writeln('CLS');
      final end = (start + spec.columns).clamp(0, flat.length);
      for (var i = start; i < end; i++) {
        final it = flat[i];
        final colStart = (i - start) * colPitch;
        final val = _clean(it.barcodeValue);
        if (val.isEmpty) continue;
        // Auto-fit: pick the boldest bars that keep the barcode inside its
        // own sticker, then center it — bars must never cross a neighbour.
        // EAN-13 values use the native type: exactly 95 modules wide, so
        // the printed width is known, not estimated.
        if (_isEan13(val)) {
          final v12 = val.substring(0, 12); // printer computes check digit
          var narrow = 3;
          while (narrow > 1 && _ean13Modules * narrow > availW) narrow--;
          final barW = _ean13Modules * narrow;
          final xBar =
              colStart + ((colWDots - barW) ~/ 2).clamp(margin, colWDots);
          b.writeln(
              'BARCODE $xBar,$yBar,"EAN13",$barH,0,0,$narrow,$narrow,"$v12"');
        } else {
          final narrow = _fitNarrow(val, availW);
          final barW = _code128Dots(val, narrow);
          final xBar =
              colStart + ((colWDots - barW) ~/ 2).clamp(margin, colWDots);
          // BARCODE x,y,"type",height,human,rotation,narrow,wide,"content"
          b.writeln(
              'BARCODE $xBar,$yBar,"128",$barH,0,0,$narrow,$narrow,"$val"');
        }
        final maxChars = availW ~/ charW;
        final name = _truncate(_clean(it.name), maxChars);
        final price = _truncate(_clean(it.price), maxChars);
        if (name.isNotEmpty) {
          final xn = colStart +
              ((colWDots - name.length * charW) ~/ 2).clamp(margin, colWDots);
          b.writeln('TEXT $xn,$yName,"1",0,1,1,"$name"');
        }
        if (price.isNotEmpty) {
          final xp = colStart +
              ((colWDots - price.length * charW) ~/ 2).clamp(margin, colWDots);
          b.writeln('TEXT $xp,$yPrice,"1",0,1,1,"$price"');
        }
      }
      b.writeln('PRINT 1,1');
    }
    return b.toString();
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max < 0 ? 0 : max);

  static String buildZpl(List<LabelItem> items, LabelSpec spec, int dpi) {
    final flat = _flatten(items);
    final b = StringBuffer();
    final fullWDots = _dots(
        spec.labelWmm * spec.columns + spec.gapMm * (spec.columns - 1), dpi);
    final labelHDots = _dots(spec.labelHmm, dpi);
    final colWDots = _dots(spec.labelWmm, dpi);
    final colPitch = _dots(spec.labelWmm + spec.gapMm, dpi);
    final padX = _dots(2.0, dpi);
    final barH = _dots(spec.labelHmm * 0.55, dpi).clamp(20, 100000);
    // Vertically centered content block, matching the TSPL builder.
    final lineGap = _dots(1.0, dpi);
    const zplTextH = 22;
    final contentH = barH + lineGap + 22 + zplTextH;
    final yBar =
        ((labelHDots - contentH) ~/ 2).clamp(_dots(1.0, dpi), labelHDots);
    final yName = yBar + barH + lineGap;
    final yPrice = yName + 22;

    final margin = padX;
    final availW = colWDots - margin * 2;
    const zplCharW = 10; // ^A0N,18,18 approx character width in dots

    for (var start = 0; start < flat.length; start += spec.columns) {
      b.writeln('^XA');
      b.writeln('^PW$fullWDots');
      b.writeln('^LL$labelHDots');
      final end = (start + spec.columns).clamp(0, flat.length);
      for (var i = start; i < end; i++) {
        final it = flat[i];
        final colStart = (i - start) * colPitch;
        final val = _clean(it.barcodeValue);
        if (val.isEmpty) continue;
        if (_isEan13(val)) {
          final v12 = val.substring(0, 12); // printer computes check digit
          var narrow = 3;
          while (narrow > 1 && _ean13Modules * narrow > availW) narrow--;
          final barW = _ean13Modules * narrow;
          final xBar =
              colStart + ((colWDots - barW) ~/ 2).clamp(margin, colWDots);
          b.writeln('^FO$xBar,$yBar^BY$narrow^BEN,$barH,N,N^FD$v12^FS');
        } else {
          final narrow = _fitNarrow(val, availW);
          final barW = _code128Dots(val, narrow);
          final xBar =
              colStart + ((colWDots - barW) ~/ 2).clamp(margin, colWDots);
          b.writeln('^FO$xBar,$yBar^BY$narrow^BCN,$barH,N,N,N^FD$val^FS');
        }
        final maxChars = availW ~/ zplCharW;
        final name = _truncate(_clean(it.name), maxChars);
        final price = _truncate(_clean(it.price), maxChars);
        if (name.isNotEmpty) {
          final xn = colStart +
              ((colWDots - name.length * zplCharW) ~/ 2).clamp(margin, colWDots);
          b.writeln('^FO$xn,$yName^A0N,18,18^FD$name^FS');
        }
        if (price.isNotEmpty) {
          final xp = colStart +
              ((colWDots - price.length * zplCharW) ~/ 2).clamp(margin, colWDots);
          b.writeln('^FO$xp,$yPrice^A0N,18,18^FD$price^FS');
        }
      }
      b.writeln('^XZ');
    }
    return b.toString();
  }

  static String buildCommands(List<LabelItem> items, LabelSpec spec, LabelPrinterProfile p) =>
      p.language == LabelLanguage.zpl
          ? buildZpl(items, spec, p.dpi)
          : buildTspl(items, spec, p.dpi);

  // ── Transport ───────────────────────────────────────────────────────────
  /// Sends raw bytes to a network printer over TCP. One automatic retry on a
  /// transient failure; hard timeout so a wedged printer can't hang the UI.
  /// Throws on failure so the caller can surface the error.
  static Future<void> sendRawNetwork(String data, LabelPrinterProfile p) async {
    Future<void> attempt() async {
      final socket = await Socket.connect(
        p.host.trim(),
        p.port,
        timeout: const Duration(seconds: 6),
      );
      try {
        socket.add(latin1.encode(data));
        await socket.flush().timeout(const Duration(seconds: 10));
      } finally {
        await socket.close();
        socket.destroy();
      }
    }

    try {
      await attempt();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 600));
      await attempt(); // second failure propagates to the caller
    }
  }

  /// Resolves a saved printer/queue name to the CUPS queue that actually
  /// exists. CUPS mangles names (prefixes, suffixes, dropped punctuation),
  /// so match ignoring case and non-alphanumerics; fall back to the saved
  /// string so an exact name still works even if lpstat is unavailable.
  static Future<String> _resolveQueue(String saved) async {
    final queues = await listQueues();
    if (queues.isEmpty) return saved;
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final want = norm(saved);
    if (want.isEmpty) return saved;
    for (final q in queues) {
      if (norm(q) == want) return q;
    }
    for (final q in queues) {
      final nq = norm(q);
      if (nq.isEmpty) continue;
      if (nq.contains(want) || want.contains(nq)) return q;
    }
    return saved;
  }

  /// Sends raw bytes to a USB printer via its CUPS queue using `lpr -l`
  /// (literal/raw), which bypasses the queue's driver/PPD and delivers the
  /// bytes untouched. lpr, not lp: lp fails to spawn from the packaged app
  /// (same finding as receipt printing). After queueing, verifies the
  /// printer actually took the job — lpr exits 0 even when the printer is
  /// off, and a silently stuck queue is worse than an error.
  static Future<void> sendRawUsb(String data, String queue) async {
    final resolved = await _resolveQueue(queue.trim());
    final tmp = await Directory.systemTemp.createTemp('billcat_lbl_');
    final f = File('${tmp.path}/label.prn');
    await f.writeAsString(data, encoding: latin1, flush: true);
    final res = await Process.run('/usr/bin/lpr', ['-l', '-P', resolved, f.path])
        .timeout(const Duration(seconds: 15));
    try { await tmp.delete(recursive: true); } catch (_) {}
    if (res.exitCode != 0) {
      throw Exception((res.stderr as String?)?.trim().isNotEmpty == true
          ? (res.stderr as String).trim()
          : 'lpr exited with code ${res.exitCode}');
    }
    // Queued is not printed: give the transfer a moment, then check the
    // queue drained. Label jobs are tiny, so a lingering job means the
    // printer is off/unplugged (the job stays queued and prints later).
    await Future.delayed(const Duration(seconds: 3));
    try {
      final check = await Process.run('/usr/bin/lpstat', ['-o', resolved])
          .timeout(const Duration(seconds: 5));
      if ('${check.stdout}'.trim().isNotEmpty) {
        throw Exception(
            'printer "$resolved" is not responding — check its power and USB '
            'cable (the label stays queued and will print when it reconnects)');
      }
    } on Exception catch (e) {
      if (e.toString().contains('not responding')) rethrow;
      // lpstat itself failing is not proof of a print failure — let it pass.
    }
  }

  /// The CUPS queue names available on this machine (raw names, e.g. GODEX_G500).
  static Future<List<String>> listQueues() async {
    if (Platform.isWindows) return const [];
    try {
      final res = await Process.run('/usr/bin/lpstat', ['-e'])
          .timeout(const Duration(seconds: 3));
      return '${res.stdout}'.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Builds commands for [items] and sends them over the configured raw
  /// transport (network or USB). Only valid when [profile.isRaw].
  static Future<void> printBatch(
    List<LabelItem> items,
    LabelSpec spec,
    LabelPrinterProfile profile,
  ) async {
    final data = buildCommands(items, spec, profile);
    if (profile.transport == LabelTransport.usb) {
      await sendRawUsb(data, profile.queue.trim());
    } else {
      await sendRawNetwork(data, profile);
    }
  }

  /// Sends the printer's own gap-calibration command so it re-learns the
  /// label size and gap from the loaded roll. Run after changing label stock
  /// — fixes the "printing drifts off the sticker" class of problems.
  static Future<void> calibrate(LabelPrinterProfile profile) async {
    final cmd = profile.language == LabelLanguage.zpl
        ? '~JC\n'
        : 'GAPDETECT\n';
    if (profile.transport == LabelTransport.usb) {
      await sendRawUsb(cmd, profile.queue.trim());
    } else {
      await sendRawNetwork(cmd, profile);
    }
  }

  /// Prints one probe label in EACH language, regardless of the configured
  /// one. Only the language the printer really speaks produces a scannable
  /// barcode (whose content is that language's code), so scanning whichever
  /// label printed cleanly identifies the right setting — the "select
  /// language by scanning" setup flow.
  static Future<void> printLanguageProbes(
    LabelSpec spec,
    LabelPrinterProfile profile,
  ) async {
    final single = LabelSpec(
      labelWmm: spec.labelWmm,
      labelHmm: spec.labelHmm,
      columns: 1,
      gapMm: spec.gapMm,
    );
    for (final lang in LabelLanguage.values) {
      final item = LabelItem(
        barcodeValue: lang.code.toUpperCase(),
        name: 'BillCat printer setup',
        price: 'Scan this barcode',
        count: 1,
      );
      final data = lang == LabelLanguage.zpl
          ? buildZpl([item], single, profile.dpi)
          : buildTspl([item], single, profile.dpi);
      if (profile.transport == LabelTransport.usb) {
        await sendRawUsb(data, profile.queue.trim());
      } else {
        await sendRawNetwork(data, profile);
      }
    }
  }

  /// A single calibration label so users can confirm size/alignment.
  static Future<void> printTestLabel(LabelSpec spec, LabelPrinterProfile profile) async {
    final item = LabelItem(
      barcodeValue: 'BILLCAT123',
      name: 'BillCat Test',
      price: 'OK',
      count: 1,
    );
    // Force a single label for the test regardless of columns.
    final testSpec = LabelSpec(
      labelWmm: spec.labelWmm,
      labelHmm: spec.labelHmm,
      columns: 1,
      gapMm: spec.gapMm,
    );
    await printBatch([item], testSpec, profile);
  }
}
