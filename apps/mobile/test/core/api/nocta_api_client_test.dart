import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/api/session.dart';

void main() {
  test('registerDevice 201 → Session parse eder, doğru uca gider', () async {
    final mock = MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/v1/auth/device');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['fingerprint'], 'fp-1');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'accessToken': 'a',
          'refreshToken': 'r',
          'accessTokenExpiresIn': 900,
          'userId': 'u1',
        }),
        201,
      );
    });

    final client = NoctaApiClient(baseUrl: 'http://x', client: mock);
    final Session s = await client.registerDevice(fingerprint: 'fp-1', platform: 'ios');
    expect(s.userId, 'u1');
    expect(s.accessTokenExpiresIn, 900);
  });

  test('201 dışı yanıt → ApiException', () async {
    final mock = MockClient((req) async => http.Response('bad', 400));
    final client = NoctaApiClient(baseUrl: 'http://x', client: mock);
    expect(
      () => client.registerDevice(fingerprint: 'fp', platform: 'ios'),
      throwsA(isA<ApiException>()),
    );
  });
}
