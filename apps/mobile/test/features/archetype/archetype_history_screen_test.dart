import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/archetype/presentation/archetype_history_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

ArchetypeResult _r(String slug, String createdAt) => ArchetypeResult(
  userId: 'u-1',
  archetypeSlug: slug,
  scores: const {},
  version: 1,
  createdAt: createdAt,
);

const _content = <String, ArchetypeInfo>{
  'deep-ocean': ArchetypeInfo(
    slug: 'deep-ocean',
    name: 'Deep Ocean',
    tagline: 'Sinks into stillness',
    summary: '...',
  ),
  'overthinker': ArchetypeInfo(
    slug: 'overthinker',
    name: '3AM Overthinker',
    tagline: 'Mind races at night',
    summary: '...',
  ),
};

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        archetypeContentProvider.overrideWith((ref) async => _content),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        home: const ArchetypeHistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'geçmiş listelenir: isimler çözülür, en yenide "Current" rozeti',
    (tester) async {
      await _pump(tester, [
        archetypeHistoryProvider.overrideWith(
          (ref) async => [
            _r(
              'deep-ocean',
              '2026-07-16T10:00:00.000Z',
            ), // en yeni (sunucu sırası)
            _r('overthinker', '2026-03-02T22:00:00.000Z'),
          ],
        ),
      ]);

      expect(find.text('Deep Ocean'), findsOneWidget);
      expect(find.text('3AM Overthinker'), findsOneWidget);
      // ISO tarihin yalnızca gün kısmı (intl bağımlılığı yok)
      expect(find.text('2026-07-16'), findsOneWidget);
      expect(find.text('2026-03-02'), findsOneWidget);
      // "Current" yalnızca ilk (en yeni) kayıtta
      expect(find.byKey(const Key('history-current-badge')), findsOneWidget);
    },
  );

  testWidgets('içerik yüklenmese de slug ile listelenir (dayanıklı)', (
    tester,
  ) async {
    await _pump(tester, [
      archetypeContentProvider.overrideWith(
        (ref) async => <String, ArchetypeInfo>{},
      ),
      archetypeHistoryProvider.overrideWith(
        (ref) async => [_r('dawn-chaser', '2026-07-16T10:00:00.000Z')],
      ),
    ]);
    expect(find.text('dawn-chaser'), findsOneWidget);
  });

  testWidgets('boş geçmiş → empty state', (tester) async {
    await _pump(tester, [
      archetypeHistoryProvider.overrideWith((ref) async => <ArchetypeResult>[]),
    ]);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
  });

  testWidgets('hata → retry', (tester) async {
    await _pump(tester, [
      archetypeHistoryProvider.overrideWith(
        (ref) async => throw Exception('ağ'),
      ),
    ]);
    expect(find.byKey(const Key('history-retry')), findsOneWidget);
  });
}
