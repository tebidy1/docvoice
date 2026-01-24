import 'package:flutter/material.dart';

// Stub for window_manager to allow web/mobile builds in the same codebase
class WindowManager {
  static final WindowManager instance = WindowManager();
  Future<void> ensureInitialized() async {}
  Future<void> waitUntilReadyToShow(WindowOptions options, VoidCallback callback) async {
    callback();
  }
  Future<void> setBackgroundColor(Color color) async {}
  Future<void> setResizable(bool resizable) async {}
  Future<void> show() async {}
  Future<void> focus() async {}
  Future<void> setSize(Size size) async {}
  Future<void> setPosition(Offset offset) async {}
  Future<void> center() async {}
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {}
  Future<void> setOpacity(double opacity) async {}
  Future<void> minimize() async {}
  Future<void> close() async {}
  Future<bool> isMaximized() async => false;
  Future<void> restore() async {}
  Future<void> maximize() async {}
  Future<Size> getSize() async => const Size(0, 0);
  Future<void> startDragging() async {}
}

final windowManager = WindowManager.instance;

class WindowOptions {
  final Size? size;
  final bool? center;
  final Color? backgroundColor;
  final bool? skipTaskbar;
  final TitleBarStyle? titleBarStyle;
  final bool? alwaysOnTop;

  const WindowOptions({
    this.size,
    this.center,
    this.backgroundColor,
    this.skipTaskbar,
    this.titleBarStyle,
    this.alwaysOnTop,
  });
}

enum TitleBarStyle { hidden, normal }
