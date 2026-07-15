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

  Future<void> signOut() async {
    _session = null;
    await _store.clear();
  }
}
