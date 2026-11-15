import 'package:shared_preferences/shared_preferences.dart';

/// Tema rejimi (yorug'/qorong'i) ni qurilmada saqlash.
class AppearanceStore {
  static const _key = 'intizom_ai.appearance.mode.v1';

  /// Saqlangan temani o'qish ('light' yoki 'dark', yoki null).
  Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_key);
      if (val == 'light' || val == 'dark') return val;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Temani saqlash.
  Future<void> save(String mode) async {
    if (mode != 'light' && mode != 'dark') {
      throw ArgumentError.value(mode, 'mode', 'Must be "light" or "dark"');
    }
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_key, mode);
    if (!ok) throw StateError('Failed to persist appearance');
  }
}
