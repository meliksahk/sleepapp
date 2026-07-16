import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api/nocta_api_client.dart';
import '../../core/api/session.dart';
import '../../core/storage/session_store.dart';

/// Anonim oturum durumu. Uygulama açılışta kayıtlı oturumu geri yükler; yoksa
/// anonim cihaz kaydı yapar (docs/04 M0). Token'lar SessionStore'da (secure) tutulur.
class AuthController {
  AuthController(this._client, this._store);

  final NoctaApiClient _client;
  final SessionStore _store;

  Session? _session;
  Session? get session => _session;
  bool get isAuthenticated => _session != null;

  /// Kayıtlı oturumu yükler (varsa). Uygulama açılışında çağrılır.
  Future<void> restore() async {
    _session = await _store.read();
  }

  Future<void> registerAnonymously(String deviceFingerprint) async {
    final session = await _client.registerDevice(
      fingerprint: deviceFingerprint,
      platform: 'flutter',
    );
    _session = session;
    await _store.save(session);
  }

  /// Açılış akışı: kayıtlı oturum varsa onu kullan, yoksa anonim kaydol.
  Future<void> ensureSession(String deviceFingerprint) async {
    await restore();
    if (_session == null) {
      await registerAnonymously(deviceFingerprint);
    }
  }

  /// Yetkili istek: geçerli access token ile [send] çağrılır. 401 dönerse bir
  /// kez refresh denenir, yeni token'lar saklanır ve istek tekrarlanır. Refresh
  /// de başarısızsa (reuse/geçersiz) oturum geçersizdir → signOut + hata iletilir.
  /// Interim seam (docs/04 M0); generated client + Dio interceptor'a geçince değişir.
  Future<http.Response> authorizedRequest(
    Future<http.Response> Function(String accessToken) send,
  ) async {
    final current = _session;
    if (current == null) {
      throw StateError('Oturum yok — önce ensureSession çağrılmalı.');
    }

    final res = await send(current.accessToken);
    if (res.statusCode != 401) return res;

    // 401 → tek sefer refresh dene.
    final Session refreshed;
    try {
      refreshed = await _client.refresh(current.refreshToken);
    } on ApiException {
      await signOut();
      rethrow;
    }
    _session = refreshed;
    await _store.save(refreshed);
    return send(refreshed.accessToken);
  }

  /// Diğer cihazlardan çık — mevcut oturum hariç tümünü iptal eder. İptal sayısı.
  /// Refresh token gövde içinde CLOSURE'da okunur → 401 refresh rotasyonundan sonra
  /// güncel (rotasyonlu) token gönderilir (aksi halde eski token reddedilirdi).
  Future<int> revokeOtherSessions() async {
    final res = await authorizedRequest(
      (token) => _client.postAuthed('/v1/auth/sessions/revoke-others', token, {
        'refreshToken': _session?.refreshToken ?? '',
      }),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return (jsonDecode(res.body) as Map<String, dynamic>)['revoked'] as int;
  }

  Future<void> signOut() async {
    _session = null;
    await _store.clear();
  }
}
