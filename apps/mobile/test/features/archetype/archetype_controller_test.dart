import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/archetype/archetype_controller.dart';
import 'package:nocta/features/auth/auth_controller.dart';

String _questions() => jsonEncode(<String, dynamic>{
  'version': 1,
  'questions': [
    {
      'id': 'q1',
      'prompt': 'How do you fall asleep?',
      'options': [
        {'id': 'q1a', 'label': 'Hemen', 'archetype': 'deep-ocean'},
        {'id': 'q1b', 'label': 'Zor', 'archetype': 'overthinker'},
      ],
    },
  ],
});

String _result(String slug) => jsonEncode(<String, dynamic>{
  'userId': 'u-1',
  'archetypeSlug': slug,
  'scores': {'deep-ocean': 3, 'overthinker': 1},
  'version': 1,
  'createdAt': '2026-07-16T00:00:00.000Z',
});

/// Oturumlu AuthController + archetype controller kurar. [handler] archetype
/// uçlarını karşılar; /v1/auth/device register (oturum kurulumu) için sabittir.
Future<ArchetypeController> _build(
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
  return ArchetypeController(auth, api);
}

void main() {
  test('fetchQuestions: Bearer ile çeker ve parse eder', () async {
    late String authHeader;
    final controller = await _build((req) async {
      expect(req.url.path, '/v1/archetype/questions');
      authHeader = req.headers['authorization'] ?? '';
      return http.Response(_questions(), 200);
    });

    final q = await controller.fetchQuestions();
    expect(authHeader, 'Bearer access-1');
    expect(q.version, 1);
    expect(q.questions.single.options.first.archetype, 'deep-ocean');
  });

  test('submitAnswers: gövdeyi gönderir ve sonucu parse eder (201)', () async {
    late Map<String, dynamic> sentBody;
    final controller = await _build((req) async {
      expect(req.url.path, '/v1/archetype/answers');
      sentBody = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(_result('deep-ocean'), 201);
    });

    final result = await controller.submitAnswers(1, {'q1': 'q1a'});
    expect(sentBody['version'], 1);
    expect((sentBody['answers'] as Map<String, dynamic>)['q1'], 'q1a');
    expect(result.archetypeSlug, 'deep-ocean');
    expect(result.scores['deep-ocean'], 3);
  });

  test('latestResult: 200 → sonuç, 404 → null', () async {
    final ok = await _build((req) async => http.Response(_result('overthinker'), 200));
    expect((await ok.latestResult())?.archetypeSlug, 'overthinker');

    final none = await _build((req) async => http.Response('not found', 404));
    expect(await none.latestResult(), isNull);
  });

  test('fetchContent: içerik listesini parse eder', () async {
    final controller = await _build((req) async {
      expect(req.url.path, '/v1/archetype/content');
      return http.Response(
        jsonEncode(<dynamic>[
          {'slug': 'deep-ocean', 'name': 'Deep Ocean', 'tagline': 'T1', 'summary': 'S1'},
          {'slug': 'overthinker', 'name': '3AM Overthinker', 'tagline': 'T2', 'summary': 'S2'},
        ]),
        200,
      );
    });
    final list = await controller.fetchContent();
    expect(list, hasLength(2));
    expect(list.first.name, 'Deep Ocean');
    expect(list.first.tagline, 'T1');
  });

  test('fetchShare: 200 → parse, 404 → null', () async {
    final ok = await _build((req) async {
      expect(req.url.path, '/v1/sharing/archetype');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'archetypeSlug': 'deep-ocean',
          'title': 'My sleep identity is Deep Ocean',
          'description': 'Take the NOCTA sleep ritual test to discover yours.',
          'webUrl': 'https://nocta.app/a/deep-ocean',
          'deepLink': 'nocta://a/deep-ocean',
        }),
        200,
      );
    });
    final share = await ok.fetchShare();
    expect(share?.webUrl, 'https://nocta.app/a/deep-ocean');
    expect(share?.deepLink, 'nocta://a/deep-ocean');

    final none = await _build((req) async => http.Response('not found', 404));
    expect(await none.fetchShare(), isNull);
  });

  test('401 → otomatik refresh + retry (authorizedRequest üzerinden)', () async {
    var refreshed = false;
    var questionsCalls = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/v1/auth/device') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'accessToken': 'old',
            'refreshToken': 'r',
            'accessTokenExpiresIn': 900,
            'userId': 'u-1',
          }),
          201,
        );
      }
      if (req.url.path == '/v1/auth/refresh') {
        refreshed = true;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'accessToken': 'new',
            'refreshToken': 'r2',
            'accessTokenExpiresIn': 900,
            'userId': 'u-1',
          }),
          200,
        );
      }
      // İlk çağrı (old token) 401; refresh sonrası (new) 200.
      questionsCalls++;
      if (req.headers['authorization'] == 'Bearer old') {
        return http.Response('unauthorized', 401);
      }
      return http.Response(_questions(), 200);
    });
    final api = NoctaApiClient(baseUrl: 'http://x', client: client);
    final auth = AuthController(api, InMemorySessionStore());
    await auth.registerAnonymously('fp');
    final controller = ArchetypeController(auth, api);

    final q = await controller.fetchQuestions();
    expect(refreshed, isTrue);
    expect(questionsCalls, 2); // 401 sonra retry
    expect(q.version, 1);
  });
}
