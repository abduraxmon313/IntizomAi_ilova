import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/app_config.dart';
import '../models/profile.dart';
import 'api_client.dart';
import 'auth_store.dart';

/// Kirish natijasi.
class AuthResult {
  const AuthResult({required this.needsOnboarding, this.profile});
  final bool needsOnboarding;
  final Profile? profile;
}

/// Foydalanuvchi kirish oynasini o'zi yopdi — xato sifatida ko'rsatilmaydi.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Google kirishni rad etdi (odatda Google Cloud sozlamasi: paket nomi, SHA-1 yoki client ID).
class GoogleConfigError implements Exception {
  const GoogleConfigError({required this.code, this.details = ''});
  final String code;
  final String details;

  @override
  String toString() => details.isEmpty ? code : '$code: $details';
}

/// Kirish: iOS — Apple yoki Google, Android — faqat Google.
///
/// Provayder bergan ID tokenni ilova backend'iga yuboramiz; server uni
/// tekshirib, o'z sessiya tokenini qaytaradi. Parol ilovada saqlanmaydi.
class AuthService {
  AuthService({ApiClient? api, AuthStore? store})
    : _store = store ?? AuthStore(),
      _api = api ?? ApiClient(authStore: store);

  final ApiClient _api;
  final AuthStore _store;
  bool _googleReady = false;

  /// Apple orqali kirish faqat iOS'da ko'rsatiladi.
  static bool get appleAvailable => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _initGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS && kGoogleIosClientId.isNotEmpty ? kGoogleIosClientId : null,
      serverClientId: kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
    );
    _googleReady = true;
  }

  Future<AuthResult> signInWithGoogle() async {
    await _initGoogle();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      debugPrint('Google Sign-In xato: ${e.code.name} — ${e.description}');
      final desc = (e.description ?? '').trim();
      // Android Credential Manager sozlama xatosini ham "canceled" deb qaytaradi
      // (masalan "[16] Account reauth failed" — SHA-1 yoki client ID mos emas).
      // Faqat haqiqiy bekor qilish jim o'tadi, qolgani foydalanuvchiga ko'rsatiladi.
      final userCancelled = e.code == GoogleSignInExceptionCode.canceled &&
          (desc.isEmpty || desc.toLowerCase().contains('cancel'));
      if (userCancelled) throw const AuthCancelled();
      throw GoogleConfigError(code: e.code.name, details: desc);
    }
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException('Google ID token olinmadi. GOOGLE_SERVER_CLIENT_ID sozlamasini tekshiring.');
    }
    return _complete(await _api.post('/auth/google', body: {'id_token': idToken}, auth: false));
  }

  static String _randomNonce([int length = 32]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<AuthResult> signInWithApple() async {
    final rawNonce = _randomNonce();
    final AuthorizationCredentialAppleID cred;
    try {
      cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw const AuthCancelled();
      throw ApiException(e.message);
    }
    final token = cred.identityToken;
    if (token == null || token.isEmpty) throw const ApiException('Apple ID token olinmadi.');
    return _complete(
      await _api.post(
        '/auth/apple',
        auth: false,
        body: {
          'identity_token': token,
          'raw_nonce': rawNonce,
          'authorization_code': cred.authorizationCode,
          'given_name': ?cred.givenName,
          'family_name': ?cred.familyName,
        },
      ),
    );
  }

  Future<AuthResult> _complete(dynamic res) async {
    final map = res is Map ? Map<String, dynamic>.from(res) : const <String, dynamic>{};
    final token = map['token'] as String?;
    if (token == null || token.isEmpty) throw const ApiException('Server token qaytarmadi.');
    await _store.saveToken(token);
    final needs = map['needs_onboarding'] as bool? ?? true;
    await _store.setOnboarded(!needs);
    final p = map['profile'];
    return AuthResult(
      needsOnboarding: needs,
      profile: p is Map ? Profile.fromJson(Map<String, dynamic>.from(p)) : null,
    );
  }

  /// Serverdagi sessiyani bekor qiladi va qurilmadan chiqadi.
  Future<void> signOut({bool notifyServer = true}) async {
    if (notifyServer) {
      try {
        await _api.post('/auth/logout');
      } catch (_) {}
    }
    try {
      if (_googleReady || !appleAvailable) {
        await _initGoogle();
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    await _store.clear();
  }
}
