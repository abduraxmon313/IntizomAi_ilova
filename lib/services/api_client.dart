import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_store.dart';
import 'response_cache.dart';

/// Server xatosi. [statusCode]: 401 — qayta kirish, 402 — Premium kerak,
/// 409 — amalga ruxsat yo'q (masalan reja vaqti hali kelmagan),
/// 429 — juda ko'p so'rov, 0 — tarmoq (internet yo'q).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get needsPremium => statusCode == 402;

  /// Vaqtinchalik xato — qayta urinish yoki saqlangan ma'lumot o'rinli.
  bool get isTransient =>
      statusCode == 0 || statusCode == 429 || statusCode == 502 || statusCode == 503 || statusCode == 504;

  @override
  String toString() => message;
}

/// Railway serveri bilan REST aloqa. Har so'rovga `Authorization: Bearer`
/// qo'shiladi. 401 kelsa [onUnauthorized] chaqiriladi (ilova login sahifasiga qaytadi).
///
/// Chidamlilik:
/// * 429/5xx va tarmoq xatolarida avtomatik qayta urinish (orqaga chekinish bilan,
///   `Retry-After` hisobga olinadi). GET'lar ko'proq urinadi, o'zgartiruvchi
///   so'rovlar (POST/PUT/...) faqat 429'da bir marta.
/// * Bir xil GET so'rovlar bir vaqtda kelsa — bitta so'rovga birlashtiriladi.
/// * GET javoblari qurilmada saqlanadi; server javob bermasa oxirgi ma'lumot
///   qaytariladi va [offline] bayrog'i yoqiladi (ilovada "oflayn" chizig'i chiqadi).
class ApiClient {
  ApiClient({http.Client? client, AuthStore? authStore})
    : _client = client ?? http.Client(),
      _authStore = authStore ?? AuthStore();

  final http.Client _client;
  final AuthStore _authStore;

  /// Global: sessiya tugaganda chaqiriladi (main.dart o'rnatadi).
  static void Function()? onUnauthorized;

  /// Oflayn holati — saqlangan ma'lumot ko'rsatilayotganini bildiradi.
  /// Har muvaffaqiyatli so'rovdan keyin o'chadi. UI banner uchun.
  static final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  static const _timeout = Duration(seconds: 25);

  final Map<String, Future<dynamic>> _inflight = {};

  /// Barcha saqlangan GET javoblarini o'chiradi (logout / hisob almashganda).
  static Future<void> clearCache() => ResponseCache.instance.clear();

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    final key = _key(path, query);
    final existing = _inflight[key];
    if (existing != null) return existing;
    final future = _getWithCache(path, query, key);
    _inflight[key] = future;
    // Diqqat: whenComplete natijasini QAYTARMAYMIZ — aks holda future o'zini kutib qoladi.
    future.whenComplete(() => _inflight.remove(key));
    return future;
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  // ── Ichki ────────────────────────────────────────────

  String _key(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return 'GET $path';
    final keys = query.keys.toList()..sort();
    final q = keys.map((k) => '$k=${query[k]}').join('&');
    return 'GET $path?$q';
  }

  Future<dynamic> _getWithCache(String path, Map<String, String>? query, String key) async {
    try {
      final data = await _send('GET', path, query: query);
      unawaited(ResponseCache.instance.write(key, data));
      return data;
    } on ApiException catch (e) {
      if (e.isTransient) {
        final cached = await ResponseCache.instance.read(key);
        if (cached != null) {
          offline.value = true; // Saqlangan ma'lumot ko'rsatilmoqda.
          return cached;
        }
      }
      rethrow;
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
  }) async {
    if (kApiBaseUrl.isEmpty) {
      throw const ApiException(
        "Server manzili sozlanmagan (API_BASE_URL). Ilovani qayta yig'ing.",
      );
    }

    final maxAttempts = method == 'GET' ? 3 : 2;
    var attempt = 0;

    while (true) {
      attempt++;
      http.Response response;
      try {
        response = await _sendOnce(method, path, query, body, auth);
      } on ApiException {
        // Tarmoq xatosi (statusCode 0). GET'ni bir marta qayta uramiz.
        offline.value = true;
        if (method == 'GET' && attempt < maxAttempts) {
          await Future<void>.delayed(_backoff(attempt, null));
          continue;
        }
        rethrow;
      }

      // Serverdan javob keldi — demak internet bor.
      offline.value = false;

      final code = response.statusCode;
      if (code >= 200 && code < 300) return _decode(response);

      final transient = code == 429 || code == 502 || code == 503 || code == 504;
      final canRetry = transient && attempt < maxAttempts && (method == 'GET' || code == 429);
      if (canRetry) {
        await Future<void>.delayed(_backoff(attempt, response.headers['retry-after']));
        continue;
      }

      _throwFor(response, auth);
    }
  }

  Future<http.Response> _sendOnce(
    String method,
    String path,
    Map<String, String>? query,
    Object? body,
    bool auth,
  ) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-App-Platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      if (body != null) 'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await _authStore.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, apiUri(path, query))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    try {
      return await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException("Server javob bermadi. Qaytadan urinib ko'ring.");
    } catch (_) {
      throw const ApiException('Internet aloqasini tekshiring.');
    }
  }

  dynamic _decode(http.Response response) {
    try {
      return response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Never _throwFor(http.Response response, bool auth) {
    dynamic decoded;
    try {
      decoded = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {}
    final code = response.statusCode;
    final detail = decoded is Map ? decoded['detail'] : null;
    final message = detail is String && detail.isNotEmpty
        ? detail
        : switch (code) {
            401 => 'Sessiya tugagan. Qaytadan kiring.',
            402 => 'Bu imkoniyat Premium foydalanuvchilar uchun.',
            404 => "Ma'lumot topilmadi.",
            429 => "Juda ko'p so'rov. Biroz kuting.",
            _ => 'Server xatosi ($code).',
          };
    if (code == 401 && auth) {
      unawaited(_authStore.clear());
      unawaited(ResponseCache.instance.clear());
      onUnauthorized?.call();
    }
    throw ApiException(message, statusCode: code);
  }

  /// Orqaga chekinish: `Retry-After` (soniya) bo'lsa — o'sha, bo'lmasa
  /// eksponensial (0.3s→3.5s) + kichik tasodifiy qo'shimcha.
  Duration _backoff(int attempt, String? retryAfter) {
    if (retryAfter != null) {
      final secs = int.tryParse(retryAfter.trim());
      if (secs != null && secs >= 0 && secs <= 10) {
        return Duration(seconds: secs);
      }
    }
    final ms = (300 * pow(2, attempt - 1)).toInt().clamp(300, 3500);
    return Duration(milliseconds: ms + Random().nextInt(250));
  }
}
