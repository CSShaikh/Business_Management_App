import 'package:flutter/material.dart';

import '../core/app_refresh_controller.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isSystemMode =>
      _themeMode == ThemeMode.system;

  bool get isLightMode =>
      _themeMode == ThemeMode.light;

  bool get isDarkMode =>
      _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    _notifyDataChanged();
  }
  void _notifyDataChanged() {
    notifyListeners();
    AppRefreshController.instance.bump();
  }

}
