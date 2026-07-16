import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/l10n/app_localizations.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/home/home_screen.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';

ArchetypeResult _result(String slug) => ArchetypeResult(
  userId: 'u-1',
  archetypeSlug: slug,
  scores: const {},
  version: 1,
  createdAt: '2026-07-16T00:00:00.000Z',
);

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  FlavorConfig.current = const FlavorConfig(
    flavor: Flavor.dev,
    name: 'DEV',
    apiBaseUrl: 'http://localhost:3001',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // Varsayılan: test sonucu yok + boş içerik (kimlik kartı gizli). İlgili test kendi kurar.
        latestArchetypeResultProvider.overrideWith((ref) async => null),
        archetypeContentProvider.overrideWith((ref) async => <String, ArchetypeInfo>{}),
        // Varsayılan: geçmiş yok → bağlantı gizli.
        archetypeHistoryProvider.overrideWith((ref) async => <ArchetypeResult>[]),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        home: const HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('streak verisi gelince kart + kişisel rekor görünür', (tester) async {
    await _pump(tester, [
      streakProvider.overrideWith(
        (ref) async => const StreakStats(current: 5, longest: 12, totalNights: 40),
      ),
    ]);

    expect(find.byKey(const Key('streak-current')), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('nights streak'), findsOneWidget);
    expect(find.byKey(const Key('streak-best')), findsOneWidget);
    expect(find.text('Best 12'), findsOneWidget); // longest > current
    expect(find.text('NOCTA'), findsOneWidget); // home yine render
  });

  testWidgets('streak tek gece → tekil metin, rekor satırı yok (longest == current)', (
    tester,
  ) async {
    await _pump(tester, [
      streakProvider.overrideWith(
        (ref) async => const StreakStats(current: 1, longest: 1, totalNights: 1),
      ),
    ]);
    expect(find.text('night streak'), findsOneWidget);
    expect(find.byKey(const Key('streak-best')), findsNothing);
  });

  testWidgets('kayıt yokken (totalNights 0) streak kartı gizli', (tester) async {
    await _pump(tester, [
      streakProvider.overrideWith(
        (ref) async => const StreakStats(current: 0, longest: 0, totalNights: 0),
      ),
    ]);
    expect(find.byKey(const Key('streak-current')), findsNothing);
    expect(find.text('NOCTA'), findsOneWidget);
  });

  testWidgets('seri kopmuş ama geçmiş var → 0 + kişisel rekor gösterilir', (tester) async {
    await _pump(tester, [
      streakProvider.overrideWith(
        (ref) async => const StreakStats(current: 0, longest: 12, totalNights: 40),
      ),
    ]);
    expect(find.byKey(const Key('streak-current')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Best 12'), findsOneWidget);
  });

  testWidgets('streak hatası home\'u bloklamaz (kart gizli)', (tester) async {
    await _pump(tester, [
      streakProvider.overrideWith((ref) async => throw Exception('ağ hatası')),
    ]);

    expect(find.byKey(const Key('streak-current')), findsNothing);
    expect(find.text('NOCTA'), findsOneWidget); // home yine görünür
    expect(find.textContaining('flavor: DEV'), findsOneWidget);
  });

  testWidgets('haftalık yayın kartı görünür (notes gösterilir)', (tester) async {
    await _pump(tester, [
      weeklyReleaseProvider.overrideWith(
        (ref) async => const WeeklyRelease(
          weekStart: '2026-07-13',
          notes: 'Yaz serisi',
          soundscapes: [],
        ),
      ),
    ]);

    expect(find.byKey(const Key('weekly-card')), findsOneWidget);
    expect(find.text('Yaz serisi'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
  });

  testWidgets('haftalık yayın yoksa (null) kart gizli, home bloklanmaz', (tester) async {
    await _pump(tester, [
      weeklyReleaseProvider.overrideWith((ref) async => null),
    ]);
    expect(find.byKey(const Key('weekly-card')), findsNothing);
    expect(find.text('NOCTA'), findsOneWidget);
  });

  testWidgets('sonuç varken kimlik kartı (içerik adı) + buton "Retake"', (tester) async {
    await _pump(tester, [
      latestArchetypeResultProvider.overrideWith((ref) async => _result('deep-ocean')),
      archetypeContentProvider.overrideWith(
        (ref) async => const {
          'deep-ocean': ArchetypeInfo(
            slug: 'deep-ocean',
            name: 'Deep Ocean',
            tagline: 'Sinks into stillness',
            summary: '...',
          ),
        },
      ),
    ]);

    expect(find.byKey(const Key('identity-name')), findsOneWidget);
    expect(find.text('Deep Ocean'), findsOneWidget);
    expect(find.text('Sinks into stillness'), findsOneWidget);
    expect(find.text('Retake the test'), findsOneWidget);
    expect(find.text('Find your sleep identity'), findsNothing);
  });

  testWidgets('sonuç yokken kimlik kartı gizli + buton "Find"', (tester) async {
    await _pump(tester, []); // default: result null
    expect(find.byKey(const Key('identity-name')), findsNothing);
    expect(find.text('Find your sleep identity'), findsOneWidget);
  });

  testWidgets('birden fazla sonuç → kimlik geçmişi bağlantısı görünür', (tester) async {
    await _pump(tester, [
      latestArchetypeResultProvider.overrideWith((ref) async => _result('deep-ocean')),
      archetypeHistoryProvider.overrideWith(
        (ref) async => [_result('deep-ocean'), _result('overthinker')],
      ),
    ]);
    expect(find.byKey(const Key('identity-history-link')), findsOneWidget);
    expect(find.text('2 identities over time'), findsOneWidget);
  });

  testWidgets('tek sonuç → geçmiş bağlantısı gizli (anlamsız olurdu)', (tester) async {
    await _pump(tester, [
      latestArchetypeResultProvider.overrideWith((ref) async => _result('deep-ocean')),
      archetypeHistoryProvider.overrideWith((ref) async => [_result('deep-ocean')]),
    ]);
    expect(find.byKey(const Key('identity-history-link')), findsNothing);
    expect(find.byKey(const Key('identity-name')), findsOneWidget); // kart yine görünür
  });

  testWidgets('içerik yüklenmese de sonuç slug ile kimlik kartı gösterilir', (tester) async {
    await _pump(tester, [
      latestArchetypeResultProvider.overrideWith((ref) async => _result('dawn-chaser')),
      // archetypeContentProvider default boş → info yok → slug fallback
    ]);
    expect(find.byKey(const Key('identity-name')), findsOneWidget);
    expect(find.text('dawn-chaser'), findsOneWidget);
    expect(find.text('Retake the test'), findsOneWidget);
  });
}
