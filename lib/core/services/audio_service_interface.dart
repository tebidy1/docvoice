import '../models/audio_models.dart';
import 'base_service_interface.dart';

abstract class AudioService extends BaseService {
  Future<AudioUploadResult> uploadAudio(dynamic audioFile);
  Future<TranscriptionResult> getTranscription(String audioId);
  Stream<TranscriptionStatus> watchTranscription(String audioId);
  Future<void> cancelTranscription(String audioId);
  Stream<UploadProgress> watchUploadProgress(String uploadId);
  List<String> getSupportedFormats();
  Future<AudioValidationResult> validateAudioFile(dynamic audioFile);
}
