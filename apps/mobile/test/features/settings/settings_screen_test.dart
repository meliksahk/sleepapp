import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/auth/session_info.dart';
import 'package:nocta/features/settings/presentation/settings_screen.dart';

Future<AuthController> _auth(int revoked) async {
  final client = MockClient((req) async {
    if (req.url.path == '/v1/auth/device') {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'accessToken': 'a',
          'refreshToken': 'r',
          'accessTokenExpiresIn': 900,
          'userId': 'u-1',
        }),
        201,
      );
    }
    if (req.url.path == '/v1/auth/sessions/revoke-others') {
      return http.Response(jsonEncode(<String, dynamic>{'revoked': revoked}), 200);
    }
    return http.Response('not found', 404);
  });
  final auth = AuthController(NoctaApiClient(baseUrl: 'http://x', client: client), InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return auth;
}

Future<void> _pump(WidgetTester tester, AuthController auth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[authControllerProvider.overrideWithValue(auth)],
      child: MaterialApp(theme: buildNoctaDarkTheme(), home: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('diğer cihazlardan çık → sayı SnackBar\'da (çoğul)', (tester) async {
    await _pump(tester, await _auth(2));
    await tester.tap(find.byKey(const Key('revoke-others')));
    await tester.pumpAndSettle();
    expect(find.text('2 other devices signed out'), findsOneWidget);
  });

  testWidgets('tek cihaz → tekil metin', (tester) async {
    await _pump(tester, await _auth(1));
    await tester.tap(find.byKey(const Key('revoke-others')));
    await tester.pumpAndSettle();
    expect(find.text('1 other device signed out'), findsOneWidget);
  });

  testWidgets('aktif cihaz sayısı gösterilir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          activeSessionsProvider.overrideWith(
            (ref) async => const [
              SessionInfo(familyId: 'a', createdAt: '2026-01-01', expiresAt: '2026-02-01'),
              SessionInfo(familyId: 'b', createdAt: '2026-01-02', expiresAt: '2026-02-02'),
            ],
          ),
        ],
        child: MaterialApp(theme: buildNoctaDarkTheme(), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('active-devices')), findsOneWidget);
    expect(find.text('Active devices: 2'), findsOneWidget);
  });
}
