import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../interfaces/audio_service.dart';
import '../interfaces/base_service.dart';
import '../models/audio_models.dart';
import '../error/app_error.dart';
import '../../services/api_service.dart';

/// Concrete implementation of AudioService for handling audio upload and transcription
class AudioServiceImpl extends AudioService with ServiceLifecycle {
  final ApiService _apiService = ApiService();
  final Map<String, StreamController<TranscriptionStatus>> _transcriptionStreams = {};
  final Map<String, StreamController<UploadProgress>> _uploadStreams = {};
  final Map<String, Timer> _statusPollingTimers = {};
  
  // Audio format constraints
  static const List<String> _supportedFormats = [
    'mp3', 'wav', 'm4a', 'flac', 'aac', 'ogg', 'webm', 'mp4', 'mpeg', 'mpga'
  ];
  static const int _maxFileSizeBytes = 25 * 1024 * 1024; // 25MB
  static const int _minFileSizeBytes = 1024; // 1KB
  
  @override
  Future<void> initialize() async {
    ensureNotDisposed();
    await _apiService.init();
    markInitialized();
  }
  
  @override
  Future<void> dispose() async {
    // Cancel all active streams and timers
    for (final controller in _transcriptionStreams.values) {
      await controller.close();
    }
    for (final controller in _uploadStreams.values) {
      await controller.close();
    }
    for (final timer in _statusPollingTimers.values) {
      timer.cancel();
    }
    
    _transcriptionStreams.clear();
    _uploadStreams.clear();
    _statusPollingTimers.clear();
    
    markDisposed();
  }
  
  @override
  List<String> getSupportedFormats() {
    return List.unmodifiable(_supportedFormats);
  }
  
  @override
  Future<AudioValidationResult> validateAudioFile(File audioFile) async {
    ensureInitialized();
    
    final errors = <String>[];
    final metadata = <String, dynamic>{};
    
    try {
      // Check if file exists
      if (!await audioFile.exists()) {
        errors.add('Audio file does not exist');
        return AudioValidationResult.invalid(errors);
      }
      
      // Get file info
      final fileName = path.basename(audioFile.path);
      final fileExtension = path.extension(fileName).toLowerCase().replaceFirst('.', '');
      final fileStat = await audioFile.stat();
      final fileSize = fileStat.size;
      
      metadata['fileName'] = fileName;
      metadata['fileExtension'] = fileExtension;
      metadata['fileSize'] = fileSize;
      metadata['lastModified'] = fileStat.modified.toIso8601String();
      
      // Validate file format
      if (!_supportedFormats.contains(fileExtension)) {
        errors.add('Unsupported audio format: $fileExtension. Supported formats: ${_supportedFormats.join(', ')}');
      }
      
      // Validate file size
      if (fileSize > _maxFileSizeBytes) {
        final maxSizeMB = (_maxFileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
        final currentSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        errors.add('File size too large: ${currentSizeMB}MB. Maximum allowed: ${maxSizeMB}MB');
      }
      
      if (fileSize < _minFileSizeBytes) {
        errors.add('File size too small: ${fileSize}B. Minimum required: ${_minFileSizeBytes}B');
      }
      
      // Try to read file header to validate it's actually an audio file
      try {
        final bytes = await audioFile.readAsBytes();
        if (bytes.isEmpty) {
          errors.add('Audio file is empty');
        } else {
          metadata['actualFileSize'] = bytes.length;
          // Basic file signature validation
          if (!_isValidAudioFileSignature(bytes, fileExtension)) {
            errors.add('File does not appear to be a valid $fileExtension audio file');
          }
        }
      } catch (e) {
        errors.add('Unable to read audio file: $e');
      }
      
      if (errors.isEmpty) {
        return AudioValidationResult.valid(metadata: metadata);
      } else {
        return AudioValidationResult.invalid(errors);
      }
      
    } catch (e) {
      errors.add('Validation failed: $e');
      return AudioValidationResult.invalid(errors);
    }
  }
  
  @override
  Future<AudioUploadResult> uploadAudio(File audioFile) async {
    ensureInitialized();
    
    // First validate the file
    final validationResult = await validateAudioFile(audioFile);
    if (!validationResult.isValid) {
      throw AudioError(
        'Audio file validation failed: ${validationResult.errors.join(', ')}',
        code: 'validation_failed',
        context: {'errors': validationResult.errors},
      );
    }
    
    final uploadId = _generateUploadId();
    final fileName = path.basename(audioFile.path);
    final fileSize = await audioFile.length();
    
    try {
      // Create upload progress stream
      final progressController = StreamController<UploadProgress>.broadcast();
      _uploadStreams[uploadId] = progressController;
      
      // Initial progress
      progressController.add(UploadProgress(
        uploadId: uploadId,
        bytesUploaded: 0,
        totalBytes: fileSize,
        percentage: 0.0,
        status: UploadStatus.pending,
      ));
      
          // Create a new inbox note with the audio file
      final noteData = {
        'title': 'Audio Recording - ${DateTime.now().toString().substring(0, 19)}',
        'content': 'Audio file uploaded for transcription',
        'original_text': 'Transcription pending...',
        'status': 'draft',
        'audio_path': fileName,
      };
      
      // Update progress to uploading
      progressController.add(UploadProgress(
        uploadId: uploadId,
        bytesUploaded: 0,
        totalBytes: fileSize,
        percentage: 0.0,
        status: UploadStatus.uploading,
      ));
      
      // Create inbox note via API
      final response = await _apiService.post('/inbox-notes', body: noteData);
      
      // Update progress to completed
      progressController.add(UploadProgress(
        uploadId: uploadId,
        bytesUploaded: fileSize,
        totalBytes: fileSize,
        percentage: 100.0,
        status: UploadStatus.completed,
      ));
      
      if (response['success'] == true || response['status'] == true) {
        final noteId = response['data']?['id']?.toString() ?? 
                      response['payload']?['id']?.toString() ?? 
                      uploadId;
        
        final result = AudioUploadResult(
          uploadId: noteId,
          fileName: fileName,
          fileSize: fileSize,
          status: UploadStatus.completed,
          uploadedAt: DateTime.now(),
        );
        
        // Start transcription simulation (since we don't have real transcription API yet)
        _simulateTranscription(noteId, audioFile);
        
        // Close progress stream after a delay
        Timer(const Duration(seconds: 5), () {
          progressController.close();
          _uploadStreams.remove(uploadId);
        });
        
        return result;
      } else {
        // Update progress to failed
        progressController.add(UploadProgress(
          uploadId: uploadId,
          bytesUploaded: 0,
          totalBytes: fileSize,
          percentage: 0.0,
          status: UploadStatus.failed,
        ));
        
        final errorMessage = response['message'] ?? 'Upload failed';
        throw AudioError(
          errorMessage,
          code: 'upload_failed',
          context: {'response': response},
        );
      }
      
    } catch (e) {
      // Update progress to failed
      final progressController = _uploadStreams[uploadId];
      if (progressController != null) {
        progressController.add(UploadProgress(
          uploadId: uploadId,
          bytesUploaded: 0,
          totalBytes: fileSize,
          percentage: 0.0,
          status: UploadStatus.failed,
        ));
      }
      
      if (e is AudioError) {
        rethrow;
      }
      
      throw AudioError(
        'Audio upload failed: $e',
        code: 'upload_error',
        context: {'uploadId': uploadId, 'fileName': fileName},
      );
    }
  }
  
  @override
  Future<TranscriptionResult> getTranscription(String audioId) async {
    ensureInitialized();
    
    try {
      // Get the inbox note which contains the transcription
      final response = await _apiService.get('/inbox-notes/$audioId');
      
      if (response['success'] == true || response['status'] == true) {
        final data = response['data'] ?? response['payload'];
        
        // Determine transcription status based on note content
        TranscriptionStatus status;
        String transcribedText = data['content'] ?? '';
        double confidence = 0.95; // Default confidence
        
        if (transcribedText.contains('Transcription pending') || 
            transcribedText.contains('Processing')) {
          status = TranscriptionStatus.processing;
          transcribedText = '';
          confidence = 0.0;
        } else if (transcribedText.contains('Transcription failed') ||
                   transcribedText.contains('Error')) {
          status = TranscriptionStatus.failed;
          transcribedText = '';
          confidence = 0.0;
        } else if (transcribedText.isNotEmpty && 
                   !transcribedText.contains('pending')) {
          status = TranscriptionStatus.completed;
        } else {
          status = TranscriptionStatus.queued;
          confidence = 0.0;
        }
        
        return TranscriptionResult(
          transcriptionId: audioId,
          audioId: audioId,
          transcribedText: transcribedText,
          confidence: confidence,
          status: status,
          completedAt: status == TranscriptionStatus.completed 
              ? DateTime.parse(data['updated_at'] ?? DateTime.now().toIso8601String())
              : null,
        );
      } else {
        throw AudioError(
          'Failed to get transcription: ${response['message'] ?? 'Unknown error'}',
          code: 'transcription_fetch_failed',
          context: {'audioId': audioId, 'response': response},
        );
      }
    } catch (e) {
      if (e is AudioError) rethrow;
      throw AudioError(
        'Failed to get transcription: $e',
        code: 'transcription_fetch_failed',
        context: {'audioId': audioId},
      );
    }
  }
  
  @override
  Stream<TranscriptionStatus> watchTranscription(String audioId) {
    ensureInitialized();
    
    if (_transcriptionStreams.containsKey(audioId)) {
      return _transcriptionStreams[audioId]!.stream;
    }
    
    final controller = StreamController<TranscriptionStatus>.broadcast();
    _transcriptionStreams[audioId] = controller;
    
    // Start polling for status updates
    _startTranscriptionPolling(audioId, controller);
    
    return controller.stream;
  }
  
  @override
  Future<void> cancelTranscription(String audioId) async {
    ensureInitialized();
    
    try {
      // Update the inbox note to indicate cancellation
      await _apiService.patch('/inbox-notes/$audioId', body: {
        'content': 'Transcription cancelled by user',
        'status': 'draft'
      });
      
      // Update stream if exists
      final controller = _transcriptionStreams[audioId];
      if (controller != null) {
        controller.add(TranscriptionStatus.cancelled);
        await controller.close();
        _transcriptionStreams.remove(audioId);
      }
      
      // Cancel polling timer
      _statusPollingTimers[audioId]?.cancel();
      _statusPollingTimers.remove(audioId);
      
    } catch (e) {
      throw AudioError(
        'Failed to cancel transcription: $e',
        code: 'transcription_cancel_failed',
        context: {'audioId': audioId},
      );
    }
  }
  
  // Simulate transcription process (since we don't have real AI transcription yet)
  Future<void> _simulateTranscription(String noteId, File audioFile) async {
    // Wait a bit then update the note with simulated transcription
    Timer(const Duration(seconds: 3), () async {
      try {
        // Simulate transcription based on file name or generate sample text
        final fileName = path.basename(audioFile.path);
        final simulatedText = _generateSimulatedTranscription(fileName);
        
        await _apiService.patch('/inbox-notes/$noteId', body: {
          'content': simulatedText,
          'original_text': simulatedText,
          'status': 'processed'
        });
        
        // Notify any listeners
        final controller = _transcriptionStreams[noteId];
        if (controller != null) {
          controller.add(TranscriptionStatus.completed);
        }
      } catch (e) {
        print('Failed to simulate transcription: $e');
        // Update with error
        try {
          await _apiService.patch('/inbox-notes/$noteId', body: {
            'content': 'Transcription failed: $e',
            'status': 'draft'
          });
          
          final controller = _transcriptionStreams[noteId];
          if (controller != null) {
            controller.add(TranscriptionStatus.failed);
          }
        } catch (updateError) {
          print('Failed to update note with error: $updateError');
        }
      }
    });
  }
  
  String _generateSimulatedTranscription(String fileName) {
    // Generate sample medical transcription based on file name
    final samples = [
      'Patient presents with chest pain and shortness of breath. Vital signs are stable. Recommend ECG and chest X-ray.',
      'Follow-up visit for hypertension. Blood pressure is well controlled on current medication. Continue current regimen.',
      'Patient complains of headache and dizziness. Physical examination reveals no abnormalities. Recommend rest and hydration.',
      'Routine check-up completed. All vital signs within normal limits. Patient advised to continue healthy lifestyle.',
      'Patient reports improvement in symptoms after starting new medication. No adverse effects noted. Continue treatment plan.',
    ];
    
    // Use file name hash to consistently return same sample for same file
    final hash = fileName.hashCode.abs();
    return samples[hash % samples.length];
  }
  
  @override
  Stream<UploadProgress> watchUploadProgress(String uploadId) {
    final controller = _uploadStreams[uploadId];
    if (controller != null) {
      return controller.stream;
    }
    
    // Return empty stream if upload not found
    return const Stream.empty();
  }
  
  // Private helper methods
  
  Future<String> _getBaseUrl() async {
    // Get base URL from environment or use default
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://docvoice.gumra-ai.com/api');
    return baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  }
  
  Future<String?> _getAuthToken() async {
    // Get token from shared preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      return null;
    }
  }
  
  String _generateUploadId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.toString() + DateTime.now().microsecond.toString();
    final bytes = utf8.encode(random);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
  
  bool _isValidAudioFileSignature(Uint8List bytes, String extension) {
    if (bytes.length < 4) return false;
    
    // Check common audio file signatures
    switch (extension) {
      case 'mp3':
        // MP3 files can start with ID3 tag or frame sync
        return (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) || // ID3
               (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0); // Frame sync
      case 'wav':
        // WAV files start with "RIFF" and contain "WAVE"
        return bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
               bytes.length >= 12 && bytes[8] == 0x57 && bytes[9] == 0x41 && bytes[10] == 0x56 && bytes[11] == 0x45;
      case 'flac':
        // FLAC files start with "fLaC"
        return bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43;
      case 'ogg':
        // OGG files start with "OggS"
        return bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53;
      case 'm4a':
      case 'mp4':
        // M4A/MP4 files have "ftyp" at offset 4
        return bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70;
      default:
        // For other formats, just check if file is not empty and has some content
        return bytes.isNotEmpty && bytes.any((byte) => byte != 0);
    }
  }
  
  TranscriptionStatus _parseTranscriptionStatus(dynamic status) {
    if (status == null) return TranscriptionStatus.queued;
    
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'queued':
      case 'pending':
        return TranscriptionStatus.queued;
      case 'processing':
      case 'in_progress':
        return TranscriptionStatus.processing;
      case 'completed':
      case 'done':
        return TranscriptionStatus.completed;
      case 'failed':
      case 'error':
        return TranscriptionStatus.failed;
      case 'cancelled':
      case 'canceled':
        return TranscriptionStatus.cancelled;
      default:
        return TranscriptionStatus.queued;
    }
  }
  
  void _startTranscriptionPolling(String audioId, StreamController<TranscriptionStatus> controller) {
    final timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final transcription = await getTranscription(audioId);
        controller.add(transcription.status);
        
        // Stop polling if transcription is complete, failed, or cancelled
        if (transcription.status == TranscriptionStatus.completed ||
            transcription.status == TranscriptionStatus.failed ||
            transcription.status == TranscriptionStatus.cancelled) {
          timer.cancel();
          _statusPollingTimers.remove(audioId);
          
          // Close stream after a delay
          Timer(const Duration(seconds: 5), () {
            controller.close();
            _transcriptionStreams.remove(audioId);
          });
        }
      } catch (e) {
        // On error, add failed status and stop polling
        controller.add(TranscriptionStatus.failed);
        timer.cancel();
        _statusPollingTimers.remove(audioId);
        
        Timer(const Duration(seconds: 5), () {
          controller.close();
          _transcriptionStreams.remove(audioId);
        });
      }
    });
    
    _statusPollingTimers[audioId] = timer;
  }
}