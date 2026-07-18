import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/content/presentation/soundscape_detail_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

Soundscape _s(String slug) => Soundscape(
  id: 'id-$slug',
  slug: slug,
  titleI18n: const {'en': 'Deep Ocean'},
  archetypeAffinity: const [],
  version: 1,
);

Future<void> _pump(
  WidgetTester tester,
  String slug,
  List<Override> overrides,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        home: SoundscapeDetailScreen(slug: slug),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detay: başlık + preset sayısı + preview göstergesi', (
    tester,
  ) async {
    await _pump(tester, 'deep-ocean', [
      soundscapeDetailProvider('deep-ocean').overrideWith(
        (ref) async => SoundscapeDetail(
          soundscape: _s('deep-ocean'),
          presets: [
            const Preset(archetypeSlug: 'deep-ocean', mixerState: null),
          ],
          previewUrl: 'https://minio/x?sig=1',
        ),
      ),
    ]);

    expect(find.byKey(const Key('soundscape-detail-title')), findsOneWidget);
    expect(find.text('Deep Ocean'), findsOneWidget);
    expect(find.text('1 preset'), findsOneWidget);
    expect(find.byKey(const Key('soundscape-preview')), findsOneWidget);
  });

  testWidgets('previewUrl yoksa gösterge yok', (tester) async {
    await _pump(tester, 'rain', [
      soundscapeDetailProvider('rain').overrideWith(
        (ref) async => SoundscapeDetail(
          soundscape: _s('rain'),
          presets: const [],
          previewUrl: null,
        ),
      ),
    ]);
    expect(find.text('0 presets'), findsOneWidget);
    expect(find.byKey(const Key('soundscape-preview')), findsNothing);
  });

  testWidgets('yok (404 → null) → not found', (tester) async {
    await _pump(tester, 'yok', [
      soundscapeDetailProvider('yok').overrideWith((ref) async => null),
    ]);
    expect(find.byKey(const Key('soundscape-detail-notfound')), findsOneWidget);
  });

  testWidgets('birincil eylem: "bu sesi çal" butonu var', (tester) async {
    await _pump(tester, 'deep-ocean', [
      soundscapeDetailProvider('deep-ocean').overrideWith(
        (ref) async => SoundscapeDetail(
          soundscape: _s('deep-ocean'),
          presets: const [],
          previewUrl: null,
        ),
      ),
    ]);
    expect(find.byKey(const Key('soundscape-play')), findsOneWidget);
    expect(find.text('Play this sound'), findsOneWidget);
  });

  testWidgets('çal butonu mikseri BU sesin slug\'ıyla açar', (tester) async {
    String? mixerLocation;
    final router = GoRouter(
      initialLocation: '/library/deep-ocean',
      routes: [
        GoRoute(
          path: '/library/:slug',
          builder: (c, s) =>
              SoundscapeDetailScreen(slug: s.pathParameters['slug'] ?? ''),
        ),
        GoRoute(
          path: '/mixer',
          builder: (c, s) {
            mixerLocation = s.uri.toString();
            return const Scaffold(body: Text('mixer'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soundscapeDetailProvider('deep-ocean').overrideWith(
            (ref) async => SoundscapeDetail(
              soundscape: _s('deep-ocean'),
              presets: const [],
              previewUrl: null,
            ),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildNoctaDarkTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('soundscape-play')));
    await tester.pumpAndSettle();

    // Slug URL'de yaşar (go_router `extra` DEĞİL): derin link ve yeniden
    // başlatma tarifi kaybetmez.
    expect(mixerLocation, '/mixer?soundscape=deep-ocean');
  });

  testWidgets('hata → retry', (tester) async {
    await _pump(tester, 'x', [
      soundscapeDetailProvider(
        'x',
      ).overrideWith((ref) async => throw Exception('ağ')),
    ]);
    expect(find.byKey(const Key('soundscape-detail-retry')), findsOneWidget);
  });
}
