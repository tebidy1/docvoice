import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class MedTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark, // Dark Mode
      primaryColor: MedColors.primary,
      scaffoldBackgroundColor: MedColors.background,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: MedColors.primary,
        secondary: MedColors.accent,
        surface: MedColors.surface,
        error: MedColors.error,
        onPrimary: Colors.black, // Dark text on light blue primary
        onSurface: MedColors.textMain,
        background: MedColors.background,
      ),
      
      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.cairo(
          fontSize: 56, // Increased from 44
          fontWeight: FontWeight.bold,
          height: 1.25,
          color: MedColors.textMain,
        ),
        displayMedium: GoogleFonts.cairo(
          fontSize: 42, // Increased from 32
          fontWeight: FontWeight.bold,
          height: 1.3,
          color: MedColors.textMain,
        ),
        headlineMedium: GoogleFonts.cairo(
          fontSize: 32, // Increased from 24
          fontWeight: FontWeight.bold,
          height: 1.35,
          color: MedColors.textMain,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.8, // Increased from 1.7
          color: MedColors.textMain,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.8, // Increased from 1.6
          color: MedColors.textMain,
        ),
        labelSmall: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          height: 1.6,
          color: MedColors.textMicro,
        ),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MedColors.primary,
          foregroundColor: Colors.white, // Keep white for contrast on blue
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MedColors.primary,
          side: const BorderSide(color: MedColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
