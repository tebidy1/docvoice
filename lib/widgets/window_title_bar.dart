import 'package:flutter/material.dart';
import '../utils/window_manager_proxy.dart';
import 'window_controls.dart';

class WindowTitleBar extends StatelessWidget {
  final String title;
  final Widget? centerWidget;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;

  const WindowTitleBar({
    super.key,
    required this.title,
    this.centerWidget,
    this.actions,
    this.backgroundColor,
    this.textColor,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(0xFF1E293B).withOpacity(0.8);
    final txtColor = textColor ?? Colors.grey[400]!;
    final barHeight = height ?? 32.0;

    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        height: barHeight,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side - Title and drag area
            Expanded(
              child: GestureDetector(
                onPanStart: (details) {
                  windowManager.startDragging();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.drag_indicator,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          color: txtColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Center - Optional widget
            if (centerWidget != null)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Prevent window dragging when clicking on center widget
                  child: centerWidget!,
                ),
              ),
            // Right side - Actions and Window controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actions != null) ...actions!,
                const WindowControls(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

