import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/api/session.dart';
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

String _session(String access, String refresh) => jsonEncode(<String, dynamic>{
  'accessToken': access,
  'refreshToken': refresh,
  'accessTokenExpiresIn': 900,
  'userId': 'u-1',
});

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

  test('authorizedRequest: 401 → refresh → retry başarılı, yeni token saklanır', () async {
    final store = InMemorySessionStore();
    var refreshCalls = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/v1/auth/device') {
        return http.Response(_session('old-access', 'old-refresh'), 201);
      }
      if (req.url.path == '/v1/auth/refresh') {
        refreshCalls++;
        expect((jsonDecode(req.body) as Map<String, dynamic>)['refreshToken'], 'old-refresh');
        return http.Response(_session('new-access', 'new-refresh'), 200);
      }
      return http.Response('not found', 404);
    });
    final controller = AuthController(NoctaApiClient(baseUrl: 'http://x', client: client), store);
    await controller.registerAnonymously('fp');

    var sendCalls = 0;
    final res = await controller.authorizedRequest((accessToken) async {
      sendCalls++;
      if (accessToken == 'old-access') return http.Response('unauthorized', 401);
      return http.Response('ok:$accessToken', 200);
    });

    expect(res.statusCode, 200);
    expect(res.body, 'ok:new-access');
    expect(refreshCalls, 1);
    expect(sendCalls, 2); // ilk 401, sonra retry
    expect(controller.session?.accessToken, 'new-access');
    expect((await store.read())?.refreshToken, 'new-refresh'); // kalıcı
  });

  test('authorizedRequest: refresh de 401 (reuse) → signOut + ApiException', () async {
    final store = InMemorySessionStore();
    final client = MockClient((req) async {
      if (req.url.path == '/v1/auth/device') {
        return http.Response(_session('old-access', 'reused'), 201);
      }
      return http.Response(jsonEncode(<String, dynamic>{'code': 'refresh_token_reuse'}), 401);
    });
    final controller = AuthController(NoctaApiClient(baseUrl: 'http://x', client: client), store);
    await controller.registerAnonymously('fp');

    await expectLater(
      controller.authorizedRequest((_) async => http.Response('unauthorized', 401)),
      throwsA(isA<ApiException>()),
    );
    expect(controller.isAuthenticated, isFalse); // oturum geçersiz → temizlendi
    expect(await store.read(), isNull);
  });

  test('revokeOtherSessions: refresh token gönderir, revoked sayısını döner', () async {
    final store = InMemorySessionStore();
    late Map<String, dynamic> body;
    final client = MockClient((req) async {
      if (req.url.path == '/v1/auth/device') {
        return http.Response(_session('access', 'my-refresh'), 201);
      }
      if (req.url.path == '/v1/auth/sessions/revoke-others') {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(<String, dynamic>{'revoked': 2}), 200);
      }
      return http.Response('not found', 404);
    });
    final controller = AuthController(NoctaApiClient(baseUrl: 'http://x', client: client), store);
    await controller.registerAnonymously('fp');

    final revoked = await controller.revokeOtherSessions();
    expect(revoked, 2);
    expect(body['refreshToken'], 'my-refresh'); // güncel oturum token'ı
  });

  test('authorizedRequest: 200 → refresh çağrılmaz, yanıt aynen döner', () async {
    final store = InMemorySessionStore();
    var refreshCalls = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/v1/auth/device') {
        return http.Response(_session('access', 'refresh'), 201);
      }
      if (req.url.path == '/v1/auth/refresh') refreshCalls++;
      return http.Response('', 200);
    });
    final controller = AuthController(NoctaApiClient(baseUrl: 'http://x', client: client), store);
    await controller.registerAnonymously('fp');

    final res = await controller.authorizedRequest((_) async => http.Response('data', 200));
    expect(res.statusCode, 200);
    expect(res.body, 'data');
    expect(refreshCalls, 0);
  });
}
