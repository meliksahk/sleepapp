import 'dart:convert';
import '../../core/api/nocta_api_client.dart';
import '../../core/api/session.dart';
import '../auth/auth_controller.dart';
import 'content_models.dart';

/// İçerik veri katmanı (docs/04): feed + soundscape detay + haftalık yayın.
/// Tümü AuthController.authorizedRequest ile sarılı (401'de otomatik refresh+retry).
class ContentController {
  ContentController(this._auth, this._client);

  final AuthController _auth;
  final NoctaApiClient _client;

  /// Yayınlanmış soundscape feed'i; [archetype] verilirse affinity sıralı.
  Future<List<Soundscape>> feed({String? archetype}) async {
    final path = archetype == null
        ? '/v1/content/feed'
        : '/v1/content/feed?archetype=${Uri.encodeQueryComponent(archetype)}';
    final res = await _auth.authorizedRequest((token) => _client.getAuthed(path, token));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Soundscape.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Soundscape detay + preset; yayınlanmamış/yok ise (404) null.
  Future<SoundscapeDetail?> soundscape(String slug) async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/content/soundscapes/${Uri.encodeComponent(slug)}', token),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return SoundscapeDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Ses dosyası kataloğu (tür/mood filtreli). URL İÇERMEZ — çalmak için
  /// [audioAsset] ile tekil kayda gidilir (sunucu listede imza dağıtmaz).
  Future<List<AudioAsset>> audioAssets({String? genre, List<String>? moods}) async {
    final params = <String>[
      if (genre != null && genre.isNotEmpty) 'genre=${Uri.encodeQueryComponent(genre)}',
      if (moods != null && moods.isNotEmpty)
        'mood=${Uri.encodeQueryComponent(moods.join(','))}',
    ];
    final path =
        '/v1/content/audio-assets${params.isEmpty ? '' : '?${params.join('&')}'}';
    final res = await _auth.authorizedRequest((token) => _client.getAuthed(path, token));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AudioAsset.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Tek ses dosyası + presigned URL; yoksa (404) null.
  ///
  /// URL KISA ÖMÜRLÜDÜR. Uzun bir gecede yeniden çalmak gerekirse bu uç yeniden
  /// çağrılmalı — URL'i kalıcı saklamak, sabaha karşı çalmayan bir katman demektir.
  Future<AudioAssetDetail?> audioAsset(String id) async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/content/audio-assets/${Uri.encodeComponent(id)}', token),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return AudioAssetDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// En güncel haftalık yayın; yoksa (404) null.
  Future<WeeklyRelease?> weekly() async {
    final res = await _auth.authorizedRequest(
      (token) => _client.getAuthed('/v1/content/weekly', token),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return WeeklyRelease.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
