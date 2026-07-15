import 'dart:convert';
import '../../core/api/nocta_api_client.dart';
import '../../core/api/session.dart';
import '../auth/auth_controller.dart';
import 'archetype_models.dart';

/// Archetype test akışı (docs/04 M1): soruları çek → cevapla → sonuç.
/// Tüm çağrılar AuthController.authorizedRequest ile sarılır → 401'de otomatik
/// refresh + retry. Interim http; üretilen client (B-3) gelince swap edilir.
class ArchetypeController {
  ArchetypeController(this._auth, this._client);

  final AuthController _auth;
  final NoctaApiClient _client;

  Future<ArchetypeQuestions> fetchQuestions() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/archetype/questions', token),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return ArchetypeQuestions.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Cevapları gönderir → hesaplanan sonuç (201). answers: questionId → optionId.
  Future<ArchetypeResult> submitAnswers(int version, Map<String, String> answers) async {
    final res = await _auth.authorizedRequest(
      (token) => _client.postAuthed('/v1/archetype/answers', token, {
        'version': version,
        'answers': answers,
      }),
    );
    if (res.statusCode != 201) throw ApiException(res.statusCode, res.body);
    return ArchetypeResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Paylaşım kartı (kullanıcının sonucundan). Sonuç yoksa (404) null döner.
  Future<ArchetypeShare?> fetchShare() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/sharing/archetype', token),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return ArchetypeShare.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// En son sonuç; henüz test yapılmadıysa (404) null döner.
  Future<ArchetypeResult?> latestResult() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/archetype/result', token),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return ArchetypeResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
