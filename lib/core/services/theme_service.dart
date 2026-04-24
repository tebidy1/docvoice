import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entities/app_theme.dart';

class ThemeService extends ValueNotifier<ThemePreset> {
  // Singleton instance
  static final ThemeService _instance = ThemeService._internal();

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal() : super(ThemePreset.slateDark) {
    _loadTheme();
  }

  static const String _themePrefKey = 'selected_theme';

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(_themePrefKey);
      if (themeId != null) {
        if (themeId == ThemePreset.lightNative.id) {
          value = ThemePreset.lightNative;
        } else if (themeId == ThemePreset.slateDark.id) {
          value = ThemePreset.slateDark;
        } else if (themeId == ThemePreset.darkOnyx.id) {
          value = ThemePreset.darkOnyx;
        }
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> setTheme(ThemePreset theme) async {
    value = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, theme.id);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}
