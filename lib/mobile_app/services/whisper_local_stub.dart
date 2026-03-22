class WhisperLocalService {
  static final WhisperLocalService _instance = WhisperLocalService._internal();
  factory WhisperLocalService() => _instance;
  WhisperLocalService._internal();

  Future<void> initialize() async {
    throw UnsupportedError('Local Whisper/Sherpa STT is not supported on the Web.');
  }

  Future<String> transcribeAudioUrl(String audioFilePath) async {
    throw UnsupportedError('Local Whisper/Sherpa STT is not supported on the Web.');
  }
}
