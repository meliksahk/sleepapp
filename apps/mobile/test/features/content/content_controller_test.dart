import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/content/content_controller.dart';

String _soundscape(String slug) => jsonEncode(<String, dynamic>{
  'id': 'id-$slug',
  'slug': slug,
  'titleI18n': <String, String>{'en': 'Deep Ocean', 'tr': 'Derin Okyanus'},
  'engineParams': <String, dynamic>{},
  'layerDefs': <String, dynamic>{},
  'archetypeAffinity': ['deep-ocean'],
  'version': 1,
});

Future<ContentController> _build(
  Future<http.Response> Function(http.Request req) handler,
) async {
  final client = MockClient((req) async {
    if (req.url.path == '/v1/auth/device') {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'accessToken': 'access-1',
          'refreshToken': 'r',
          'accessTokenExpiresIn': 900,
          'userId': 'u-1',
        }),
        201,
      );
    }
    return handler(req);
  });
  final api = NoctaApiClient(baseUrl: 'http://x', client: client);
  final auth = AuthController(api, InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return ContentController(auth, api);
}

void main() {
  test('feed: archetype query ile çeker + parse (title fallback)', () async {
    late Map<String, String> query;
    final content = await _build((req) async {
      expect(req.url.path, '/v1/content/feed');
      query = req.url.queryParameters;
      return http.Response('[${_soundscape('deep-ocean')}]', 200);
    });

    final list = await content.feed(archetype: 'deep-ocean');
    expect(query['archetype'], 'deep-ocean');
    expect(list, hasLength(1));
    expect(list.first.slug, 'deep-ocean');
    expect(list.first.title('tr'), 'Derin Okyanus');
    expect(list.first.title('de'), 'Deep Ocean'); // fallback en
  });

  test('feed: archetype yoksa query eklenmez', () async {
    final content = await _build((req) async {
      expect(req.url.query, isEmpty);
      return http.Response('[]', 200);
    });
    expect(await content.feed(), isEmpty);
  });

  test('soundscape detay: 200 → parse (preset + previewUrl), 404 → null', () async {
    final ok = await _build((req) async {
      expect(req.url.path, '/v1/content/soundscapes/deep-ocean');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'soundscape': jsonDecode(_soundscape('deep-ocean')),
          'presets': [
            {'archetypeSlug': 'deep-ocean', 'mixerState': <String, double>{'rain': 0.7}},
          ],
          'previewUrl': 'https://minio/x?sig=1',
        }),
        200,
      );
    });
    final detail = await ok.soundscape('deep-ocean');
    expect(detail?.soundscape.slug, 'deep-ocean');
    expect(detail?.presets, hasLength(1));
    expect(detail?.previewUrl, 'https://minio/x?sig=1');

    final none = await _build((req) async => http.Response('not found', 404));
    expect(await none.soundscape('yok'), isNull);
  });

  test('weekly: 200 → parse, 404 → null', () async {
    final ok = await _build((req) async {
      expect(req.url.path, '/v1/content/weekly');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'weekStart': '2026-07-13',
          'notes': 'Yaz serisi',
          'soundscapes': [jsonDecode(_soundscape('deep-ocean'))],
        }),
        200,
      );
    });
    final weekly = await ok.weekly();
    expect(weekly?.weekStart, '2026-07-13');
    expect(weekly?.soundscapes, hasLength(1));

    final none = await _build((req) async => http.Response('not found', 404));
    expect(await none.weekly(), isNull);
  });
}
