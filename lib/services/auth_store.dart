import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Auth token va foydalanuvchi ID'sini xavfsiz saqlash.
///
/// Token — Railway API tomonidan beriladigan JWT yoki session token.
/// Telegram orqali login qilinganda olinadi.
class AuthStore {
  static const _tokenKey = 'intizom_ai.auth.token';
  static const _userIdKey = 'intizom_ai.auth.user_id';
  static const _telegramIdKey = 'intizom_ai.auth.telegram_id';

  final FlutterSecureStorage _storage;

  AuthStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Auth tokenni saqlash.
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  /// Auth tokenni o'qish.
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// User ID saqlash.
  Future<void> saveUserId(int userId) =>
      _storage.write(key: _userIdKey, value: userId.toString());

  /// User ID o'qish.
  Future<int?> getUserId() async {
    final val = await _storage.read(key: _userIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  /// Telegram ID saqlash.
  Future<void> saveTelegramId(int telegramId) =>
      _storage.write(key: _telegramIdKey, value: telegramId.toString());

  /// Telegram ID o'qish.
  Future<int?> getTelegramId() async {
    final val = await _storage.read(key: _telegramIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  /// Foydalanuvchi logged in mi?
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Barcha ma'lumotlarni o'chirish (logout).
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _telegramIdKey);
  }
}
