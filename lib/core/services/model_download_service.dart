import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Service to download Whisper-Small.en ONNX INT8 model files on first launch.
/// Supports progress tracking and resume on failure.
class ModelDownloadService {
  static final ModelDownloadService _instance =
      ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  /// Base URL for model files (HuggingFace direct download)
  static const String _baseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small.en/resolve/main';

  /// Model files to download
  static const List<Map<String, String>> _modelFiles = [
    {
      'url': '$_baseUrl/small.en-encoder.int8.onnx',
      'filename': 'small.en-encoder.int8.onnx',
    },
    {
      'url': '$_baseUrl/small.en-decoder.int8.onnx',
      'filename': 'small.en-decoder.int8.onnx',
    },
    {
      'url': '$_baseUrl/small.en-tokens.txt',
      'filename': 'small.en-tokens.txt',
    },
  ];

  /// Returns the local model directory path.
  Future<String> get modelDir async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/whisper-small-en';
  }

  /// Check if all model files are already downloaded.
  Future<bool> isModelReady() async {
    final dir = await modelDir;
    for (final file in _modelFiles) {
      final f = File('$dir/${file['filename']}');
      if (!await f.exists() || await f.length() == 0) {
        return false;
      }
    }
    return true;
  }

  /// Download all model files with progress callback.
  /// [onProgress] receives (downloadedBytes, totalBytes, currentFileName).
  Future<void> downloadModel({
    required void Function(int downloaded, int total, String fileName)
        onProgress,
  }) async {
    final dir = await modelDir;
    final modelDirFile = Directory(dir);
    if (!await modelDirFile.exists()) {
      await modelDirFile.create(recursive: true);
    }

    // Calculate total size by doing HEAD requests first
    int totalSize = 0;
    final List<int> fileSizes = [];
    for (final file in _modelFiles) {
      try {
        final headResponse =
            await http.head(Uri.parse(file['url']!)).timeout(
                  const Duration(seconds: 15),
                );
        final size =
            int.tryParse(headResponse.headers['content-length'] ?? '0') ?? 0;
        fileSizes.add(size);
        totalSize += size;
      } catch (e) {
        fileSizes.add(0);
        debugPrint('⚠️ HEAD request failed for ${file['filename']}: $e');
      }
    }

    int downloadedSoFar = 0;

    for (int i = 0; i < _modelFiles.length; i++) {
      final file = _modelFiles[i];
      final destPath = '$dir/${file['filename']}';
      final destFile = File(destPath);

      // Skip if already downloaded and non-empty
      if (await destFile.exists() && await destFile.length() > 0) {
        final existingSize = await destFile.length();
        downloadedSoFar += existingSize;
        onProgress(downloadedSoFar, totalSize, file['filename']!);
        debugPrint(
            '✅ ${file['filename']} already exists (${(existingSize / 1024 / 1024).toStringAsFixed(1)} MB)');
        continue;
      }

      debugPrint('📥 Downloading ${file['filename']}...');
      onProgress(downloadedSoFar, totalSize, file['filename']!);

      try {
        final request = http.Request('GET', Uri.parse(file['url']!));
        final response = await http.Client().send(request);

        if (response.statusCode != 200) {
          throw HttpException(
              'Failed to download ${file['filename']}: HTTP ${response.statusCode}');
        }

        final sink = destFile.openWrite();
        int fileDownloaded = 0;

        await for (final chunk in response.stream) {
          sink.add(chunk);
          fileDownloaded += chunk.length;
          downloadedSoFar += chunk.length;
          onProgress(downloadedSoFar, totalSize, file['filename']!);
        }

        await sink.flush();
        await sink.close();

        debugPrint(
            '✅ ${file['filename']} downloaded (${(fileDownloaded / 1024 / 1024).toStringAsFixed(1)} MB)');
      } catch (e) {
        // Delete partial file on error
        if (await destFile.exists()) {
          await destFile.delete();
        }
        debugPrint('❌ Error downloading ${file['filename']}: $e');
        rethrow;
      }
    }

    debugPrint('🎉 All model files downloaded successfully!');
  }

  /// Delete all downloaded model files (for re-download or cleanup).
  Future<void> deleteModel() async {
    final dir = await modelDir;
    final modelDirFile = Directory(dir);
    if (await modelDirFile.exists()) {
      await modelDirFile.delete(recursive: true);
    }
  }
}
