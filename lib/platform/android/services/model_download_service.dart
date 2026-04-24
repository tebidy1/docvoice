import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Service to download Whisper-Small.en ONNX INT8 model files on demand.
/// Supports progress tracking and skips already-downloaded files.
class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  /// Base URL for model files (HuggingFace direct download)
  static const String _baseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small.en/resolve/main';

  /// Model files to download (in order: smallest first for faster initial check)
  static const List<Map<String, String>> modelFiles = [
    {
      'url': '$_baseUrl/small.en-tokens.txt',
      'filename': 'small.en-tokens.txt',
      'sizeMb': '0.8',
    },
    {
      'url': '$_baseUrl/small.en-encoder.int8.onnx',
      'filename': 'small.en-encoder.int8.onnx',
      'sizeMb': '107',
    },
    {
      'url': '$_baseUrl/small.en-decoder.int8.onnx',
      'filename': 'small.en-decoder.int8.onnx',
      'sizeMb': '250',
    },
  ];

  /// Returns the local model directory path.
  Future<String> get modelDir async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/whisper-small-en';
  }

  /// Check if all model files are already downloaded and non-empty.
  Future<bool> isModelReady() async {
    final dir = await modelDir;
    for (final file in modelFiles) {
      final f = File('$dir/${file['filename']}');
      if (!await f.exists() || await f.length() == 0) {
        return false;
      }
    }
    return true;
  }

  /// Returns how many files out of total are already downloaded.
  Future<String> getModelStatusText() async {
    final dir = await modelDir;
    int ready = 0;
    for (final file in modelFiles) {
      final f = File('$dir/${file['filename']}');
      if (await f.exists() && await f.length() > 0) ready++;
    }
    if (ready == modelFiles.length) return 'Ready';
    if (ready == 0) return 'Not Downloaded (~358 MB)';
    return 'Partial ($ready/${modelFiles.length} files)';
  }

  /// Download all model files with progress callback.
  /// [onProgress] receives (downloadedBytes, totalBytes, currentFileName).
  Future<void> downloadModel({
    required void Function(int downloaded, int total, String fileName) onProgress,
  }) async {
    final dir = await modelDir;
    final modelDirFile = Directory(dir);
    if (!await modelDirFile.exists()) {
      await modelDirFile.create(recursive: true);
    }

    // Calculate total size via HEAD requests
    int totalSize = 0;
    final List<int> fileSizes = [];
    for (final file in modelFiles) {
      try {
        final headResponse = await http.head(Uri.parse(file['url']!)).timeout(
          const Duration(seconds: 15),
        );
        final size =
            int.tryParse(headResponse.headers['content-length'] ?? '0') ?? 0;
        fileSizes.add(size);
        totalSize += size;
      } catch (e) {
        // Fallback to estimated size if HEAD fails
        final estimatedMb = double.tryParse(file['sizeMb'] ?? '0') ?? 0;
        final estimated = (estimatedMb * 1024 * 1024).toInt();
        fileSizes.add(estimated);
        totalSize += estimated;
        debugPrint('⚠️ HEAD request failed for ${file['filename']}: $e');
      }
    }

    // If we got no size at all, use a rough fallback
    if (totalSize == 0) totalSize = 376 * 1024 * 1024; // ~376MB

    int downloadedSoFar = 0;

    for (int i = 0; i < modelFiles.length; i++) {
      final file = modelFiles[i];
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
        // Delete partial file on error so it can be retried
        if (await destFile.exists()) {
          await destFile.delete();
        }
        debugPrint('❌ Error downloading ${file['filename']}: $e');
        rethrow;
      }
    }

    debugPrint('🎉 All model files downloaded successfully!');
  }

  /// Delete all downloaded model files (for cleanup or re-download).
  Future<void> deleteModel() async {
    final dir = await modelDir;
    final modelDirFile = Directory(dir);
    if (await modelDirFile.exists()) {
      await modelDirFile.delete(recursive: true);
    }
    debugPrint('🗑️ Model files deleted.');
  }
}






