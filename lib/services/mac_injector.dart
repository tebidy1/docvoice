import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Minimal macOS injector: copy to clipboard, blur to previous app, send Cmd+V.
/// Requires the app to have Accessibility permission to send keystrokes.
Future<void> copyAndPaste(String text) async {
  final prefs = await SharedPreferences.getInstance();
  final copyOnly = prefs.getBool('mac_copy_only_inject') ?? false;

  await Clipboard.setData(ClipboardData(text: text));

  if (copyOnly) {
    return; // user prefers manual paste
  }

  // Let the OS regain focus to the last active window.
  try {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.blur();
    await Future.delayed(const Duration(milliseconds: 400));
  } catch (_) {}

  // Fire Cmd+V using AppleScript (System Events).
  try {
    await Process.run('osascript', [
      '-e',
      'tell application "System Events" to keystroke "v" using {command down}'
    ]);
  } catch (_) {}

  // Optional: re-pin window if caller was floating.
  try {
    await windowManager.setAlwaysOnTop(true);
  } catch (_) {}
}
