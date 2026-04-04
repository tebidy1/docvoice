import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart';

class KeyboardService {
  /// Types the given [text] into the currently active window.
  /// Now uses PASTE method for maximum reliability.
  Future<void> typeText(String text) async {
    print("KeyboardService: Inserting ${text.length} characters via paste...");
    await pasteText(text);
    print("KeyboardService: Insert complete.");
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


