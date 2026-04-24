import '../repositories/audio_transcription_repository.dart';

class UploadAudioUseCase {
  final AudioTranscriptionRepository _audioTranscriptionRepository;

  UploadAudioUseCase(this._audioTranscriptionRepository);

  Future<Map<String, dynamic>> execute({
    required List<int> audioBytes,
    required String filename,
    String? model,
    String? language,
  }) async {
    return await _audioTranscriptionRepository.transcribeAudio(
      audioBytes: audioBytes,
      filename: filename,
      model: model,
      language: language,
    );
  }
}
