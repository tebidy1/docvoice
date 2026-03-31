import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutnote/core/models/app_theme.dart';

/// Notifier for managing app theme settings.
class ThemeNotifier extends Notifier<AppTheme> {
  static const String _themePrefKey = 'selected_theme';

  @override
  AppTheme build() {
    // Start with default, then load from prefs
    _loadTheme();
    return AppTheme.slateDark;
  }
  
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(_themePrefKey);
      if (themeId != null) {
        if (themeId == AppTheme.lightNative.id) {
          state = AppTheme.lightNative;
        } else if (themeId == AppTheme.slateDark.id) {
          state = AppTheme.slateDark;
        } else if (themeId == AppTheme.darkOnyx.id) {
          state = AppTheme.darkOnyx;
        }
      }
    } catch (e) {
      // debugPrint is already available globally in Flutter
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, theme.id);
    } catch (e) {
      // Error handling
    }
  }
}

/// Provider for the ThemeNotifier
final themeServiceProvider = NotifierProvider<ThemeNotifier, AppTheme>(() {
  return ThemeNotifier();
});
