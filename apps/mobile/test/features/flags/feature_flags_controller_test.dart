import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/api/session.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/flags/feature_flags_controller.dart';

Future<FeatureFlagsController> _build(
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
  return FeatureFlagsController(auth, api, platform: 'ios', appVersion: '1.5.0');
}

void main() {
  test('çekmeden önce isEnabled → false (güvenli varsayılan)', () async {
    final flags = await _build((req) async => http.Response('{}', 200));
    expect(flags.isEnabled('anything'), isFalse);
  });

  test('refresh: context query gönderir, haritayı parse eder', () async {
    late Map<String, String> query;
    final flags = await _build((req) async {
      expect(req.url.path, '/v1/flags');
      query = req.url.queryParameters;
      return http.Response(
        jsonEncode(<String, dynamic>{'new_home': true, 'beta_mixer': false}),
        200,
      );
    });

    await flags.refresh();
    expect(query['platform'], 'ios');
    expect(query['appVersion'], '1.5.0');
    expect(flags.isEnabled('new_home'), isTrue);
    expect(flags.isEnabled('beta_mixer'), isFalse);
    expect(flags.isEnabled('bilinmeyen'), isFalse); // haritada yok → false
  });

  test('refresh başarısız (500) → hata, flag\'ler varsayılan kalır', () async {
    final flags = await _build((req) async => http.Response('err', 500));
    await expectLater(flags.refresh(), throwsA(isA<ApiException>()));
    expect(flags.isEnabled('new_home'), isFalse);
  });
}
