import 'base_repository.dart';
import '../models/audio_models.dart';

/// Repository interface for AudioUploadResult entities
abstract class AudioUploadRepository extends BaseRepository<AudioUploadResult> {
  /// Get uploads by status
  Future<List<AudioUploadResult>> getByStatus(UploadStatus status);
  
  /// Get recent uploads
  Future<List<AudioUploadResult>> getRecent({int limit = 20});
  
  /// Get uploads by date range
  Future<List<AudioUploadResult>> getByDateRange(DateTime start, DateTime end);
  
  /// Get uploads by file name pattern
  Future<List<AudioUploadResult>> getByFileNamePattern(String pattern);
  
  /// Update upload status
  Future<void> updateStatus(String uploadId, UploadStatus status);
  
  /// Get upload statistics
  Future<Map<String, dynamic>> getUploadStats();
  
  /// Clean up old uploads
  Future<void> cleanupOldUploads({Duration? olderThan});
}

/// Repository interface for TranscriptionResult entities
abstract class TranscriptionRepository extends BaseRepository<TranscriptionResult> {
  /// Get transcriptions by status
  Future<List<TranscriptionResult>> getByStatus(TranscriptionStatus status);
  
  /// Get transcriptions by audio ID
  Future<List<TranscriptionResult>> getByAudioId(String audioId);
  
  /// Get transcriptions by confidence range
  Future<List<TranscriptionResult>> getByConfidenceRange(double minConfidence, double maxConfidence);
  
  /// Get recent transcriptions
  Future<List<TranscriptionResult>> getRecent({int limit = 20});
  
  /// Get transcriptions by date range
  Future<List<TranscriptionResult>> getByDateRange(DateTime start, DateTime end);
  
  /// Update transcription status
  Future<void> updateStatus(String transcriptionId, TranscriptionStatus status);
  
  /// Update transcription text
  Future<void> updateTranscribedText(String transcriptionId, String text, double confidence);
  
  /// Get transcription statistics
  Future<Map<String, dynamic>> getTranscriptionStats();
  
  /// Search transcriptions by text content
  Future<List<TranscriptionResult>> searchByText(String query);
  
  /// Get failed transcriptions for retry
  Future<List<TranscriptionResult>> getFailedTranscriptions();
  
  /// Clean up old transcriptions
  Future<void> cleanupOldTranscriptions({Duration? olderThan});
}

/// Repository interface for upload progress tracking
abstract class UploadProgressRepository {
  /// Save upload progress
  Future<void> saveProgress(UploadProgress progress);
  
  /// Get upload progress
  Future<UploadProgress?> getProgress(String uploadId);
  
  /// Watch upload progress changes
  Stream<UploadProgress> watchProgress(String uploadId);
  
  /// Remove progress tracking
  Future<void> removeProgress(String uploadId);
  
  /// Get all active uploads
  Future<List<UploadProgress>> getActiveUploads();
  
  /// Clean up completed uploads
  Future<void> cleanupCompletedUploads();
}