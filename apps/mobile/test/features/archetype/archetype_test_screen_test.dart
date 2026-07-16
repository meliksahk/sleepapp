import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nocta/core/api/nocta_api_client.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/share/sharer.dart';
import 'package:nocta/core/storage/session_store.dart';
import 'package:nocta/features/analytics/analytics.dart';
import 'package:nocta/features/analytics/analytics_providers.dart';
import 'package:nocta/features/archetype/archetype_controller.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/archetype/presentation/archetype_test_screen.dart';
import 'package:nocta/features/auth/auth_controller.dart';

class RecordingAnalytics implements Analytics {
  final List<String> events = [];
  Map<String, dynamic>? lastProps;
  @override
  void track(String name, {Map<String, dynamic>? props}) {
    events.add(name);
    lastProps = props;
  }

  @override
  Future<int> flush() async => 0;
}

class RecordingSharer implements Sharer {
  ShareContent? last;
  @override
  Future<void> share(ShareContent content) async => last = content;
}

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

Future<ArchetypeController> _controller({bool existingResult = false}) async {
  final client = MockClient((req) async {
    if (req.url.path == '/v1/archetype/result') {
      if (!existingResult) return http.Response('not found', 404);
      return http.Response(
        jsonEncode(<String, dynamic>{
          'userId': 'u-1',
          'archetypeSlug': 'overthinker',
          'scores': {'overthinker': 4},
          'version': 1,
          'createdAt': '2026-07-16T00:00:00.000Z',
        }),
        200,
      );
    }
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
    if (req.url.path == '/v1/archetype/content') {
      return http.Response(
        jsonEncode(<dynamic>[
          {
            'slug': 'deep-ocean',
            'name': 'Deep Ocean',
            'tagline': 'You sink into stillness.',
            'summary': 'You drop into deep, quiet rest quickly.',
          },
        ]),
        200,
      );
    }
    if (req.url.path == '/v1/sharing/archetype') {
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
    }
    return http.Response('not found', 404);
  });
  final api = NoctaApiClient(baseUrl: 'http://x', client: client);
  final auth = AuthController(api, InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return ArchetypeController(auth, api);
}

Future<void> _pump(
  WidgetTester tester,
  ArchetypeController controller, {
  Sharer? sharer,
  RecordingAnalytics? analytics,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        archetypeControllerProvider.overrideWithValue(controller),
        // Analytics override — default'u apiClientProvider→FlavorConfig okur (testte yok).
        analyticsProvider.overrideWithValue(analytics ?? RecordingAnalytics()),
        if (sharer != null) sharerProvider.overrideWithValue(sharer),
      ],
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
    // Tanıtım içeriği (public uç) geldiyse tagline gösterilir.
    expect(find.byKey(const Key('archetype-tagline')), findsOneWidget);
    expect(find.text('You sink into stillness.'), findsOneWidget);
  });

  testWidgets('sonuç görüntülenince archetype_completed analitik olayı gönderilir', (tester) async {
    final analytics = RecordingAnalytics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          archetypeControllerProvider.overrideWithValue(await _controller()),
          analyticsProvider.overrideWithValue(analytics),
        ],
        child: MaterialApp(theme: buildNoctaDarkTheme(), home: const ArchetypeTestScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opt-q1-q1a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archetype-submit')));
    await tester.pumpAndSettle();

    expect(analytics.events, contains('archetype_completed'));
    expect(analytics.lastProps?['archetype'], 'deep-ocean');
  });

  testWidgets('sonuçta paylaş → sharer web URL alır, "Link copied" + share_tapped', (tester) async {
    final sharer = RecordingSharer();
    final analytics = RecordingAnalytics();
    await _pump(tester, await _controller(), sharer: sharer, analytics: analytics);

    // Cevapla → sonuç.
    await tester.tap(find.byKey(const Key('opt-q1-q1a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archetype-submit')));
    await tester.pumpAndSettle();

    // Paylaş → sharer'a paylaşım kartı iletilir + SnackBar.
    await tester.tap(find.byKey(const Key('archetype-share')));
    await tester.pumpAndSettle();

    expect(sharer.last?.url, 'https://nocta.app/a/deep-ocean');
    expect(sharer.last?.text, contains('Deep Ocean'));
    expect(find.text('Link copied'), findsOneWidget);
    // Viral huni: sonuç görüldü + paylaşıldı.
    expect(analytics.events, containsAll(<String>['archetype_completed', 'share_tapped']));
  });

  testWidgets('kayıtlı sonuç varsa doğrudan sonucu gösterir (sihirbaz atlanır)', (tester) async {
    await _pump(tester, await _controller(existingResult: true));

    expect(find.byKey(const Key('archetype-result')), findsOneWidget);
    expect(find.text('Overthinker'), findsOneWidget);
    // Sihirbaz gösterilmez (soru/submit yok).
    expect(find.byKey(const Key('archetype-submit')), findsNothing);
  });

  testWidgets('Retake → sonuçtan sihirbaza döner', (tester) async {
    await _pump(tester, await _controller(existingResult: true));
    expect(find.byKey(const Key('archetype-result')), findsOneWidget);

    await tester.tap(find.byKey(const Key('archetype-retake')));
    await tester.pumpAndSettle();

    // Sihirbaz göründü: soru + submit var, sonuç yok.
    expect(find.text('How do you fall asleep?'), findsOneWidget);
    expect(find.byKey(const Key('archetype-submit')), findsOneWidget);
    expect(find.byKey(const Key('archetype-result')), findsNothing);
  });
}
