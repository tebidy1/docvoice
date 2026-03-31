import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Explicit import
import 'package:screen_retriever/screen_retriever.dart';
import 'package:soutnote/utils/window_manager_stub.dart';

class WindowManagerHelper {
  static const double sidebarWidth = 400.0;

  /// Expands window to sidebar mode and docks to right with full height
  static Future<void> expandToSidebar(BuildContext context) async {
    if (kIsWeb) return; // Web Guard
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenSize = primaryDisplay.size;
      // Provide a reasonable max height, leaving space for top hospital system headers
      final height = screenSize.height * 0.75; // 75% of screen height
      await windowManager.setSize(Size(sidebarWidth, height));
      
      // Position at bottom-right edge, avoiding taskbar
      final x = screenSize.width - sidebarWidth - 20; // 20px padding from right
      final y = screenSize.height - height - 80; // 80px padding from bottom
      await windowManager.setPosition(Offset(x, y));
    } catch (e) {
      print("Error expanding to sidebar: $e");
    }
  }

  /// Collapses window back to pill mode and centers on right edge
  static Future<void> collapseToPill(BuildContext context) async {
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenSize = primaryDisplay.size;
      const pillWidth = 350.0; // Native Utility Width
      const pillHeight = 56.0; // Native Utility Height
      
      // Shrink to pill size
      try {
        await windowManager.setResizable(true); // Temporarily allow resize
        await windowManager.setSize(const Size(pillWidth, pillHeight));
        await windowManager.setResizable(false); // Lock it back
      } catch (e) { print(e); }
      // Position at bottom-right (leaving margin for taskbar and edge)
      final x = screenSize.width - pillWidth - 20; // 20px padding from right
      final y = screenSize.height - pillHeight - 80; // 80px padding from bottom to avoid taskbar
      await windowManager.setPosition(Offset(x, y));
    } catch (e) {
      print("Error collapsing to pill: $e");
    }
  }

  /// Docks the window to the right side of the screen, centered vertically
  static Future<void> dockToRight(BuildContext context) async {
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenSize = primaryDisplay.size;
      final windowSize = await windowManager.getSize();
      
      final x = screenSize.width - windowSize.width;
      final y = (screenSize.height - windowSize.height) / 2;
      
      await windowManager.setPosition(Offset(x, y));
    } catch (e) {
      print("Error docking to right: $e");
    }
  }

  /// Restores the window to a dialog size and places it on the bottom right
  static Future<void> centerDialog() async {
    await expandToCustomSizeBottomRight(900, 700);
    await windowManager.setAlwaysOnTop(false);
  }

  /// Expands to a custom size but keeps it aligned bottom-right like the sidebar and pill
  static Future<void> expandToCustomSizeBottomRight(double width, double height) async {
    if (kIsWeb) return;
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenSize = primaryDisplay.size;
      
      await windowManager.setSize(Size(width, height));
      
      final x = screenSize.width - width - 20; // 20px padding from right
      final y = screenSize.height - height - 80; // 80px padding from bottom
      await windowManager.setPosition(Offset(x, y));
    } catch (e) {
      print("Error expanding: $e");
    }
  }

  static bool _isTransparencyLocked = false;

  /// Locks opacity to 1.0 (prevent dimming)
  static void setTransparencyLocked(bool locked) {
    _isTransparencyLocked = locked;
    if (locked) {
      setOpacity(1.0); // Enforce full visibility immediately
    }
  }

  /// Sets the window opacity (unless locked)
  static Future<void> setOpacity(double opacity) async {
    if (_isTransparencyLocked && opacity < 1.0) return; // Prevent dimming if locked
    await windowManager.setOpacity(opacity);
  }
}
