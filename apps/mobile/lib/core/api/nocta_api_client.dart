import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';

/// İnce interim API istemcisi (docs/04 M0 auth akışı). baseUrl flavor'dan gelir.
/// Auth interceptor + offline kuyruk üstüne eklenecek; generated client B-3'te.
class NoctaApiClient {
  NoctaApiClient({
    required this.baseUrl,
    http.Client? client,
    this.resolveLanguage,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Sunucudan içeriğin hangi dilde isteneceğini **İSTEK ANINDA** çözer
  /// (`'tr'`, `'en'`, ya da null → sunucu varsayılanı EN).
  ///
  /// **Neden istemci gönderiyor:** arketip soruları ve sonuç anlatımı SUNUCUDA
  /// yaşıyor (tek kaynak — web ve mobil aynı matrisi kullanır, CLAUDE.md §2).
  /// Bu başlık olmadan Türkçe arayüzde İngilizce sorular çıkıyordu.
  ///
  /// **NEDEN SABİT STRING DEĞİL — GERÇEK BİR HATA:** dil başta sabit bir alandı ve
  /// `apiClientProvider` dili `watch` ediyordu. Kullanıcı ayarlardan dili değiştirince
  /// provider yeniden kuruluyor, `onDispose` eski `http.Client`'ı KAPATIYOR, ama
  /// `AuthController` onu `ref.read` ile tuttuğu için kapanmış client'la istek atmaya
  /// çalışıyordu → dil değiştiren kullanıcıda TÜM API çağrıları sessizce ölüyordu
  /// (emülatörde yakalandı: değişimden sonra sunucuya tek istek ulaşmadı).
  /// Çözüm: client ÖMÜR BOYU tek; dil her istekte yeniden okunur.
  final String? Function()? resolveLanguage;

  /// Dil başlığı — her istekte (auth'lu ya da değil) aynı şekilde eklenir.
  Map<String, String> get _localeHeaders {
    final language = resolveLanguage?.call();
    if (language == null || language.isEmpty) return const {};
    return {'Accept-Language': language};
  }

  /// Anonim cihaz kaydı → access + refresh token.
  Future<Session> registerDevice({
    required String fingerprint,
    required String platform,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/v1/auth/device'),
      headers: {..._localeHeaders, 'Content-Type': 'application/json'},
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
      headers: {..._localeHeaders, 'Content-Type': 'application/json'},
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
        ..._localeHeaders,
        'Authorization': 'Bearer $accessToken',
      };

  void close() => _client.close();
}
