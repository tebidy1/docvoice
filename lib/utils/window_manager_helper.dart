import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

class WindowManagerHelper {
  static const double sidebarWidth = 400.0;

  /// Expands window to sidebar mode and docks to right with full height
  static Future<void> expandToSidebar(BuildContext context) async {
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenSize = primaryDisplay.size;
      
      // Expand to full sidebar dimensions
      final height = screenSize.height - 60; // Account for taskbar
      await windowManager.setSize(Size(sidebarWidth, height));
      
      // Position at right edge, top aligned
      final x = screenSize.width - sidebarWidth;
      await windowManager.setPosition(Offset(x, 0));
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
      
      // Position at right-center
      final x = screenSize.width - pillWidth - 10;
      final y = (screenSize.height - pillHeight) / 2;
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

  /// Restores the window to a centered dialog size (for Macro Manager etc)
  static Future<void> centerDialog() async {
    await windowManager.setSize(const Size(900, 700));
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false);
  }

  /// Sets the window opacity
  static Future<void> setOpacity(double opacity) async {
    await windowManager.setOpacity(opacity);
  }
}
