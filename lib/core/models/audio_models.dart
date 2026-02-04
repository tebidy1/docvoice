/// Audio processing models and enums
/// 
/// This file contains all the models and enums related to audio processing,
/// upload, and transcription functionality.

/// Upload status enumeration
enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
  cancelled;
  
  /// Check if upload is in progress
  bool get isInProgress => this == UploadStatus.uploading;
  
  /// Check if upload is complete
  bool get isComplete => this == UploadStatus.completed;
  
  /// Check if upload has failed
  bool get hasFailed => this == UploadStatus.failed;
  
  /// Check if upload was cancelled
  bool get isCancelled => this == UploadStatus.cancelled;
  
  /// Check if upload is in a final state
  bool get isFinal => isComplete || hasFailed || isCancelled;
}

/// Transcription status enumeration
enum TranscriptionStatus {
  queued,
  processing,
  completed,
  failed,
  cancelled;
  
  /// Check if transcription is in progress
  bool get isInProgress => this == TranscriptionStatus.processing;
  
  /// Check if transcription is complete
  bool get isComplete => this == TranscriptionStatus.completed;
  
  /// Check if transcription has failed
  bool get hasFailed => this == TranscriptionStatus.failed;
  
  /// Check if transcription was cancelled
  bool get isCancelled => this == TranscriptionStatus.cancelled;
  
  /// Check if transcription is in a final state
  bool get isFinal => isComplete || hasFailed || isCancelled;
  
  /// Check if transcription is waiting to be processed
  bool get isQueued => this == TranscriptionStatus.queued;
}

/// Audio upload result
class AudioUploadResult {
  final String uploadId;
  final String fileName;
  final int fileSize;
  final UploadStatus status;
  final DateTime uploadedAt;
  final String? errorMessage;
  
  const AudioUploadResult({
    required this.uploadId,
    required this.fileName,
    required this.fileSize,
    required this.status,
    required this.uploadedAt,
    this.errorMessage,
  });
  
  /// Create a copy with updated fields
  AudioUploadResult copyWith({
    String? uploadId,
    String? fileName,
    int? fileSize,
    UploadStatus? status,
    DateTime? uploadedAt,
    String? errorMessage,
  }) {
    return AudioUploadResult(
      uploadId: uploadId ?? this.uploadId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'upload_id': uploadId,
      'file_name': fileName,
      'file_size': fileSize,
      'status': status.name,
      'uploaded_at': uploadedAt.toIso8601String(),
      'error_message': errorMessage,
    };
  }
  
  /// Create from JSON
  factory AudioUploadResult.fromJson(Map<String, dynamic> json) {
    return AudioUploadResult(
      uploadId: json['upload_id'] ?? '',
      fileName: json['file_name'] ?? '',
      fileSize: json['file_size'] ?? 0,
      status: UploadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => UploadStatus.pending,
      ),
      uploadedAt: DateTime.parse(json['uploaded_at'] ?? DateTime.now().toIso8601String()),
      errorMessage: json['error_message'],
    );
  }
  
  @override
  String toString() {
    return 'AudioUploadResult(uploadId: $uploadId, fileName: $fileName, status: $status)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioUploadResult &&
        other.uploadId == uploadId &&
        other.fileName == fileName &&
        other.fileSize == fileSize &&
        other.status == status &&
        other.uploadedAt == uploadedAt &&
        other.errorMessage == errorMessage;
  }
  
  @override
  int get hashCode {
    return Object.hash(uploadId, fileName, fileSize, status, uploadedAt, errorMessage);
  }
}

/// Transcription result
class TranscriptionResult {
  final String transcriptionId;
  final String audioId;
  final String transcribedText;
  final double confidence;
  final TranscriptionStatus status;
  final DateTime? completedAt;
  final String? errorMessage;
  
  const TranscriptionResult({
    required this.transcriptionId,
    required this.audioId,
    required this.transcribedText,
    required this.confidence,
    required this.status,
    this.completedAt,
    this.errorMessage,
  });
  
  /// Create a copy with updated fields
  TranscriptionResult copyWith({
    String? transcriptionId,
    String? audioId,
    String? transcribedText,
    double? confidence,
    TranscriptionStatus? status,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return TranscriptionResult(
      transcriptionId: transcriptionId ?? this.transcriptionId,
      audioId: audioId ?? this.audioId,
      transcribedText: transcribedText ?? this.transcribedText,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'transcription_id': transcriptionId,
      'audio_id': audioId,
      'transcribed_text': transcribedText,
      'confidence': confidence,
      'status': status.name,
      'completed_at': completedAt?.toIso8601String(),
      'error_message': errorMessage,
    };
  }
  
  /// Create from JSON
  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      transcriptionId: json['transcription_id'] ?? json['id'] ?? '',
      audioId: json['audio_id'] ?? '',
      transcribedText: json['transcribed_text'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      status: TranscriptionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TranscriptionStatus.queued,
      ),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      errorMessage: json['error_message'],
    );
  }
  
  @override
  String toString() {
    return 'TranscriptionResult(transcriptionId: $transcriptionId, audioId: $audioId, status: $status)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptionResult &&
        other.transcriptionId == transcriptionId &&
        other.audioId == audioId &&
        other.transcribedText == transcribedText &&
        other.confidence == confidence &&
        other.status == status &&
        other.completedAt == completedAt &&
        other.errorMessage == errorMessage;
  }
  
  @override
  int get hashCode {
    return Object.hash(transcriptionId, audioId, transcribedText, confidence, status, completedAt, errorMessage);
  }
}

/// Upload progress information
class UploadProgress {
  final String uploadId;
  final int bytesUploaded;
  final int totalBytes;
  final double percentage;
  final UploadStatus status;
  
  const UploadProgress({
    required this.uploadId,
    required this.bytesUploaded,
    required this.totalBytes,
    required this.percentage,
    required this.status,
  });
  
  /// Create a copy with updated fields
  UploadProgress copyWith({
    String? uploadId,
    int? bytesUploaded,
    int? totalBytes,
    double? percentage,
    UploadStatus? status,
  }) {
    return UploadProgress(
      uploadId: uploadId ?? this.uploadId,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      totalBytes: totalBytes ?? this.totalBytes,
      percentage: percentage ?? this.percentage,
      status: status ?? this.status,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'upload_id': uploadId,
      'bytes_uploaded': bytesUploaded,
      'total_bytes': totalBytes,
      'percentage': percentage,
      'status': status.name,
    };
  }
  
  /// Create from JSON
  factory UploadProgress.fromJson(Map<String, dynamic> json) {
    return UploadProgress(
      uploadId: json['upload_id'] ?? '',
      bytesUploaded: json['bytes_uploaded'] ?? 0,
      totalBytes: json['total_bytes'] ?? 0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      status: UploadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => UploadStatus.pending,
      ),
    );
  }
  
  @override
  String toString() {
    return 'UploadProgress(uploadId: $uploadId, percentage: ${percentage.toStringAsFixed(1)}%, status: $status)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UploadProgress &&
        other.uploadId == uploadId &&
        other.bytesUploaded == bytesUploaded &&
        other.totalBytes == totalBytes &&
        other.percentage == percentage &&
        other.status == status;
  }
  
  @override
  int get hashCode {
    return Object.hash(uploadId, bytesUploaded, totalBytes, percentage, status);
  }
}

/// Audio validation result
class AudioValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic>? metadata;
  
  const AudioValidationResult({
    required this.isValid,
    this.errors = const [],
    this.metadata,
  });
  
  /// Create a valid result
  factory AudioValidationResult.valid({Map<String, dynamic>? metadata}) {
    return AudioValidationResult(isValid: true, metadata: metadata);
  }
  
  /// Create an invalid result with errors
  factory AudioValidationResult.invalid(List<String> errors) {
    return AudioValidationResult(isValid: false, errors: errors);
  }
  
  /// Create a copy with updated fields
  AudioValidationResult copyWith({
    bool? isValid,
    List<String>? errors,
    Map<String, dynamic>? metadata,
  }) {
    return AudioValidationResult(
      isValid: isValid ?? this.isValid,
      errors: errors ?? this.errors,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'is_valid': isValid,
      'errors': errors,
      'metadata': metadata,
    };
  }
  
  /// Create from JSON
  factory AudioValidationResult.fromJson(Map<String, dynamic> json) {
    return AudioValidationResult(
      isValid: json['is_valid'] ?? false,
      errors: List<String>.from(json['errors'] ?? []),
      metadata: json['metadata'],
    );
  }
  
  @override
  String toString() {
    return 'AudioValidationResult(isValid: $isValid, errors: ${errors.length})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioValidationResult &&
        other.isValid == isValid &&
        other.errors.length == errors.length &&
        other.errors.every((e) => errors.contains(e)) &&
        other.metadata == metadata;
  }
  
  @override
  int get hashCode {
    return Object.hash(isValid, errors, metadata);
  }
}