import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/features/auth/auth_controller.dart';

void main() {
  test('registerAnonymously oturumu kurar (platform=flutter)', () async {
    final mock = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['platform'], 'flutter');
      expect(body['fingerprint'], 'device-xyz');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'accessToken': 'a',
          'refreshToken': 'r',
          'accessTokenExpiresIn': 900,
          'userId': 'u-1',
        }),
        201,
      );
    });
    final controller = AuthController(NoctaApiClient(baseUrl: 'http://x', client: mock));

    expect(controller.isAuthenticated, isFalse);
    await controller.registerAnonymously('device-xyz');
    expect(controller.isAuthenticated, isTrue);
    expect(controller.session?.userId, 'u-1');

    controller.signOut();
    expect(controller.isAuthenticated, isFalse);
  });
}
