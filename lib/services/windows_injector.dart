import 'dart:ffi';
import 'dart:io';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart';

import 'package:window_manager/window_manager.dart';

// Helper class for Windows Injection (Paste/Type)
class WindowsInjector {
  // Singleton
  static final WindowsInjector _instance = WindowsInjector._internal();
  factory WindowsInjector() => _instance;
  WindowsInjector._internal();

  /// Level 1: Just copy to clipboard (Manual)
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    // Clear buffer to ensure clean state
  }

  /// Level 2: Smart Paste (Ctrl+V)
  /// Focuses the previous window and sends Ctrl+V
  Future<void> injectViaPaste(String text) async {
    // 1. Minimize our app to reveal the EMR/Target Window behind
    await windowManager.minimize();
    
    // 2. Copy to Clipboard
    await copyToClipboard(text);

    // 3. Add delay to allow minimize animation/focus switch (critical)
    await Future.delayed(const Duration(milliseconds: 300));

    // 4. Send Ctrl+V
    _sendCtrlV();
  }

  /// Level 3: Typewriter (Simulate Keystrokes)
  /// Useful for fields that block Paste
  Future<void> injectViaTypewriter(String text, {int delayMs = 10}) async {
    // Focus is assumed to be on the target window already (user clicked input)
    // Or we actively restore focus if we stole it. 
    // Usually, this runs while App is minimized/hidden.

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      _sendToInput(char);
      if (delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  void _sendCtrlV() {
    final inputs = calloc<INPUT>(4);

    // Press Ctrl
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;
    
    // Press V
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 0x56; // V key

    // Release V
    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = 0x56;
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

    // Release Ctrl
    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

    SendInput(4, inputs, sizeOf<INPUT>());
    calloc.free(inputs);
  }

  void _sendToInput(String char) {
    // Unicode handling
    final inputs = calloc<INPUT>(2);
    
    // Get UTF-16 code unit
    final codeUnit = char.codeUnitAt(0);

    // Key Down (Unicode)
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wScan = codeUnit;
    inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;

    // Key Up (Unicode)
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wScan = codeUnit;
    inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

    SendInput(2, inputs, sizeOf<INPUT>());
    calloc.free(inputs);
  }
}
