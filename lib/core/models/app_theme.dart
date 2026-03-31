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

  // Semantic Colors
  final Color successColor;
  final Color draftColor;
  final Color accentColor;
  final Color recordRedColor;

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
    required this.successColor,
    required this.draftColor,
    required this.accentColor,
    required this.recordRedColor,
  });

  // Presets
  static final AppTheme lightNative = AppTheme(
    id: 'light_native',
    name: 'Native Light',
    isDark: false,
    backgroundColor: const Color(0xFFF3F3F3),
    borderColor: const Color(0xFF8E9093),
    shadows: [
      BoxShadow(
        color: const Color.fromRGBO(0, 0, 0, 0.15),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    borderRadius: 8.0,
    iconColor: const Color(0xFF444746),
    hoverColor: const Color(0xFFE0E0E0),
    dividerColor: const Color(0xFFC0C0C0),
    micIdleBackground: const Color(0xFFFFFFFF),
    micIdleIcon: const Color(0xFF4A90E2),
    micIdleBorder: const Color(0xFFD1D1D1),
    micRecordingBackground: const Color(0xFFFF5252),
    micRecordingIcon: Colors.white,
    micRecordingBorder: const Color(0xFFFF5252),
    dragHandleColor: const Color(0xFF444746),
    successColor: const Color(0xFF2E7D32), // Material Green 800
    draftColor: const Color(0xFFF57C00), // Material Orange 800
    accentColor: const Color(0xFF1976D2), // Material Blue 700
    recordRedColor: const Color(0xFFD32F2F), // Material Red 700
  );

  static final AppTheme slateDark = AppTheme(
    id: 'slate_dark',
    name: 'Slate Dark',
    isDark: true,
    backgroundColor: const Color(0xFF0F172A),
    borderColor: const Color(0xFF334155),
    shadows: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
    borderRadius: 8.0,
    iconColor: const Color(0xFFF1F5F9),
    hoverColor: const Color(0xFF1E293B),
    dividerColor: const Color(0xFF334155),
    micIdleBackground: const Color(0xFF1E293B),
    micIdleIcon: const Color(0xFF38BDF8),
    micIdleBorder: const Color(0xFF334155),
    micRecordingBackground: const Color(0xFFEF4444),
    micRecordingIcon: Colors.white,
    micRecordingBorder: const Color(0xFFEF4444),
    dragHandleColor: const Color(0xFF94A3B8),
    successColor: const Color(0xFF32D74B), // Legacy successGreen
    draftColor: const Color(0xFFFFD60A), // Legacy draftYellow
    accentColor: const Color(0xFF0A84FF), // Legacy accent (iOS Blue)
    recordRedColor: const Color(0xFFFF453A), // Legacy recordRed
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
    successColor: const Color(0xFF32D74B),
    draftColor: const Color(0xFFFFD60A),
    accentColor: const Color(0xFF0A84FF),
    recordRedColor: const Color(0xFFFF453A),
  );
}
