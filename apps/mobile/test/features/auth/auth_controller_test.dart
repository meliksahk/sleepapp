import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';

MockClient _client(int calls) {
  return MockClient((req) async {
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['platform'], 'flutter');
    return http.Response(
      jsonEncode(<String, dynamic>{
        'accessToken': 'a$calls',
        'refreshToken': 'r',
        'accessTokenExpiresIn': 900,
        'userId': 'u-1',
      }),
      201,
    );
  });
}

void main() {
  test('registerAnonymously oturumu kurar ve store\'a kaydeder', () async {
    final store = InMemorySessionStore();
    final controller = AuthController(NoctaApiClient(baseUrl: 'http://x', client: _client(1)), store);

    expect(controller.isAuthenticated, isFalse);
    await controller.registerAnonymously('device-xyz');
    expect(controller.session?.userId, 'u-1');
    expect((await store.read())?.userId, 'u-1'); // kalıcı
  });

  test('ensureSession: kayıtlı oturum varsa yeniden kaydolmaz (restore)', () async {
    final store = InMemorySessionStore();
    // İlk açılış → kaydolur.
    final c1 = AuthController(NoctaApiClient(baseUrl: 'http://x', client: _client(1)), store);
    await c1.ensureSession('fp');
    expect(c1.session?.accessToken, 'a1');

    // İkinci açılış (aynı store) → restore, API çağrısı yok (client çağrılırsa fail eder).
    final failClient = MockClient((req) async {
      fail('restore varken registerDevice çağrılmamalı');
    });
    final c2 = AuthController(NoctaApiClient(baseUrl: 'http://x', client: failClient), store);
    await c2.ensureSession('fp');
    expect(c2.session?.accessToken, 'a1'); // restore edildi

    await c2.signOut();
    expect(await store.read(), isNull);
  });
}
