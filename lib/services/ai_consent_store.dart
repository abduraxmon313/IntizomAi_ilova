import 'package:shared_preferences/shared_preferences.dart';

/// AI murabbiyga ma'lumot yuborishga rozilik (App Store 5.1.2(i)):
/// xabarlar va reja/odat/maqsadlar uchinchi tomon AI'ga (OpenAI) yuboriladi,
/// shuning uchun birinchi foydalanishdan oldin aniq ruxsat so'raladi.
/// Profil sahifasida istalgan vaqtda qaytarib olinadi.
class AiConsentStore {
  static const _key = 'intizom_ai.ai_consent.v1';

  Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> save(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
