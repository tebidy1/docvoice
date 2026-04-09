import 'dart:io';
import 'package:flutter/services.dart';

import 'windows_injector.dart' as win;
import 'mac_injector.dart' as mac;

/// Cross-platform entry point for desktop text injection.
/// - Windows: uses low-level keyboard injection (Ctrl+V/typewriter).
/// - macOS: uses clipboard + Command+V via AppleScript (requires Accessibility permission).
/// - Other platforms: copies to clipboard only.
class DesktopInjector {
  static final DesktopInjector instance = DesktopInjector._internal();
  DesktopInjector._internal();

  Future<void> copyOnly(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> copyAndInject(String text) async {
    if (Platform.isWindows) {
      return win.WindowsInjector().smartInject(text);
    }
    if (Platform.isMacOS) {
      return mac.copyAndPaste(text);
    }
    return copyOnly(text);
  }
}
