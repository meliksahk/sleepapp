import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/content/presentation/soundscape_library_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

Soundscape _s(String slug, String title, {List<String> affinity = const []}) =>
    Soundscape(
      id: 'id-$slug',
      slug: slug,
      titleI18n: {'en': title},
      archetypeAffinity: affinity,
      version: 1,
    );

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        home: const SoundscapeLibraryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('affinityLabel: slug\'ları okunur etikete çevirir (ilk 2)', () {
    expect(
      _s(
        'x',
        'X',
        affinity: const ['deep-ocean', 'delta-drifter'],
      ).affinityLabel(),
      'Deep Ocean · Delta Drifter',
    );
    expect(
      _s('x', 'X', affinity: const ['a', 'b', 'c']).affinityLabel(max: 2),
      'A · B',
    ); // yalnızca ilk 2
    expect(_s('x', 'X').affinityLabel(), ''); // boş affinity
  });

  testWidgets('feed listelenir + affinity altyazısı gösterilir', (
    tester,
  ) async {
    await _pump(tester, [
      soundscapeFeedProvider.overrideWith(
        (ref) async => [
          _s(
            'deep-ocean',
            'Deep Ocean',
            affinity: const ['deep-ocean', 'delta-drifter'],
          ),
          _s('rain', 'Rain'),
        ],
      ),
    ]);

    expect(find.byKey(const Key('soundscape-deep-ocean')), findsOneWidget);
    expect(find.text('Deep Ocean'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
    // affinity olan kartta altyazı, olmayanda yok
    expect(
      find.byKey(const Key('soundscape-affinity-deep-ocean')),
      findsOneWidget,
    );
    expect(find.text('For Deep Ocean · Delta Drifter'), findsOneWidget);
    expect(find.byKey(const Key('soundscape-affinity-rain')), findsNothing);
  });

  testWidgets('boş feed → empty state', (tester) async {
    await _pump(tester, [
      soundscapeFeedProvider.overrideWith((ref) async => <Soundscape>[]),
    ]);
    expect(find.byKey(const Key('soundscape-empty')), findsOneWidget);
  });

  testWidgets('hata → retry butonu', (tester) async {
    await _pump(tester, [
      soundscapeFeedProvider.overrideWith((ref) async => throw Exception('ağ')),
    ]);
    expect(find.byKey(const Key('soundscape-retry')), findsOneWidget);
  });

  group('dil: kategori etiketleri ve başlıklar arayüz dilinde', () {
    // Bu grup öncesinde çipler ve rozet sabit Türkçeydi, başlık sabit
    // İngilizceydi: EN kullanıcı "Tümü / Gürültüler" görüyor, TR kullanıcı
    // Türkçe başlığı olan tarifi İngilizce okuyordu.
    final feed = <Soundscape>[
      Soundscape(
        id: 'id-soft-rain',
        slug: 'soft-rain',
        titleI18n: const {'en': 'Soft Rain', 'tr': 'Yumuşak Yağmur'},
        archetypeAffinity: const [],
        version: 1,
        category: 'noise',
      ),
    ];

    Future<void> pumpIn(WidgetTester t, Locale locale) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [soundscapeFeedProvider.overrideWith((ref) async => feed)],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: buildNoctaDarkTheme(),
            home: const SoundscapeLibraryScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('EN: çipler, rozet ve başlık İngilizce; Türkçe kelime yok', (t) async {
      await pumpIn(t, const Locale('en'));

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Noise'), findsNWidgets(2)); // çip + rozet
      expect(find.text('Nature'), findsOneWidget);
      expect(find.text('Relaxing'), findsOneWidget);
      expect(find.text('Soft Rain'), findsOneWidget);
      for (final tr in ['Tümü', 'Gürültüler', 'Gürültü', 'Doğadan', 'Rahatlatıcı', 'Yumuşak Yağmur']) {
        expect(find.text(tr), findsNothing, reason: tr);
      }
    });

    testWidgets('TR: çipler, rozet ve başlık Türkçe', (t) async {
      await pumpIn(t, const Locale('tr'));

      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('Gürültüler'), findsOneWidget);
      expect(find.text('Gürültü'), findsOneWidget); // rozet
      expect(find.text('Doğadan'), findsOneWidget);
      expect(find.text('Yumuşak Yağmur'), findsOneWidget);
      expect(find.text('Soft Rain'), findsNothing);
    });
  });
}
