import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF000000); // Pure OLED Black
  static const Color surface = Color(0xFF121212); // Secondary Surface
  static const Color primary = Color(0xFFE0E0E0); // White/Grey text
  static const Color recordRed = Color(0xFFFF453A);
  static const Color successGreen = Color(0xFF32D74B);
  static const Color draftYellow = Color(0xFFFFD60A);
  
  static const Color accent = Color(0xFF0A84FF); // iOS System Blue
  
  // Aliases for UI code
  static const Color success = successGreen;
  static const Color draft = draftYellow;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      
      // Typography
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: Colors.white70),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: Colors.white60),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1))
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: Colors.white30),
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }
}
