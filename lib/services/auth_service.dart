import 'dart:async';
import 'dart:math';

import 'api_client.dart';
import 'auth_store.dart';
import 'telegram_launcher.dart';

export 'telegram_launcher.dart' show TelegramApps, TelegramTarget;

/// Telegram bot orqali kirish.
///
/// 1) Ilova bir martalik maxfiy kod (nonce) yaratadi.
/// 2) Bot `start=applogin_<nonce>` bilan Telegram ilovasida (yoki Telegram
///    Web'da) ochiladi — qarang: [TelegramLauncher].
/// 3) Foydalanuvchi botda "Tasdiqlash"ni bosadi.
/// 4) Ilova serverni so'rab turadi va tokenni o'zi oladi.
class AuthService {
  AuthService({ApiClient? api, AuthStore? store})
    : _store = store ?? AuthStore(),
      _api = api ?? ApiClient(authStore: store);

  final ApiClient _api;
  final AuthStore _store;
  final TelegramLauncher _telegram = const TelegramLauncher();

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  String newNonce() {
    final rnd = Random.secure();
    return List.generate(40, (_) => _alphabet[rnd.nextInt(_alphabet.length)])
        .join();
  }

  /// Telefondagi Telegram ilovalarini aniqlaydi.
  Future<TelegramApps> telegramApps() => _telegram.detect();

  /// Botni [target] da ochadi (ochilmasa keyingi variantga, oxiri — Telegram Web).
  /// Hech narsa ochilmasa false.
  Future<bool> openBot(String nonce, TelegramTarget target) =>
      _telegram.open(target, 'applogin_$nonce');

  /// Bir marta so'raydi: 'approved' (token saqlandi), 'pending' yoki 'expired'.
  Future<String> poll(String nonce) async {
    final res = await _api.post(
      '/app-auth/poll',
      body: {'nonce': nonce},
      auth: false,
    );
    final status = (res is Map ? res['status'] : null) as String? ?? 'expired';
    if (status == 'approved') {
      final token = res['token'] as String?;
      if (token == null || token.isEmpty) return 'expired';
      await _store.saveToken(token);
    }
    return status;
  }

  Future<void> signOut() => _store.clear();
}
