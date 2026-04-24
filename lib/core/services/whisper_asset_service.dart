/// ============================================================
/// WhisperAssetService — Extracts the GGML model on first run
/// ============================================================
/// Copies the bundled ggml-small.en-q5_0.bin (~180MB) from
/// Flutter assets to the Application Documents directory.
/// Verifies extracted file size > 170,000,000 bytes.
/// ============================================================

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class WhisperAssetService {
  static const String _modelAssetPath = 'assets/models/ggml-small.en-q5_1.bin';
  static const String _modelFileName = 'ggml-small.en-q5_1.bin';
  static const int _minimumModelSizeBytes = 170000000; // ~170MB

  /// Returns the absolute path to the extracted model file.
  /// If the model hasn't been extracted yet, extracts it first.
  /// Throws an exception if extraction or verification fails.
  static Future<String> getModelPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDocDir.path}${Platform.pathSeparator}soutnote${Platform.pathSeparator}$_modelFileName');

    // Check if model already exists and is valid
    if (await modelFile.exists()) {
      final fileSize = await modelFile.length();
      if (fileSize > _minimumModelSizeBytes) {
        print('[WhisperAsset] Model already extracted: ${modelFile.path} (${(fileSize / 1048576).toStringAsFixed(1)} MB)');
        return modelFile.path;
      } else {
        // Corrupted or incomplete — delete and re-extract
        print('[WhisperAsset] Model file corrupted (${fileSize} bytes). Re-extracting...');
        await modelFile.delete();
      }
    }

    // Ensure directory exists
    final dir = modelFile.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Extract from assets
    print('[WhisperAsset] Extracting model from assets...');
    try {
      final byteData = await rootBundle.load(_modelAssetPath);
      final buffer = byteData.buffer;
      await modelFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );

      // Verify size after extraction
      final extractedSize = await modelFile.length();
      if (extractedSize <= _minimumModelSizeBytes) {
        await modelFile.delete();
        throw Exception(
          'Extracted model verification failed: size=$extractedSize bytes (expected > $_minimumModelSizeBytes)',
        );
      }

      print('[WhisperAsset] Model extracted successfully: ${(extractedSize / 1048576).toStringAsFixed(1)} MB');
      return modelFile.path;
    } catch (e) {
      // Clean up partial file
      if (await modelFile.exists()) {
        await modelFile.delete();
      }
      rethrow;
    }
  }

  /// Checks if the model is already extracted and valid.
  static Future<bool> isModelReady() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDocDir.path}${Platform.pathSeparator}soutnote${Platform.pathSeparator}$_modelFileName');
      if (!await modelFile.exists()) return false;
      final fileSize = await modelFile.length();
      return fileSize > _minimumModelSizeBytes;
    } catch (_) {
      return false;
    }
  }
}






