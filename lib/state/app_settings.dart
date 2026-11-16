import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReaderTheme { light, dark, sepia }

extension ReaderThemeColors on ReaderTheme {
  Color get background => switch (this) {
        ReaderTheme.light => const Color(0xFFFAFAFA),
        ReaderTheme.dark => const Color(0xFF121212),
        ReaderTheme.sepia => const Color(0xFFF4ECD8),
      };

  Color get foreground => switch (this) {
        ReaderTheme.light => const Color(0xFF1B1B1B),
        ReaderTheme.dark => const Color(0xFFE6E1D8),
        ReaderTheme.sepia => const Color(0xFF5B4636),
      };

  Brightness get brightness =>
      this == ReaderTheme.dark ? Brightness.dark : Brightness.light;

  String get label => switch (this) {
        ReaderTheme.light => 'Light',
        ReaderTheme.dark => 'Dark',
        ReaderTheme.sepia => 'Sepia',
      };
}

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._theme, this._fontSize);

  static const minFont = 14.0;
  static const maxFont = 32.0;

  final SharedPreferences _prefs;
  ReaderTheme _theme;
  double _fontSize;

  ReaderTheme get theme => _theme;
  double get fontSize => _fontSize;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIdx = prefs.getInt('theme') ?? ReaderTheme.light.index;
    return AppSettings._(
      prefs,
      ReaderTheme.values[themeIdx.clamp(0, ReaderTheme.values.length - 1)],
      (prefs.getDouble('fontSize') ?? 20).clamp(minFont, maxFont),
    );
  }

  void setTheme(ReaderTheme t) {
    _theme = t;
    _prefs.setInt('theme', t.index);
    notifyListeners();
  }

  void setFontSize(double v) {
    _fontSize = v.clamp(minFont, maxFont);
    _prefs.setDouble('fontSize', _fontSize);
    notifyListeners();
  }
}
