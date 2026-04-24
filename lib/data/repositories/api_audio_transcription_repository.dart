import '../../core/network/api_client.dart';
import '../../core/repositories/audio_transcription_repository.dart';

class ApiAudioTranscriptionRepository implements AudioTranscriptionRepository {
  final ApiClient _apiClient;

  ApiAudioTranscriptionRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<Map<String, dynamic>> transcribeAudio({
    required List<int> audioBytes,
    required String filename,
    String? model,
    String? language,
  }) async {
    return await _apiClient.multipartPost(
      '/audio/transcribe',
      fileBytes: audioBytes,
      filename: filename,
      fields: {
        if (model != null) 'model': model,
        if (language != null) 'language': language,
      },
    );
  }
}
