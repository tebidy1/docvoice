// This file is a backward-compatible wrapper.
// The actual implementation has moved to SherpaLocalService using sherpa_onnx.
// This file redirects to the new service for any code that still imports it.

export 'sherpa_local_service.dart' show SherpaLocalService;

import 'sherpa_local_service.dart';

/// Legacy wrapper — delegates to SherpaLocalService (sherpa_onnx + SenseVoice).
class WhisperLocalService {
  static final WhisperLocalService _instance = WhisperLocalService._internal();
  factory WhisperLocalService() => _instance;
  WhisperLocalService._internal();

  final SherpaLocalService _sherpa = SherpaLocalService();

  Future<void> initialize() => _sherpa.initialize();

  Future<String> transcribeAudioUrl(String audioFilePath) =>
      _sherpa.transcribeAudioFile(audioFilePath);
}


