import 'package:flutter/material.dart';

/// Shared brand color constants for SoutNote.
/// Source of truth for all platforms (Mobile, Desktop, Web Extension).
/// Derived from MedColors + SVG logo assets.
class BrandColors {
  BrandColors._();

  // ── Primary Brand ────────────────────────────────────────────
  static const Color navy = Color(0xFF0F172A);
  static const Color primaryBlue = Color(0xFF00A6FB);
  static const Color primaryDark = Color(0xFF0086C8);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color darkNavy = Color(0xFF0B1F3B);
  static const Color medicalBlue = Color(0xFF1D4ED8);

  // ── Surfaces (Light / White Theme) ────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color inputFill = Color(0xFFF1F5F9);
  static const Color inputBorder = Color(0xFFE2E8F0);
  static const Color cardBorder = Color(0xFFCBD5E1);

  // ── Text ──────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textHint = Color(0xFFCBD5E1);

  // ── Status ────────────────────────────────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFFFC107);

  // ── Surfaces (Dark Theme - existing app) ──────────────────────
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF0B2C55);
  static const Color dividerDark = Color(0xFF1E3A5F);
}






