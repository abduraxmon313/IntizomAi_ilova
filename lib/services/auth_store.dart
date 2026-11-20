import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kirish tokenini qurilmaning xavfsiz xotirasida saqlaydi
/// (Android Keystore / iOS Keychain).
class AuthStore {
  AuthStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  // v2: yangi (alohida) backend tokeni. Eski bot tokeni (v1) bilan aralashmaydi.
  static const _tokenKey = 'intizom_ai.auth.token.v2';
  static const _onboardedKey = 'intizom_ai.auth.onboarded.v2';
  static const _legacyTokenKey = 'intizom_ai.auth.token.v1';

  final FlutterSecureStorage _storage;

  Future<String?> getToken() async {
    try {
      final t = await _storage.read(key: _tokenKey);
      return (t == null || t.isEmpty) ? null : t;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  /// Profil to'ldirilganmi (oflayn ishga tushganda ham to'g'ri sahifani ko'rsatish uchun).
  Future<bool> isOnboarded() async {
    try {
      return await _storage.read(key: _onboardedKey) == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> setOnboarded(bool value) async {
    try {
      await _storage.write(key: _onboardedKey, value: value ? '1' : '0');
    } catch (_) {}
  }

  Future<void> clear() async {
    for (final k in [_tokenKey, _onboardedKey, _legacyTokenKey]) {
      try {
        await _storage.delete(key: k);
      } catch (_) {}
    }
  }
}
