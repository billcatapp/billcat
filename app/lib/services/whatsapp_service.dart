import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class WhatsAppService {
  final String phoneNumberId;
  final String accessToken;

  /// Meta's own error text from the last failed call. Kept so a failure can say
  /// WHY — "send failed" alone gives the shopkeeper nothing to act on.
  String? lastError;

  // Without these a half-open connection never resolves: the send Future hangs
  // forever, no success or failure toast ever fires, and the bill is silently
  // lost while the counter moves on. Upload gets longer — the PDF is bigger.
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _uploadTimeout = Duration(seconds: 45);
  static const Duration _sendTimeout = Duration(seconds: 30);

  WhatsAppService({required this.phoneNumberId, required this.accessToken});

  /// Pulls the human-readable message out of a Graph API error body.
  static String _describe(int status, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final err = json['error'] as Map<String, dynamic>?;
      if (err != null) {
        final msg = (err['message'] ?? '').toString();
        final detail = (err['error_data'] is Map)
            ? ((err['error_data'] as Map)['details'] ?? '').toString()
            : '';
        final code = err['code']?.toString() ?? '$status';
        return detail.isNotEmpty ? '[$code] $detail' : '[$code] $msg';
      }
    } catch (_) {}
    return 'HTTP $status: ${body.length > 200 ? body.substring(0, 200) : body}';
  }

  static String _normalize(String phone) {
    // Strip spaces, dashes, parens; ensure starts with country code digits only
    String p = phone.replaceAll(RegExp(r'[\s\-().+]'), '');
    if (p.startsWith('0')) p = p.substring(1); // drop leading 0
    return p;
  }

  // Upload PDF bytes as a WhatsApp media object; returns media_id or null
  Future<String?> uploadPdf(Uint8List pdfBytes, String filename) async {
    final uri = Uri.parse(
        'https://graph.facebook.com/v19.0/$phoneNumberId/media');

    final boundary = 'BillCatBoundary${DateTime.now().millisecondsSinceEpoch}';
    final body = StringBuffer();
    body.write('--$boundary\r\n');
    body.write('Content-Disposition: form-data; name="messaging_product"\r\n\r\nwhatsapp\r\n');
    body.write('--$boundary\r\n');
    body.write('Content-Disposition: form-data; name="type"\r\n\r\napplication/pdf\r\n');
    body.write('--$boundary\r\n');
    body.write(
        'Content-Disposition: form-data; name="file"; filename="$filename"\r\n');
    body.write('Content-Type: application/pdf\r\n\r\n');

    final headerBytes = utf8.encode(body.toString());
    final footer = utf8.encode('\r\n--$boundary--\r\n');
    final multipart = Uint8List(headerBytes.length + pdfBytes.length + footer.length);
    multipart.setRange(0, headerBytes.length, headerBytes);
    multipart.setRange(headerBytes.length, headerBytes.length + pdfBytes.length, pdfBytes);
    multipart.setRange(headerBytes.length + pdfBytes.length, multipart.length, footer);

    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final req = await client.postUrl(uri);
      req.headers.set('Authorization', 'Bearer $accessToken');
      req.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');
      req.headers.contentLength = multipart.length;
      req.add(multipart);
      final res = await req.close().timeout(_uploadTimeout);
      final respStr =
          await res.transform(utf8.decoder).join().timeout(_uploadTimeout);
      // Status FIRST: a proxy or captive portal answers with HTML, and parsing
      // that threw a Dart error that hid the real HTTP failure.
      if (res.statusCode != 200) {
        lastError = 'PDF upload — ${_describe(res.statusCode, respStr)}';
        return null;
      }
      final decoded = jsonDecode(respStr);
      if (decoded is Map<String, dynamic> && decoded['id'] is String) {
        return decoded['id'] as String;
      }
      lastError = 'PDF upload — no media id in reply: '
          '${respStr.length > 200 ? respStr.substring(0, 200) : respStr}';
      return null;
    } on TimeoutException {
      lastError = 'PDF upload timed out — check the internet connection';
      return null;
    } catch (e) {
      lastError = 'PDF upload — $e';
      return null;
    } finally {
      // force: a hung socket must actually be torn down, not pooled.
      client.close(force: true);
    }
  }

  // Send a PDF document message to a phone number
  Future<bool> sendInvoicePdf({
    required String toPhone,
    required Uint8List pdfBytes,
    required String invoiceNo,
    required String storeName,
    String customerName = '',
    String amount = '',
    String date = '',
    String docType = 'Invoice',
    String invoiceLink = '',
    /// What the caption should say about payment. Empty omits the line, which
    /// is what a Quotation needs. Defaults to the previous hardcoded value so
    /// no existing caller changes behaviour.
    String paymentStatus = 'Paid',
  }) async {
    final phone = _normalize(toPhone);
    if (phone.isEmpty) return false;

    final mediaId = await uploadPdf(pdfBytes, '$docType-$invoiceNo.pdf');
    if (mediaId == null) return false;

    final name = customerName.isNotEmpty ? customerName : 'Valued Customer';
    final caption =
        'Hello $name,\n\n'
        'Thank you for choosing $storeName.\n'
        'Your e-bill for $docType #$invoiceNo has been generated successfully.\n\n'
        'Amount: $amount\n'
        'Date: $date\n'
        '${paymentStatus.isEmpty ? '' : 'Payment Status: $paymentStatus\n'}\n'
        'Please find your bill attached.\n\n'
        'For any queries, feel free to contact us.\n'
        'Thank you for your support!\n\n'
        '— $storeName'
        '${invoiceLink.isNotEmpty ? '\n\nView your bill: $invoiceLink' : ''}';

    final payload = jsonEncode({
      'messaging_product': 'whatsapp',
      'to': phone,
      'type': 'document',
      'document': {
        'id': mediaId,
        'filename': '$docType-$invoiceNo.pdf',
        'caption': caption,
      },
    });

    return await _sendMessage(payload);
  }

  // Send a template message (e.g. payment reminder)
  Future<bool> sendTemplate({
    required String toPhone,
    required String templateName,
    required String languageCode,
    List<String> bodyParams = const [],
  }) async {
    final phone = _normalize(toPhone);
    if (phone.isEmpty) return false;

    final components = <Map<String, dynamic>>[];
    if (bodyParams.isNotEmpty) {
      components.add({
        'type': 'body',
        'parameters': [
          for (final p in bodyParams) {'type': 'text', 'text': p},
        ],
      });
    }

    final payload = jsonEncode({
      'messaging_product': 'whatsapp',
      'to': phone,
      'type': 'template',
      'template': {
        'name': templateName,
        'language': {'code': languageCode},
        if (components.isNotEmpty) 'components': components,
      },
    });

    return await _sendMessage(payload);
  }

  Future<bool> _sendMessage(String jsonPayload) async {
    final uri = Uri.parse(
        'https://graph.facebook.com/v19.0/$phoneNumberId/messages');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final req = await client.postUrl(uri);
      req.headers.set('Authorization', 'Bearer $accessToken');
      // The charset is not decoration: dart:io falls back to latin1 when the
      // content type omits one, and the caption carries ₹ (U+20B9), which
      // latin1 cannot encode — the write threw before reaching Meta. Send the
      // JSON as explicit UTF-8 bytes so any currency or regional text is safe.
      req.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      final payloadBytes = utf8.encode(jsonPayload);
      req.headers.contentLength = payloadBytes.length;
      req.add(payloadBytes);
      final res = await req.close().timeout(_sendTimeout);
      final body = await res.transform(utf8.decoder).join().timeout(_sendTimeout);
      if (res.statusCode == 200) return true;
      lastError = _describe(res.statusCode, body);
      return false;
    } on TimeoutException {
      lastError = 'WhatsApp timed out — check the internet connection';
      return false;
    } catch (e) {
      lastError = '$e';
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
