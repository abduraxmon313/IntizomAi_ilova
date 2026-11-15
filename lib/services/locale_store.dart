import 'package:shared_preferences/shared_preferences.dart';

/// Til sozlamasini qurilmada saqlash.
class LocaleStore {
  static const _key = 'intizom_ai.locale.v1';
  static const supported = {'uz', 'ru', 'en'};

  /// Saqlangan tilni o'qish.
  Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_key);
      if (val != null && supported.contains(val)) return val;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tilni saqlash.
  Future<void> save(String code) async {
    if (!supported.contains(code)) {
      throw ArgumentError.value(code, 'code', 'Unsupported locale');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
