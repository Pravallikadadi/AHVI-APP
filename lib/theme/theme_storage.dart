import 'package:shared_preferences/shared_preferences.dart';

import 'profile_theme.dart';

class ThemeStorage {
  static const _themeKey = 'profile_theme';
  static const _modeKey = 'profile_mode';

  static Future<void> saveTheme(ProfileTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
  }

  static Future<void> saveMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, isDark ? 'dark' : 'light');
  }

  static Future<ProfileTheme> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeKey);
    return ProfileTheme.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => ProfileTheme.coolBlue,
    );
  }

  static Future<bool> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_modeKey);
    if (raw == 'light') return false;
    if (raw == 'dark') return true;
    return true;
  }
}
