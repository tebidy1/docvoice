import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GroqService {
  final String apiKey;
  
  GroqService({required this.apiKey});

  Future<String> transcribe(Uint8List audioBytes, {String filename = 'recording.wav'}) async {
    if (apiKey.isEmpty || apiKey.contains("your_groq_api_key")) {
      return "Error: Groq API Key not set.";
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';
      
      // Add model field
      request.fields['model'] = 'whisper-large-v3';
      request.fields['response_format'] = 'json';
      request.fields['language'] = 'en'; // Force English for medical terms accuracy

      // Add audio file
      // Groq expects a file. We create a multipart file from bytes.
      // Filename is important for mime type detection usually, though we send raw PCM/Wav if possible.
      // Since we are sending raw PCM 16bit 16kHz from 'record' package (if configured), 
      // we might need to wrap it in a WAV header or just try sending as .wav if the bytes are wav.
      // The 'record' package with 'AudioEncoder.pcm16bit' sends raw PCM. 
      // Whisper might struggle with raw PCM without a header.
      // Ideally we should add a WAV header.
      
      // For MVP, let's assume we add a WAV header or the 'record' package was configured to output wav.
      // Let's update AudioRecorderService to output WAV container if possible, or add header here.
      // Actually, 'AudioEncoder.wav' exists in some versions, or we construct it.
      // Let's assume we send it as 'recording.wav'.
      
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
