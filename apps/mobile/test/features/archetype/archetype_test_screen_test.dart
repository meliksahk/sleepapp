import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/archetype/archetype_controller.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/archetype/presentation/archetype_test_screen.dart';
import 'package:nocta/features/auth/auth_controller.dart';

String _questions() => jsonEncode(<String, dynamic>{
  'version': 1,
  'questions': [
    {
      'id': 'q1',
      'prompt': 'How do you fall asleep?',
      'options': [
        {'id': 'q1a', 'label': 'Fast', 'archetype': 'deep-ocean'},
        {'id': 'q1b', 'label': 'Slowly', 'archetype': 'overthinker'},
      ],
    },
  ],
});

Future<ArchetypeController> _controller() async {
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
    if (req.url.path == '/v1/archetype/questions') {
      return http.Response(_questions(), 200);
    }
    if (req.url.path == '/v1/archetype/answers') {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'userId': 'u-1',
          'archetypeSlug': 'deep-ocean',
          'scores': {'deep-ocean': 3},
          'version': 1,
          'createdAt': '2026-07-16T00:00:00.000Z',
        }),
        201,
      );
    }
    return http.Response('not found', 404);
  });
  final api = NoctaApiClient(baseUrl: 'http://x', client: client);
  final auth = AuthController(api, InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return ArchetypeController(auth, api);
}

Future<void> _pump(WidgetTester tester, ArchetypeController controller) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[archetypeControllerProvider.overrideWithValue(controller)],
      child: MaterialApp(theme: buildNoctaDarkTheme(), home: const ArchetypeTestScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('soruları yükler, cevaplar, sonucu gösterir', (tester) async {
    await _pump(tester, await _controller());

    // Soru yüklendi.
    expect(find.text('How do you fall asleep?'), findsOneWidget);
    expect(find.byKey(const Key('archetype-result')), findsNothing);

    // Cevaplamadan submit → hâlâ sonuç yok (gating).
    await tester.tap(find.byKey(const Key('archetype-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archetype-result')), findsNothing);

    // Seçenek seç → submit → sonuç.
    await tester.tap(find.byKey(const Key('opt-q1-q1a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archetype-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archetype-result')), findsOneWidget);
    expect(find.text('Deep Ocean'), findsOneWidget); // slug → görünen ad
  });
}
