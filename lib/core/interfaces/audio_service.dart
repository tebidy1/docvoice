import 'dart:io';
import 'base_service.dart';
import '../models/audio_models.dart';

/// Audio service interface for handling audio upload and transcription
abstract class AudioService extends BaseService {
  /// Upload audio file for transcription
  Future<AudioUploadResult> uploadAudio(File audioFile);
  
  /// Get transcription result
  Future<TranscriptionResult> getTranscription(String audioId);
  
  /// Watch transcription status changes
  Stream<TranscriptionStatus> watchTranscription(String audioId);
  
  /// Cancel transcription
  Future<void> cancelTranscription(String audioId);
  
  /// Get upload progress
  Stream<UploadProgress> watchUploadProgress(String uploadId);
  
  /// Get supported audio formats
  List<String> getSupportedFormats();
  
  /// Validate audio file
  Future<AudioValidationResult> validateAudioFile(File audioFile);
}