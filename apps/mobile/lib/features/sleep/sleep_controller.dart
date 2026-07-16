import 'dart:convert';
import '../../core/api/nocta_api_client.dart';
import '../../core/api/session.dart';
import '../auth/auth_controller.dart';
import 'sleep_models.dart';

/// Uyku veri katmanı (docs/04). Kayıt/liste/rapor/streak — hepsi
/// AuthController.authorizedRequest ile sarılı (401'de otomatik refresh+retry).
/// YALNIZCA türetilmiş metrikler gönderilir; ham mikrofon verisi ASLA (CLAUDE.md §6).
class SleepController {
  SleepController(this._auth, this._client);

  final AuthController _auth;
  final NoctaApiClient _client;

  Future<SleepSession> recordSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int movementEvents,
    required int soundEvents,
  }) async {
    final res = await _auth.authorizedRequest(
      (token) => _client.postAuthed('/v1/sleep/sessions', token, {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'movementEvents': movementEvents,
        'soundEvents': soundEvents,
      }),
    );
    if (res.statusCode != 201) throw ApiException(res.statusCode, res.body);
    return SleepSession.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<SleepSession>> recentSessions() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/sleep/sessions', token),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => SleepSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Bir gecenin raporu; o gecede oturum yoksa (404) null döner.
  Future<NightReport?> nightReport(String nightDate) async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/sleep/report?night=$nightDate', token),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return NightReport.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Uyku istatistikleri (gece sayısı, toplam/ortalama süre).
  Future<SleepStats> stats() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/sleep/stats', token),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return SleepStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Son 7 gecenin uyku trendi (grafik için).
  Future<WeeklyTrend> weeklyTrend() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/sleep/trend', token),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return WeeklyTrend.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<StreakStats> streak() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/sleep/streak', token),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return StreakStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
