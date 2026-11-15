import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_store.dart';

/// Railway backend bilan REST API aloqasi.
///
/// Barcha so'rovlarga auth token avtomatik qo'shiladi.
/// 401 javob kelsa — token eskirgan, qayta login kerak.
class ApiClient {
  ApiClient({http.Client? client, AuthStore? authStore})
      : _client = client ?? http.Client(),
        _authStore = authStore ?? AuthStore();

  final http.Client _client;
  final AuthStore _authStore;

  Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authStore.getToken();
    final headers = Map<String, String>.from(_defaultHeaders);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET so'rov.
  Future<ApiResponse> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse(apiUrl(path)).replace(queryParameters: query);
    final response = await _client.get(uri, headers: await _authHeaders());
    return ApiResponse.fromHttp(response);
  }

  /// POST so'rov.
  Future<ApiResponse> post(String path, {Object? body}) async {
    final response = await _client.post(
      Uri.parse(apiUrl(path)),
      headers: await _authHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return ApiResponse.fromHttp(response);
  }

  /// PUT so'rov.
  Future<ApiResponse> put(String path, {Object? body}) async {
    final response = await _client.put(
      Uri.parse(apiUrl(path)),
      headers: await _authHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return ApiResponse.fromHttp(response);
  }

  /// PATCH so'rov.
  Future<ApiResponse> patch(String path, {Object? body}) async {
    final response = await _client.patch(
      Uri.parse(apiUrl(path)),
      headers: await _authHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return ApiResponse.fromHttp(response);
  }

  /// DELETE so'rov.
  Future<ApiResponse> delete(String path) async {
    final response = await _client.delete(
      Uri.parse(apiUrl(path)),
      headers: await _authHeaders(),
    );
    return ApiResponse.fromHttp(response);
  }
}

/// API javob o'rami.
class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    this.data,
    this.error,
  });

  final int statusCode;
  final dynamic data;
  final String? error;

  bool get isOk => statusCode >= 200 && statusCode < 300;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  factory ApiResponse.fromHttp(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    String? error;
    if (!_isOk(response.statusCode) && decoded is Map) {
      error = decoded['error']?.toString() ??
          decoded['detail']?.toString() ??
          decoded['message']?.toString();
    }

    return ApiResponse(
      statusCode: response.statusCode,
      data: decoded,
      error: error,
    );
  }

  static bool _isOk(int code) => code >= 200 && code < 300;
}

/// API xatolik sinfi.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
