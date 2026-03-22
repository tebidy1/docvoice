import 'dart:convert';
import 'dart:io';

void main() async {
  final token = 'eyJhbGciOiJIUzI1NiJ9.ewogICJzZXNzaW9uSWQiIDogIjA4MjZjOWQxLTc4YjItNDc4Yi1iZTQ5LTk1OTdjM2JmYjJkNSIsCiAgInRlbmFudElkIiA6ICJvY2lkMS50ZW5hbmN5Lm9jMS4uYWFhYWFhYWFkdDNldWx4Y2h1NnlncmlzcXNhaTR6NnFqaTVkeXFpYW03dGd3Z2Q2cnJ4ZTJ3c29jcDJhIiwKICAiaWF0IiA6IDE3NzIxNDIwNzEzNDgsCiAgImV4cCIgOiAxNzcyMTQ5MjcxMzQ4Cn0.slXHSazv18GtApbWzvfjZZFSUd1ywrw0oUu1wnj0MaE';
  
  // Try standard websocket path
  await testWs("https://realtime.aiservice.me-riyadh-1.oci.oraclecloud.com/ws/transcribe/stream?token=\${Uri.encodeComponent(token)}");
  
  // Try API version prefixed path
  await testWs("https://realtime.aiservice.me-riyadh-1.oci.oraclecloud.com/20220101/ws/transcribe/stream?token=\${Uri.encodeComponent(token)}");

  // Try FULL query params path
  final params = 'token=\${Uri.encodeComponent(token)}&isAckEnabled=false&encoding=audio/raw;rate=16000';
  await testWs("https://realtime.aiservice.me-riyadh-1.oci.oraclecloud.com/20220101/ws/transcribe/stream?\$params");
}

Future<void> testWs(String url) async {
  try {
    print("\\nConnecting to: \$url");
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    request.headers.add('Connection', 'Upgrade');
    request.headers.add('Upgrade', 'websocket');
    request.headers.add('Sec-WebSocket-Version', '13');
    request.headers.add('Sec-WebSocket-Key', 'x3JJHMbDL1EzLkh9GBhXDw==');
    
    final response = await request.close();
    print("  -> Status Code: \${response.statusCode} \${response.reasonPhrase}");
    print("  -> Connection Header: \${response.headers.value('Connection')}");
    print("  -> Upgrade Header: \${response.headers.value('Upgrade')}");
    
    if (response.statusCode != 101) {
      final body = await response.transform(utf8.decoder).join();
      print("  -> Body: \$body");
    } else {
      print("  -> WebSocked Upgraded Successfully! (Exiting stream)");
    }
  } catch (e) {
    print("  -> Exception: \$e");
  }
}
