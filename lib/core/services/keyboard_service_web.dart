import 'package:flutter/services.dart';

/// Web implementation of KeyboardService
/// On web, we can only use the clipboard directly
class KeyboardService {
  /// On web, we can only set clipboard data
  /// User must manually paste (Ctrl+V) themselves
  Future<void> typeText(String text) async {
    print("KeyboardService (Web): Setting clipboard...");
    await Clipboard.setData(ClipboardData(text: text));
    print("KeyboardService (Web): Text copied to clipboard. User can paste with Ctrl+V.");
  }

  /// Same as typeText on web - just copies to clipboard
  Future<void> pasteText(String text) async {
    await typeText(text);
  }
}
