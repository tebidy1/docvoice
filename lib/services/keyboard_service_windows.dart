import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class KeyboardService {
  /// Types the given [text] into the currently active window.
  /// Now uses PASTE method for maximum reliability.
  Future<void> typeText(String text) async {
    print("KeyboardService: Inserting ${text.length} characters via paste...");
    await pasteText(text);
    print("KeyboardService: Insert complete.");
  }

  void _sendChunk(String chunk) {
    final kInputs = calloc<INPUT>(chunk.length * 2);

    try {
      for (var i = 0; i < chunk.length; i++) {
        final charCode = chunk.codeUnitAt(i);

        // Key Down
        final inputDown = kInputs[2 * i];
        inputDown.type = INPUT_KEYBOARD;
        inputDown.ki.wVk = 0;
        inputDown.ki.wScan = charCode;
        inputDown.ki.dwFlags = KEYEVENTF_UNICODE;

        // Key Up
        final inputUp = kInputs[2 * i + 1];
        inputUp.type = INPUT_KEYBOARD;
        inputUp.ki.wVk = 0;
        inputUp.ki.wScan = charCode;
        inputUp.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
      }

      final result = SendInput(chunk.length * 2, kInputs, sizeOf<INPUT>());
      if (result != chunk.length * 2) {
        print("SendInput failed. Sent $result of ${chunk.length * 2} events.");
      }
    } finally {
      calloc.free(kInputs);
    }
  }

  /// Pastes the given [text] into the currently active window using Clipboard and Ctrl+V.
  Future<void> pasteText(String text) async {
    print("KeyboardService: Setting clipboard...");
    
    // 1. Copy to Clipboard
    await Clipboard.setData(ClipboardData(text: text));
    
    // Wait longer for clipboard to be ready
    await Future.delayed(const Duration(milliseconds: 300));
    
    print("KeyboardService: Simulating Ctrl+V...");
    
    // 2. Simulate Ctrl + V with delays between each event
    try {
      // Ctrl Down
      final ctrlDown = calloc<INPUT>(1);
      ctrlDown[0].type = INPUT_KEYBOARD;
      ctrlDown[0].ki.wVk = 0xA2; // VK_LCONTROL
      ctrlDown[0].ki.dwFlags = 0;
      SendInput(1, ctrlDown, sizeOf<INPUT>());
      calloc.free(ctrlDown);
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // V Down
      final vDown = calloc<INPUT>(1);
      vDown[0].type = INPUT_KEYBOARD;
      vDown[0].ki.wVk = 0x56; // V key
      vDown[0].ki.dwFlags = 0;
      SendInput(1, vDown, sizeOf<INPUT>());
      calloc.free(vDown);
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // V Up
      final vUp = calloc<INPUT>(1);
      vUp[0].type = INPUT_KEYBOARD;
      vUp[0].ki.wVk = 0x56;
      vUp[0].ki.dwFlags = KEYEVENTF_KEYUP;
      SendInput(1, vUp, sizeOf<INPUT>());
      calloc.free(vUp);
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Ctrl Up
      final ctrlUp = calloc<INPUT>(1);
      ctrlUp[0].type = INPUT_KEYBOARD;
      ctrlUp[0].ki.wVk = 0xA2; // VK_LCONTROL
      ctrlUp[0].ki.dwFlags = KEYEVENTF_KEYUP;
      SendInput(1, ctrlUp, sizeOf<INPUT>());
      calloc.free(ctrlUp);
      
      print("KeyboardService: Ctrl+V sent successfully.");
      
      // Wait for paste to complete
      await Future.delayed(const Duration(milliseconds: 200));
      
    } catch (e) {
      print("KeyboardService: Error during paste: $e");
    }
  }
}
