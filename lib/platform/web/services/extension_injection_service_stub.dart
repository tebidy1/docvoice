import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/ai/text_processing_service.dart';

enum InjectionStatus {
  success,
  copiedOnly,
  failed,
}

class InjectionResult {
  final InjectionStatus status;
  final String message;

  InjectionResult({required this.status, required this.message});
}

class ExtensionInjectionService {
  /// Cleans the text by removing placeholders.
  /// No actual injection occurs on non-web platforms; it strictly falls back
  /// to copying the cleaned text to the clipboard.
  static Future<InjectionResult> smartCopyAndInject(String rawText) async {
    // 1. Clean the text (Filter placeholders)
    final cleanText = TextProcessingService.applySmartCopy(rawText);

    if (cleanText.isEmpty && rawText.isNotEmpty) {
      return InjectionResult(
        status: InjectionStatus.failed,
        message: "No clean text to copy. All lines appear to be placeholders.",
      );
    }
    
    if (cleanText.isEmpty) {
      return InjectionResult(
        status: InjectionStatus.failed,
        message: "Source text is empty.",
      );
    }

    // 2. Always copy Clean Text to Clipboard as a fallback/baseline
    try {
      await Clipboard.setData(ClipboardData(text: cleanText));
    } catch (e) {
      debugPrint("Clipboard copy failed: $e");
    }

    // Since this is the stub for non-web (or non-extension), injection is disabled.
    return InjectionResult(
      status: InjectionStatus.copiedOnly,
      message: "✅ Clean Text Copied",
    );
  }
}






