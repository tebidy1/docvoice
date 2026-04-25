/// API response models for ScribeFlow backend integration
///
/// This file contains all the models related to API communication,
/// including response wrappers, error models, and authentication results.

import 'package:soutnote/core/entities/user.dart';
import 'package:soutnote/core/mappers/user_mapper.dart';

final _userMapper = UserMapper();

/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final List<String>? errors;
  final int? statusCode;
  final Map<String, dynamic>? meta;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errors,
    this.statusCode,
    this.meta,
  });

  /// Create a successful response
  factory ApiResponse.success(T data,
      {String? message, Map<String, dynamic>? meta}) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
      meta: meta,
    );
  }

  /// Create an error response
  factory ApiResponse.error(
    String message, {
    List<String>? errors,
    int? statusCode,
    Map<String, dynamic>? meta,
  }) {
    return ApiResponse(
      success: false,
      message: message,
      errors: errors,
      statusCode: statusCode,
      meta: meta,
    );
  }

  /// Create from JSON response
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] ?? true,
      data: fromJsonT != null && json['data'] != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      message: json['message']?.toString(),
      errors: json['errors'] != null ? List<String>.from(json['errors']) : null,
      statusCode: json['status_code']?.toInt(),
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data,
      'message': message,
      'errors': errors,
      'status_code': statusCode,
      'meta': meta,
    };
  }

  @override
  String toString() {
    return 'ApiResponse(success: $success, message: $message, statusCode: $statusCode)';
  }
}

/// Authentication result model
class AuthResult {
  final bool success;
  final User? user;
  final String? token;
  final String? refreshToken;
  final String? message;
  final List<String>? errors;
  final DateTime? expiresAt;

  const AuthResult({
    required this.success,
    this.user,
    this.token,
    this.refreshToken,
    this.message,
    this.errors,
    this.expiresAt,
  });

  /// Create a successful authentication result
  factory AuthResult.success(
    User user,
    String token, {
    String? refreshToken,
    DateTime? expiresAt,
    String? message,
  }) {
    return AuthResult(
      success: true,
      user: user,
      token: token,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      message: message,
    );
  }

  /// Create a failed authentication result
  factory AuthResult.failure(String message, {List<String>? errors}) {
    return AuthResult(
      success: false,
      message: message,
      errors: errors,
    );
  }

  /// Create from JSON response
  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      success: json['success'] ?? false,
      user: json['user'] != null ? _userMapper.fromJson(json['user']) : null,
      token: json['token']?.toString(),
      refreshToken: json['refresh_token']?.toString(),
      message: json['message']?.toString(),
      errors: json['errors'] != null ? List<String>.from(json['errors']) : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'user': user != null ? _userMapper.toJson(user!) : null,
      'token': token,
      'refresh_token': refreshToken,
      'message': message,
      'errors': errors,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AuthResult(success: $success, message: $message)';
  }
}

/// File upload result model
class FileUploadResult {
  final String id;
  final String fileName;
  final String originalName;
  final String mimeType;
  final int fileSize;
  final String url;
  final DateTime uploadedAt;
  final Map<String, dynamic>? metadata;

  const FileUploadResult({
    required this.id,
    required this.fileName,
    required this.originalName,
    required this.mimeType,
    required this.fileSize,
    required this.url,
    required this.uploadedAt,
    this.metadata,
  });

  /// Create from JSON
  factory FileUploadResult.fromJson(Map<String, dynamic> json) {
    return FileUploadResult(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      fileSize: json['file_size']?.toInt() ?? 0,
      url: json['url']?.toString() ?? '',
      uploadedAt: DateTime.parse(
          json['uploaded_at'] ?? DateTime.now().toIso8601String()),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'original_name': originalName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'url': url,
      'uploaded_at': uploadedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'FileUploadResult(id: $id, fileName: $fileName, url: $url)';
  }
}

/// File upload progress model
class FileUploadProgress {
  final String uploadId;
  final double progress; // 0.0 to 1.0
  final int bytesUploaded;
  final int totalBytes;
  final String status;
  final String? errorMessage;

  const FileUploadProgress({
    required this.uploadId,
    required this.progress,
    required this.bytesUploaded,
    required this.totalBytes,
    required this.status,
    this.errorMessage,
  });

  /// Check if upload is complete
  bool get isComplete => progress >= 1.0 && status == 'completed';

  /// Check if upload failed
  bool get isFailed => status == 'failed' || errorMessage != null;

  /// Check if upload is in progress
  bool get isInProgress => status == 'uploading' && progress < 1.0;

  @override
  String toString() {
    return 'FileUploadProgress(uploadId: $uploadId, progress: ${(progress * 100).toStringAsFixed(1)}%, status: $status)';
  }
}

/// Push notification model
class PushNotification {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime receivedAt;
  final String? imageUrl;
  final String? actionUrl;

  const PushNotification({
    required this.id,
    required this.title,
    required this.body,
    this.data,
    required this.receivedAt,
    this.imageUrl,
    this.actionUrl,
  });

  /// Create from JSON
  factory PushNotification.fromJson(Map<String, dynamic> json) {
    return PushNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: json['data'] as Map<String, dynamic>?,
      receivedAt: DateTime.parse(
          json['received_at'] ?? DateTime.now().toIso8601String()),
      imageUrl: json['image_url']?.toString(),
      actionUrl: json['action_url']?.toString(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'received_at': receivedAt.toIso8601String(),
      'image_url': imageUrl,
      'action_url': actionUrl,
    };
  }

  @override
  String toString() {
    return 'PushNotification(id: $id, title: $title)';
  }
}
