import 'package:flutter/material.dart';
import '../models/app_theme.dart';

class ThemeService extends ValueNotifier<AppTheme> {
  // Singleton instance
  static final ThemeService _instance = ThemeService._internal();

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal() : super(AppTheme.darkOnyx); // Default to Dark Onyx as requested? Or Native Light? 
  // User asked to "Add Dark 2 (Onyx) considering it active". So default to Dark Onyx.

  void setTheme(AppTheme theme) {
    value = theme;
  }
}
