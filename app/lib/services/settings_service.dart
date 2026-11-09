import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings kept on this phone, so they apply before anyone logs in.
class AppSettings {
  AppSettings._();
  static final instance = AppSettings._();

  static const _themeKey = 'themeMode';

  /// Light, dark, or the same as the phone. The app rebuilds when this changes.
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Reads the saved settings. Call once at startup. A failure keeps the defaults.
  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_themeKey);
      themeMode.value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    try {
      await (await SharedPreferences.getInstance()).setString(_themeKey, mode.name);
    } catch (_) {}
  }
}
