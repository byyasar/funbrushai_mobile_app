import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/services.dart';

class ThemeProvider extends ChangeNotifier {
  static const platform = MethodChannel('com.funbrushai.app/theme');
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  static const String _themeKey = 'theme_mode';

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeStr = prefs.getString(_themeKey);
    if (themeStr != null) {
      if (themeStr == 'ThemeMode.light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'ThemeMode.dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
      _updateSystemTheme(_themeMode);
    }
  }

  Future<void> _updateSystemTheme(ThemeMode mode) async {
    try {
      await platform.invokeMethod('setTheme', {'mode': mode.toString()});
    } on PlatformException catch (e) {
      debugPrint("Failed to set system theme: '${e.message}'.");
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    _updateSystemTheme(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // This might need context to be accurate, but system usually implies follow system.
      // For simple toggle logic in UI without context, we might rely on the current mode value.
      // However, to know the *actual* brightness, we usually check MediaQuery.
      // For now, let's just use this helper to simply check if we are *explicitly* in dark mode.
      return false; 
    }
    return _themeMode == ThemeMode.dark;
  }
}
