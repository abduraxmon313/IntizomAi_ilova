import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kirish tokenini qurilmaning xavfsiz xotirasida saqlaydi
/// (Android Keystore / iOS Keychain).
class AuthStore {
  AuthStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'intizom_ai.auth.token.v1';

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

  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }
}
