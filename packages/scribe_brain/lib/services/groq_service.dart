import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/processing_config.dart';

class GroqService {
  final String apiKey;
  
  GroqService({required this.apiKey});

  /// Transcribes audio using the specified model.
  /// 
  /// [modelId] can be 'whisper-large-v3' (Precise) or 'whisper-large-v3-turbo' (Fast).
  /// Defaults to Precise if not specified, but usually controlled by ProcessingConfig.
  Future<String> transcribe(Uint8List audioBytes, {
    String filename = 'recording.m4a', 
    String? modelId,
  }) async {
    final effectiveModel = modelId ?? GroqModel.precise.modelId;

    if (apiKey.isEmpty) {
      return "Error: Groq API Key not set.";
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';
      
      request.fields['model'] = effectiveModel;
      request.fields['response_format'] = 'json';
      request.fields['prompt'] = 'Transcribe the audio exactly as spoken in English.';
      request.fields['language'] = 'en'; 
      // Groq does not support 'task' param, unlike OpenAI

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
        print("Groq Error Status: ${response.statusCode}");
        print("Groq Error Body: ${response.body}");
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      print("Groq Exception: $e");
      return "Error: $e";
    }
  }
}
