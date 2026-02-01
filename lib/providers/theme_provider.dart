import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  late Color _primaryColor;
  late bool _isDarkMode;

  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider(this._prefs) {
    _isDarkMode = _prefs.getBool('is_dark_mode') ?? true;
    final colorValue = _prefs.getInt('primary_color');
    _primaryColor = colorValue != null
        ? Color(colorValue)
        : const Color.fromARGB(255, 101, 144, 32);
  }

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    _prefs.setInt('primary_color', color.value);
    notifyListeners();
  }

  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    _prefs.setBool('is_dark_mode', isDark);
    notifyListeners();
  }
}
