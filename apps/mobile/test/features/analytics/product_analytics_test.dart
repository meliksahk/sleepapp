import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/analytics/product_analytics.dart';

Future<ProductAnalytics> _build(
  Future<http.Response> Function(http.Request req) handler, {
  DateTime Function()? now,
}) async {
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
  return ProductAnalytics(auth, api, now: now);
}

void main() {
  test('track + flush: batch gönderir, Bearer + gövde, tampon temizlenir', () async {
    late String authHeader;
    late Map<String, dynamic> body;
    final analytics = await _build(
      (req) async {
        expect(req.url.path, '/v1/analytics/events');
        authHeader = req.headers['authorization'] ?? '';
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(<String, dynamic>{'accepted': 2}), 202);
      },
      now: () => DateTime.utc(2026, 5, 1, 10),
    );

    analytics.track('archetype_completed', props: {'v': 1});
    analytics.track('sleep.session.recorded');
    expect(analytics.pending, 2);

    final sent = await analytics.flush();
    expect(sent, 2);
    expect(analytics.pending, 0);
    expect(authHeader, 'Bearer access-1');
    final events = body['events'] as List<dynamic>;
    expect(events, hasLength(2));
    expect((events.first as Map<String, dynamic>)['name'], 'archetype_completed');
    expect((events.first as Map<String, dynamic>)['occurredAt'], '2026-05-01T10:00:00.000Z');
  });

  test('boş tampon → flush çağrı yapmaz, 0 döner', () async {
    var called = false;
    final analytics = await _build((req) async {
      called = true;
      return http.Response('', 202);
    });
    expect(await analytics.flush(), 0);
    expect(called, isFalse);
  });

  test('gönderim başarısız (500) → tampon korunur (sonra tekrar denenir)', () async {
    final analytics = await _build((req) async => http.Response('err', 500));
    analytics.track('a_b');
    expect(await analytics.flush(), 0);
    expect(analytics.pending, 1); // korundu
  });

  test('tampon sınırı: en eski düşürülür (max 100)', () async {
    final analytics = await _build((req) async => http.Response('', 202));
    for (var i = 0; i < ProductAnalytics.maxBuffer + 5; i++) {
      analytics.track('e_$i');
    }
    expect(analytics.pending, ProductAnalytics.maxBuffer);
  });
}
