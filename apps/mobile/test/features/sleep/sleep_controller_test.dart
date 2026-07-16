import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';

String _session(String slug) => jsonEncode(<String, dynamic>{
  'id': 's1',
  'startedAt': '2026-03-10T22:00:00.000Z',
  'endedAt': '2026-03-11T04:00:00.000Z',
  'nightDate': slug,
  'durationMinutes': 360,
  'movementEvents': 4,
  'soundEvents': 2,
});

Future<SleepController> _build(
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
  return SleepController(auth, api);
}

void main() {
  test('recordSession: Bearer + gövde gönderir, 201 → parse', () async {
    late String authHeader;
    late Map<String, dynamic> body;
    final controller = await _build((req) async {
      expect(req.url.path, '/v1/sleep/sessions');
      expect(req.method, 'POST');
      authHeader = req.headers['authorization'] ?? '';
      body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(_session('2026-03-10'), 201);
    });

    final s = await controller.recordSession(
      SleepSessionDraft(
        startedAt: DateTime.utc(2026, 3, 10, 22),
        endedAt: DateTime.utc(2026, 3, 11, 4),
        movementEvents: 4,
        soundEvents: 2,
      ),
    );
    expect(authHeader, 'Bearer access-1');
    expect(body['movementEvents'], 4);
    expect(body['startedAt'], '2026-03-10T22:00:00.000Z');
    expect(s.nightDate, '2026-03-10');
    expect(s.durationMinutes, 360);
  });

  test('recentSessions: liste parse eder', () async {
    final controller = await _build((req) async {
      expect(req.url.path, '/v1/sleep/sessions');
      return http.Response('[${_session('2026-03-10')},${_session('2026-03-09')}]', 200);
    });
    final list = await controller.recentSessions();
    expect(list, hasLength(2));
    expect(list.first.nightDate, '2026-03-10');
  });

  test('nightReport: 200 → parse, 404 → null', () async {
    final ok = await _build((req) async {
      expect(req.url.path, '/v1/sleep/report');
      expect(req.url.queryParameters['night'], '2026-03-10');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'nightDate': '2026-03-10',
          'sessionCount': 1,
          'totalDurationMinutes': 360,
          'movementEvents': 4,
          'soundEvents': 2,
          'calmScore': 85,
        }),
        200,
      );
    });
    final report = await ok.nightReport('2026-03-10');
    expect(report?.calmScore, 85);

    final none = await _build((req) async => http.Response('not found', 404));
    expect(await none.nightReport('2000-01-01'), isNull);
  });

  test('stats: parse eder', () async {
    final controller = await _build((req) async {
      expect(req.url.path, '/v1/sleep/stats');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'nights': 12,
          'totalDurationMinutes': 5400,
          'averageDurationMinutes': 450,
        }),
        200,
      );
    });
    final s = await controller.stats();
    expect(s.nights, 12);
    expect(s.averageDurationMinutes, 450);
  });

  test('streak: parse eder', () async {
    final controller = await _build((req) async {
      expect(req.url.path, '/v1/sleep/streak');
      return http.Response(
        jsonEncode(<String, dynamic>{'current': 5, 'longest': 12, 'totalNights': 40}),
        200,
      );
    });
    final s = await controller.streak();
    expect(s.current, 5);
    expect(s.longest, 12);
    expect(s.totalNights, 40);
  });
}
