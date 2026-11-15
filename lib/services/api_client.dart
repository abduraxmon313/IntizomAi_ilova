import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_store.dart';

/// Server xatosi. [statusCode]: 401 — qayta kirish, 402 — Premium kerak,
/// 409 — amalga ruxsat yo'q (masalan reja vaqti hali kelmagan), 0 — tarmoq.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get needsPremium => statusCode == 402;

  @override
  String toString() => message;
}

/// Railway serveri bilan REST aloqa. Har so'rovga `Authorization: Bearer`
/// qo'shiladi. 401 kelsa [onUnauthorized] chaqiriladi (ilova login sahifasiga qaytadi).
class ApiClient {
  ApiClient({http.Client? client, AuthStore? authStore})
    : _client = client ?? http.Client(),
      _authStore = authStore ?? AuthStore();

  final http.Client _client;
  final AuthStore _authStore;

  /// Global: sessiya tugaganda chaqiriladi (main.dart o'rnatadi).
  static void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 25);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

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
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await _authStore.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, apiUri(path, query))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiException('Server javob bermadi. Qaytadan urinib ko\'ring.');
    } catch (_) {
      throw const ApiException('Internet aloqasini tekshiring.');
    }

    dynamic decoded;
    try {
      decoded = response.bodyBytes.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    final code = response.statusCode;
    if (code >= 200 && code < 300) return decoded;

    final detail = decoded is Map ? decoded['detail'] : null;
    final message = detail is String && detail.isNotEmpty
        ? detail
        : switch (code) {
            401 => 'Sessiya tugagan. Qaytadan kiring.',
            402 => 'Bu imkoniyat Premium foydalanuvchilar uchun.',
            404 => 'Ma\'lumot topilmadi.',
            429 => 'Juda ko\'p so\'rov. Biroz kuting.',
            _ => 'Server xatosi ($code).',
          };
    if (code == 401 && auth) {
      await _authStore.clear();
      onUnauthorized?.call();
    }
    throw ApiException(message, statusCode: code);
  }
}
