import '../../core/api/nocta_api_client.dart';
import '../../core/api/session.dart';

/// Anonim oturum durumu. Uygulama açılışta anonim cihaz kaydı ile başlar
/// (docs/04 M0). Token saklama (secure storage) + refresh sonraki iterasyonda.
class AuthController {
  AuthController(this._client);

  final NoctaApiClient _client;

  Session? _session;
  Session? get session => _session;
  bool get isAuthenticated => _session != null;

  Future<void> registerAnonymously(String deviceFingerprint) async {
    _session = await _client.registerDevice(
      fingerprint: deviceFingerprint,
      platform: 'flutter',
    );
  }

  void signOut() => _session = null;
}
