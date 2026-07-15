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

  void close() => _client.close();
}
