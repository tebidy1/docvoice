import 'package:flutter/material.dart';

class AppTheme {
  final String id;
  final String name;
  final bool isDark;
  
  // Container Styles
  final Color backgroundColor;
  final Color borderColor;
  final List<BoxShadow> shadows;
  final double borderRadius;

  // Standard Buttons
  final Color iconColor;
  final Color hoverColor;
  final Color dividerColor;

  // Hero Mic Button
  final Color micIdleBackground;
  final Color micIdleIcon;
  final Color micIdleBorder;
  final Color micRecordingBackground;
  final Color micRecordingIcon;
  final Color micRecordingBorder;

  // Drag Handle
  final Color dragHandleColor;

  const AppTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadows,
    required this.borderRadius,
    required this.iconColor,
    required this.hoverColor,
    required this.dividerColor,
    required this.micIdleBackground,
    required this.micIdleIcon,
    required this.micIdleBorder,
    required this.micRecordingBackground,
    required this.micRecordingIcon,
    required this.micRecordingBorder,
    required this.dragHandleColor,
  });

  // Presets
  static final AppTheme lightNative = AppTheme(
    id: 'light_native',
    name: 'Native Light',
    isDark: false,
    backgroundColor: const Color(0xFFFFFFFF), // White background
    borderColor: const Color(0xFFE2E8F0), // Light grey border
    shadows: [
      BoxShadow(
        color: const Color.fromRGBO(0, 0, 0, 0.05), // Soft shadow for depth
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    borderRadius: 8.0,
    iconColor: const Color(0xFF0A1C40), // Dark navy for text and icons
    hoverColor: const Color(0xFFF4F6F9), // Light grayish-blue for hover
    dividerColor: const Color(0xFFE2E8F0),
    micIdleBackground: const Color(0xFFFFFFFF),
    micIdleIcon: const Color(0xFF00A5FE), // Bright primary blue (Login Button Color)
    micIdleBorder: const Color(0xFFE2E8F0),
    micRecordingBackground: const Color(0xFFFF453A),
    micRecordingIcon: Colors.white,
    micRecordingBorder: const Color(0xFFFF453A),
    dragHandleColor: const Color(0xFF8A94A6), // Muted grey for subtle icons/handles
  );

  static final AppTheme slateDark = AppTheme(
    id: 'slate_dark',
    name: 'Slate Dark',
    isDark: true,
    backgroundColor: const Color(0xFF0F172A), // Slate 900
    borderColor: const Color(0xFF334155), // Slate 700
    shadows: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
    borderRadius: 8.0,
    iconColor: const Color(0xFFF1F5F9), // Slate 100
    hoverColor: const Color(0xFF1E293B), // Slate 800
    dividerColor: const Color(0xFF334155),
    micIdleBackground: const Color(0xFF1E293B),
    micIdleIcon: const Color(0xFF38BDF8), // Sky Blue
    micIdleBorder: const Color(0xFF334155),
    micRecordingBackground: const Color(0xFFEF4444), // Red 500
    micRecordingIcon: Colors.white,
    micRecordingBorder: const Color(0xFFEF4444),
    dragHandleColor: const Color(0xFF94A3B8), // Slate 400
  );

  static final AppTheme darkOnyx = AppTheme(
    id: 'dark_onyx',
    name: 'Dark Onyx',
    isDark: true,
    backgroundColor: const Color(0xFF202020),
    borderColor: const Color(0xFF454545),
    shadows: [
      BoxShadow(
        color: Colors.black.withOpacity(0.5),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
    borderRadius: 8.0,
    iconColor: const Color(0xFFE0E0E0),
    hoverColor: const Color(0xFF333333),
    dividerColor: const Color(0xFF404040),
    micIdleBackground: const Color(0xFF303030),
    micIdleIcon: const Color(0xFF64B5F6),
    micIdleBorder: const Color(0xFF505050),
    micRecordingBackground: const Color(0xFFFF453A),
    micRecordingIcon: Colors.white,
    micRecordingBorder: const Color(0xFFFF453A),
    dragHandleColor: const Color(0xFF808080),
  );
}
