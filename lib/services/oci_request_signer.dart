import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// OCI Signature Version 1 Request Signer ("HTTP Signatures" over RSA-SHA256).
///
/// Reference: https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm
class OciRequestSigner {
  final String tenancyId;
  final String userId;
  final String fingerprint;
  final String privateKeyPem;

  OciRequestSigner({
    required this.tenancyId,
    required this.userId,
    required this.fingerprint,
    required this.privateKeyPem,
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Public API — returns a map of headers to add to the outgoing request.
  // ─────────────────────────────────────────────────────────────────────────────

  /// Produces the required signed headers for an OCI REST API request.
  ///
  /// [method] — uppercase HTTP method (e.g. "POST")
  /// [url]    — the full URL string
  /// [body]   — request body bytes (for POST/PUT). Pass null for GET.
  Map<String, String> signRequest({
    required String method,
    required String url,
    Uint8List? body,
  }) {
    final uri = Uri.parse(url);
    final now = _httpDate();

    // 1. Base headers always needed
    final headers = <String, String>{
      'date': now,
      'host': uri.host,
    };

    final List<String> headersToSign = ['date', '(request-target)', 'host'];

    // 2. Body-related headers (POST/PUT only)
    if (body != null && body.isNotEmpty) {
      final sha256OfBody = base64.encode(sha256.convert(body).bytes);
      final contentLength = body.length.toString();
      headers['x-content-sha256'] = sha256OfBody;
      headers['content-length'] = contentLength;
      headers['content-type'] = 'application/json';
      headersToSign.addAll(['x-content-sha256', 'content-length', 'content-type']);
    }

    // 3. Build the signing string
    final requestTarget =
        '${method.toLowerCase()} ${_requestTargetPath(uri)}';
    final signingParts = headersToSign.map((h) {
      if (h == '(request-target)') return '(request-target): $requestTarget';
      return '$h: ${headers[h]}';
    }).join('\n');

    // 4. RSA-SHA256 sign the signing string
    final signature = _rsaSign(signingParts);

    // 5. Build the Authorization header value
    final keyId = '$tenancyId/$userId/$fingerprint';
    final signedHeaders = headersToSign.join(' ');
    headers['authorization'] =
        'Signature version="1",'
        'keyId="$keyId",'
        'algorithm="rsa-sha256",'
        'headers="$signedHeaders",'
        'signature="$signature"';

    return headers;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────────

  String _requestTargetPath(Uri uri) {
    var path = uri.path.isEmpty ? '/' : uri.path;
    if (uri.hasQuery) path = '$path?${uri.query}';
    return path;
  }

  String _httpDate() {
    final now = DateTime.now().toUtc();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = days[now.weekday - 1];
    final month = months[now.month - 1];
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$day, $d $month ${now.year} $h:$m:$s GMT';
  }

  /// Parse PEM → Extract minimal RSA keys (n, d), then sign with RSA-SHA256 PKCS1_v1_5.
  String _rsaSign(String signingString) {
    final keys = _parsePrivateKey(privateKeyPem);
    final n = keys['n']!;
    final d = keys['d']!;

    // 1. SHA-256 Hash
    final msgBytes = utf8.encode(signingString);
    final hash = sha256.convert(msgBytes).bytes;

    // 2. EMSA-PKCS1-v1_5 format (Magic prefix for SHA-256)
    final prefix = [
      0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65,
      0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20
    ];

    final t = [...prefix, ...hash];

    final emLen = (n.bitLength + 7) ~/ 8;
    if (emLen < t.length + 11) {
      throw Exception("RSA Key too short for SHA-256");
    }

    // 3. Construct payload block
    final psLen = emLen - t.length - 3;
    final em = Uint8List(emLen);
    em[0] = 0x00;
    em[1] = 0x01;
    for (int i = 0; i < psLen; i++) {
      em[2 + i] = 0xFF;
    }
    em[2 + psLen] = 0x00;
    em.setAll(3 + psLen, t);

    // 4. Convert EM to BigInt
    BigInt m = BigInt.zero;
    for (var b in em) {
      m = (m << 8) | BigInt.from(b);
    }

    // 5. RSA Textbook Core Signature (M^d mod n)
    final s = m.modPow(d, n);

    // 6. Convert S (BigInt) to Bytes
    final sigBytes = Uint8List(emLen);
    final sStr = s.toRadixString(16).padLeft(emLen * 2, '0');
    for (int i = 0; i < emLen; i++) {
      sigBytes[i] = int.parse(sStr.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return base64.encode(sigBytes);
  }

  Map<String, BigInt> _parsePrivateKey(String pem) {
    final stripped = pem
        .replaceAll(RegExp(r'-----BEGIN.*?-----'), '')
        .replaceAll(RegExp(r'-----END.*?-----'), '')
        .replaceAll(RegExp(r'\s+'), '');
    final der = base64.decode(stripped);

    int index = -1;
    for (int i = 0; i < der.length - 4 && i < 300; i++) {
      if (der[i] == 0x02 &&
          der[i + 1] == 0x01 &&
          (der[i + 2] == 0x00 || der[i + 2] == 0x01) &&
          der[i + 3] == 0x02) {
        index = i;
        break;
      }
    }

    if (index == -1) {
      throw Exception(
          "Invalid RSA Private Key format: PKCS#1 inner sequence not found. Please ensure it is an unencrypted RSA private key.");
    }

    int offset = index + 3;

    BigInt readInteger(String name) {
      if (der[offset] != 0x02) {
        throw Exception("Expected INTEGER tag for $name at offset $offset");
      }
      offset++;

      int length = der[offset++];
      if ((length & 0x80) != 0) {
        int count = length & 0x7F;
        length = 0;
        for (int i = 0; i < count; i++) {
          length = (length << 8) | der[offset++];
        }
      }

      var intBytes = der.sublist(offset, offset + length);
      offset += length;

      BigInt result = BigInt.zero;
      for (int i = 0; i < intBytes.length; i++) {
        result = (result << 8) | BigInt.from(intBytes[i]);
      }
      return result;
    }

    final n = readInteger("Modulus (n)");
    final e = readInteger("Public Exponent (e)");
    final d = readInteger("Private Exponent (d)");
    // We intentionally stop here completely ignoring p, q, dp, dq, and qi
    // because mathematically we solely need `n` and `d` to sign!

    return {'n': n, 'd': d};
  }
}
