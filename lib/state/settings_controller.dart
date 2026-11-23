import 'package:flutter/material.dart';

import '../data/local_cache.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._cache) : _themeMode = _cache.themeMode;

  final LocalCache _cache;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _cache.setThemeMode(mode);
  }
}
