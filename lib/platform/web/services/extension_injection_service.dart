import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/ai/text_processing_service.dart';
import 'smart_inject_stub.dart' if (dart.library.js_interop) 'smart_inject_web.dart';

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
  /// Cleans the text by removing placeholders and attempts to inject it into the active Chrome tab.
  /// If injection fails or isn't possible (e.g., outside the web extension environment),
  /// it falls back to copying the cleaned text to the clipboard.
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

    // 3. Try Smart Inject (Web Extension Only)
    bool injected = false;
    if (kIsWeb) {
      injected = await performSmartInject(cleanText);

    }

    // 4. Determine final result
    if (injected) {
      return InjectionResult(
        status: InjectionStatus.success,
        message: "✅ Injected & Clean Copied",
      );
    } else {
       if (kIsWeb) {
           return InjectionResult(
            status: InjectionStatus.copiedOnly,
            message: "✅ Clean Text Copied (Injection failed)",
          );
       } else {
           return InjectionResult(
            status: InjectionStatus.copiedOnly,
            message: "✅ Clean Text Copied",
          );
       }
    }
  }
}






