import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'services/oci_request_signer.dart';

class OciCredentials {
  final String tenancyId;
  final String userId;
  final String fingerprint;
  final String compartmentId;
  final String privateKeyPem;
  const OciCredentials({required this.tenancyId, required this.userId, required this.fingerprint, required this.compartmentId, required this.privateKeyPem});
}

void main() async {
  final creds = OciCredentials(
    tenancyId: 'ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a',
    userId: 'ocid1.user.oc1..aaaaaaaa3ykq2ykgaixlhze3yip5m3fxrsbkghnzecezym7c7neqk57fupdq',
    fingerprint: 'fb:38:d1:b4:7c:47:61:fd:95:e6:5a:e8:bb:2c:43:ee',
    compartmentId: 'ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a',
    privateKeyPem: '''-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDLQFaVcyVWbo1jq4LqN1jQ6E25nbE1Ks6nUE6zhH1h6B6kUSOYLihsKVxmKI5wVKKKYUnTTqUCYmtrKBlan46q9vfk0ccV1dxDDFIdZezk5+vuEdLklBxia/acfKZib3CThCuPX6NPoUPGrXDDeDqwsp4dhvu1QkZJRoGyMEoV5qrl2Boj0H+yVoSlAw1gCN8PZYCgstv7xgAgCwx78KIulc8uIwyl0SmEuyl9DzihqdMNjOf84yeulC5wvGE4UoQVMgiifUn3j59Iio+Wua1SYqas2cHGUxq17t7Y0Ti5iVPtL5DTASXjNbqL8woeDRFiTtcV+mmkwsBC4kXaib69AgMBAAECggIAAvqC+lGJFR/tda3hry3XS50dPHs1ibECUnHgbAw6QSkjanw06xSWwOUHRrOmng9OICcxANb+GrpCAZHsHdzzkd5Tf4MyfsesS2rpY3xm+8DJVJW8Hd+XczrKpFGa/PDN+R9z+vfSFHHpehvNvf5A+pjCLUPD5GIKVnsQc1chUs+l9keRZfHinCf3ao6fYK7hRxC5pYIrmf2f2AuPb/K0UaC3hS+oa+XLNxe5bZUuQDPuWr1dMRWKAfraHxSC+psmlqWnhpJA8DLYp1K+zRyotTyZhI3NmdWSJh3PnbtOEVCslXtaRTT/9zXkZZ7yu7PSZrg1ob1SnN7B9M3nKFVmeQKBgQDrZMOJgd29sNHh26bOcrAkQmSNyC+bElNSBWvwnBEbvqeHiSCcADWIDd4VWnLMbqUNN0GusxJhQxGvzZXlXD8K0LxnEDspecEaWiTPuYnQ752v28YRZosxSUB7bl89FjQpcu3GPd1hK3UJtpo1qQrauOMyjWA/4uT7grfVLso5aQKBgQDdC0G+Dc28r6T1Rx4cxYR0W2hnHFq1X7yDrVx0H3PEdH8+fyJPAJPkk5m/LdgE2l068NL1/39Ru3IehPM+8ZDEd2rEfvhP3IMO3uAm7IvkJMIbFFcEuR5YcABm3p2pdsEUT+/N2qjjBrvuSsghscowHsjR1rEJebW+SuBfD1V8NQKBgQDZR8Ouk+9of2TcxHHusrKgZaCHtzcqPvomBdci3Ax2vb/KPeuZ1B+VnKdYsoqw5Zj43/6DEcxvdwdGbdBlTIbspsyhnbvehwKWHotIKw1pjSTTBVyJB0yIjAM3bCQBMROpBuswSD6myQRZmPIzgfwA9RTSvukPT5LqDjk+UNhdsQKBgD1cj56D1HYpyEAywuA30KJAccYV7/RjpEBlksHFrWx+7ofZ4RtPTL7qXobc4hfOyoy/J8EUcTKuN2rTe3cgthBkGiZ8HNCGpXcuVclYZykpLx03U0TDYvIn/WSRLfFKPyU1X5uktLd5OhhXeCEqardbBGKEF9dKizJNNOYOqqt1AoGBAOa107lq0koA7A1oSlayeJY/Rw/MR3Qgzmv6Xn7dF1K2dxySo6c/8erNWt17qsC2lRFlo3p8UhyuyywvIYpNy8g1uEYVTGTAtgJKhOGSSMOpkdivygLgHGv1e+1/m79c6oGGUqdf2xmxSgxjHzsvjFhu1HSrW46DXj424N8jFYGS
-----END PRIVATE KEY-----''',
  );

  final signer = OciRequestSigner(
    tenancyId: creds.tenancyId,
    userId: creds.userId,
    fingerprint: creds.fingerprint,
    privateKeyPem: creds.privateKeyPem,
  );

  final body = jsonEncode({'compartmentId': creds.compartmentId});
  final bodyBytes = Uint8List.fromList(utf8.encode(body));

  final urls = [
    'https://speech.aiservice.me-riyadh-1.oci.oraclecloud.com/20220101/actions/createRealtimeSessionToken',
    'https://speech.aiservice.me-riyadh-1.oci.oraclecloud.com/20220101/realtimeSessionTokens',
    'https://speech.aiservice.me-riyadh-1.oci.oraclecloud.com/20220101/realtimeSessionToken',
    'https://realtime.aiservice.me-riyadh-1.oci.oraclecloud.com/20220101/actions/createRealtimeSessionToken',
    'https://realtime.aiservice.me-riyadh-1.oci.oraclecloud.com/20220601/actions/createRealtimeSessionToken',
    'https://speech.aiservice.me-riyadh-1.oci.oraclecloud.com/20220601/actions/createRealtimeSessionToken',
  ];

  for (var url in urls) {
    print("\\n--- Testing URL: '" + url + "' ---");
    try {
      final signedHeaders = signer.signRequest(
        method: 'POST',
        url: url,
        body: bodyBytes,
      );

      final response = await http.post(
        Uri.parse(url),
        headers: signedHeaders,
        body: bodyBytes,
      );

      print("Status Code: " + response.statusCode.toString());
      print("Body: " + response.body);
    } catch (e) {
      print("Error: " + e.toString());
    }
  }
}
