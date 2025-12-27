import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GroqService {
  final String apiKey;
  
  // Hardcoded for standalone test - ideally moved to secure storage or settings
  GroqService({this.apiKey = "gsk_..."}); // TODO: Insert Real Key or load from Settings

  Future<String> transcribe(Uint8List audioBytes, {String filename = 'recording.m4a'}) async {
    // Check if key is valid (simple check)
    if (apiKey.isEmpty || apiKey.contains("...")) {
      return "Error: Groq API Key not set in Mobile.";
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';
      
      request.fields['model'] = 'whisper-large-v3';
      request.fields['response_format'] = 'json';
      // Force "transcribe only" behavior using a prompt (Whisper feature)
      request.fields['prompt'] = 'Transcribe exactly what is said. Do NOT translate from Arabic to English or vice versa. Write Arabic as Arabic, English as English.';
      // request.fields['language'] = 'en'; // Removed to allow Auto-Detect (Arabic/English)

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: filename,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] ?? "";
      } else {
        print("Groq Error: ${response.body}");
        return "Error: ${response.statusCode}";
      }
    } catch (e) {
      print("Groq Exception: $e");
      return "Error: $e";
    }
  }
}
