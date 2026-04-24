abstract class AudioTranscriptionRepository {
  Future<Map<String, dynamic>> transcribeAudio({
    required List<int> audioBytes,
    required String filename,
    String? model,
    String? language,
  });
}
