import 'dart:convert';
import '../../core/api/nocta_api_client.dart';
import '../../core/api/session.dart';
import '../auth/auth_controller.dart';
import 'profile_models.dart';

/// Profil veri katmanı (docs/04). Oku/güncelle — AuthController.authorizedRequest
/// ile sarılı (401'de otomatik refresh+retry). Kapsam token sub'ından gelir.
class ProfileController {
  ProfileController(this._auth, this._client);

  final AuthController _auth;
  final NoctaApiClient _client;

  Future<Profile> get() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/profile', token),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Push bildirim tercihini günceller (opt-out). Güncel profili döner.
  Future<Profile> setNotificationsEnabled(bool enabled) async {
    final res = await _auth.authorizedRequest(
      (token) => _client.patchAuthed('/v1/profile', token, {'notificationsEnabled': enabled}),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
