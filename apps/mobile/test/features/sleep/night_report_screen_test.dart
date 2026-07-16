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
import 'package:nocta/features/archetype/archetype_providers.dart' show sharerProvider;
import 'package:nocta/features/auth/auth_controller.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/sleep/presentation/night_report_screen.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';

const _night = '2026-03-10';

const _report = NightReport(
  nightDate: _night,
  sessionCount: 2,
  totalDurationMinutes: 462,
  movementEvents: 12,
  soundEvents: 3,
  calmScore: 85,
);

/// Paylaşımları kaydeden sahte Sharer (native pano yerine).
class RecordingSharer implements Sharer {
  final List<ShareContent> shared = [];
  @override
  Future<void> share(ShareContent content) async => shared.add(content);
}

/// İzlenen olayları kaydeden sahte Analytics (ağa çıkmaz).
class RecordingAnalytics implements Analytics {
  final List<String> events = [];
  @override
  void track(String name, {Map<String, dynamic>? props}) => events.add(name);
  @override
  Future<int> flush() async => 0;
}

/// /v1/sharing/report ucunu yönlendiren MockClient tabanlı auth+api.
Future<(NoctaApiClient, AuthController)> _api({required bool hasShare}) async {
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
    if (req.url.path == '/v1/sharing/report') {
      if (!hasShare) return http.Response('not found', 404);
      return http.Response(
        jsonEncode(<String, dynamic>{
          'nightDate': _night,
          'title': 'My night: 7h 42m',
          'subtitle': 'Calm 85/100 · NOCTA sleep ritual',
          'durationText': '7h 42m',
          'calmScore': 85,
          'webUrl': 'https://nocta.app/r/abc',
          'deepLink': 'nocta://report/$_night',
        }),
        200,
      );
    }
    return http.Response('not found', 404);
  });
  final api = NoctaApiClient(baseUrl: 'http://x', client: client);
  final auth = AuthController(api, InMemorySessionStore());
  await auth.registerAnonymously('fp');
  return (api, auth);
}

Future<(RecordingSharer, RecordingAnalytics)> _pump(
  WidgetTester tester, {
  required List<Override> overrides,
  bool hasShare = true,
}) async {
  final (api, auth) = await _api(hasShare: hasShare);
  final sharer = RecordingSharer();
  final analytics = RecordingAnalytics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authControllerProvider.overrideWithValue(auth),
        apiClientProvider.overrideWithValue(api),
        sharerProvider.overrideWithValue(sharer),
        analyticsProvider.overrideWithValue(analytics),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildNoctaDarkTheme(),
        home: const NightReportScreen(nightDate: _night),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (sharer, analytics);
}

void main() {
  testWidgets('rapor gösterilir (süre + calm + olaylar)', (tester) async {
    await _pump(
      tester,
      overrides: [nightReportProvider(_night).overrideWith((ref) async => _report)],
    );

    expect(find.byKey(const Key('report-duration')), findsOneWidget);
    expect(find.text('7h 42m'), findsOneWidget);
    expect(find.byKey(const Key('report-calm')), findsOneWidget);
    expect(find.text('Calm 85/100'), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // movement
    expect(find.text('3'), findsOneWidget); // sound
  });

  testWidgets('calm skoru sağlık iddiası taşımaz (uyarı metni)', (tester) async {
    await _pump(
      tester,
      overrides: [nightReportProvider(_night).overrideWith((ref) async => _report)],
    );
    expect(find.textContaining('not a health score'), findsOneWidget);
  });

  testWidgets('rapor yoksa (null) → empty state', (tester) async {
    await _pump(
      tester,
      overrides: [nightReportProvider(_night).overrideWith((ref) async => null)],
    );
    expect(find.byKey(const Key('report-empty')), findsOneWidget);
    expect(find.byKey(const Key('report-duration')), findsNothing);
  });

  testWidgets('hata → retry butonu', (tester) async {
    await _pump(
      tester,
      overrides: [
        nightReportProvider(_night).overrideWith((ref) async => throw Exception('ağ')),
      ],
    );
    expect(find.byKey(const Key('report-retry')), findsOneWidget);
  });

  testWidgets('paylaş → sunucudan gelen kart metni paylaşılır + report_shared izlenir', (
    tester,
  ) async {
    final (sharer, analytics) = await _pump(
      tester,
      overrides: [nightReportProvider(_night).overrideWith((ref) async => _report)],
    );

    await tester.tap(find.byKey(const Key('report-share')));
    await tester.pumpAndSettle();

    expect(sharer.shared, hasLength(1));
    expect(sharer.shared.first.text, 'My night: 7h 42m');
    expect(sharer.shared.first.url, 'https://nocta.app/r/abc');
    expect(find.text('Link copied'), findsOneWidget);
    // Viral huni: paylaşım başarılıysa olay (sözlükte tanımlı).
    expect(analytics.events, contains('report_shared'));
  });

  testWidgets('paylaşım kartı yoksa (404) → bilgilendirme, paylaşım + olay yok', (tester) async {
    final (sharer, analytics) = await _pump(
      tester,
      hasShare: false,
      overrides: [nightReportProvider(_night).overrideWith((ref) async => _report)],
    );

    await tester.tap(find.byKey(const Key('report-share')));
    await tester.pumpAndSettle();

    expect(sharer.shared, isEmpty);
    expect(find.text('No report for this night'), findsOneWidget);
    expect(analytics.events, isEmpty); // paylaşım olmadıysa olay da yok
  });
}
