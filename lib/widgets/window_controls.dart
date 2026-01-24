import 'package:flutter/material.dart';
import '../utils/window_manager_proxy.dart';

class WindowControls extends StatefulWidget {
  final Color? backgroundColor;
  final Color? iconColor;
  final double? height;

  const WindowControls({
    super.key,
    this.backgroundColor,
    this.iconColor,
    this.height,
  });

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  bool _isMinimizeHovered = false;
  bool _isMaximizeHovered = false;
  bool _isCloseHovered = false;

  Future<void> _minimizeWindow() async {
    await windowManager.minimize();
  }

  Future<void> _maximizeWindow() async {
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.restore();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> _closeWindow() async {
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? const Color(0xFF1E293B).withOpacity(0.8);
    final iconColor = widget.iconColor ?? Colors.grey[400]!;
    final height = widget.height ?? 32.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimize button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isMinimizeHovered = true),
            onExit: (_) => setState(() => _isMinimizeHovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _minimizeWindow,
              child: Container(
                width: 46,
                height: height,
                color: _isMinimizeHovered
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
                child: Icon(
                  Icons.remove,
                  color: iconColor,
                  size: 18,
                ),
              ),
            ),
          ),
          // Maximize/Restore button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isMaximizeHovered = true),
            onExit: (_) => setState(() => _isMaximizeHovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _maximizeWindow,
              child: Container(
                width: 46,
                height: height,
                color: _isMaximizeHovered
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
                child: FutureBuilder<bool>(
                  future: windowManager.isMaximized(),
                  builder: (context, snapshot) {
                    final isMaximized = snapshot.data ?? false;
                    return Icon(
                      isMaximized ? Icons.filter_none : Icons.crop_square,
                      color: iconColor,
                      size: 16,
                    );
                  },
                ),
              ),
            ),
          ),
          // Close button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isCloseHovered = true),
            onExit: (_) => setState(() => _isCloseHovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeWindow,
              child: Container(
                width: 46,
                height: height,
                color: _isCloseHovered
                    ? Colors.red.withOpacity(0.2)
                    : Colors.transparent,
                child: Icon(
                  Icons.close,
                  color: _isCloseHovered ? Colors.red[300] : iconColor,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

