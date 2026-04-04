import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/app_theme.dart';

class ThemeService extends ValueNotifier<AppTheme> {
  // Singleton instance
  static final ThemeService _instance = ThemeService._internal();

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal() : super(AppTheme.slateDark) {
    _loadTheme();
  }
  
  static const String _themePrefKey = 'selected_theme';

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(_themePrefKey);
      if (themeId != null) {
        if (themeId == AppTheme.lightNative.id) {
          value = AppTheme.lightNative;
        } else if (themeId == AppTheme.slateDark.id) {
          value = AppTheme.slateDark;
        } else if (themeId == AppTheme.darkOnyx.id) {
          value = AppTheme.darkOnyx;
        }
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    value = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, theme.id);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}
