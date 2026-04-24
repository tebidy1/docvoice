import '../network/api_client.dart';

class UploadAudioUseCase {
  final ApiClient _apiClient;

  UploadAudioUseCase(this._apiClient);

  Future<Map<String, dynamic>> execute({
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
