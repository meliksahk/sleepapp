import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';

/// İnce interim API istemcisi (docs/04 M0 auth akışı). baseUrl flavor'dan gelir.
/// Auth interceptor + offline kuyruk üstüne eklenecek; generated client B-3'te.
class NoctaApiClient {
  NoctaApiClient({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Anonim cihaz kaydı → access + refresh token.
  Future<Session> registerDevice({
    required String fingerprint,
    required String platform,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/v1/auth/device'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'fingerprint': fingerprint, 'platform': platform}),
    );
    if (res.statusCode != 201) {
      throw ApiException(res.statusCode, res.body);
    }
    return Session.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Refresh token rotasyonu → yeni access + refresh (eski geçersizleşir).
  /// Reuse/geçersiz token'da 401 → ApiException.
  Future<Session> refresh(String refreshToken) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/v1/auth/refresh'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, res.body);
    }
    return Session.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Kimlik doğrulamalı GET — ham yanıt döner (401 refresh akışı çağırana ait).
  /// AuthController.authorizedRequest ile sarılır (401→refresh→retry).
  Future<http.Response> getAuthed(String path, String accessToken) {
    return _client.get(Uri.parse('$baseUrl$path'), headers: _authHeaders(accessToken));
  }

  /// Kimlik doğrulamalı POST (JSON gövde) — ham yanıt döner.
  Future<http.Response> postAuthed(String path, String accessToken, Object body) {
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {..._authHeaders(accessToken), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  /// Kimlik doğrulamalı PATCH (JSON gövde) — ham yanıt döner (kısmi güncelleme).
  Future<http.Response> patchAuthed(String path, String accessToken, Object body) {
    return _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: {..._authHeaders(accessToken), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  Map<String, String> _authHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
      };

  void close() => _client.close();
}
