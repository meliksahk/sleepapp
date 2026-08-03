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

  /// Hatırlatıcı/sessiz saat tercihlerini günceller.
  ///
  /// **`null` GÖNDERMEK ile ALAN GÖNDERMEMEK farklı:** null "temizle" demek,
  /// yokluk "dokunma". `clearReminder` bu ayrımı çağıranın açıkça yapmasını
  /// sağlıyor — aksi hâlde hatırlatıcıyı kapatmak imkânsız olurdu.
  Future<Profile> setReminder({
    int? hour,
    bool clearReminder = false,
    int? quietStart,
    int? quietEnd,
    bool clearQuietHours = false,
  }) async {
    // `?deger` null-aware eleman: değer null ise ANAHTAR HİÇ GÖNDERİLMEZ.
    // Sunucuda "alan yok = dokunma", "alan null = temizle" olduğu için bu ayrım
    // gövdeye birebir yansımalı.
    final body = <String, dynamic>{
      if (clearReminder) 'reminderHour': null else 'reminderHour': ?hour,
      if (clearQuietHours) ...<String, dynamic>{
        'quietHoursStart': null,
        'quietHoursEnd': null,
      } else ...<String, dynamic>{
        'quietHoursStart': ?quietStart,
        'quietHoursEnd': ?quietEnd,
      },
    };
    final res = await _auth.authorizedRequest(
      (token) => _client.patchAuthed('/v1/profile', token, body),
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
