import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/archetype/presentation/archetype_detail_screen.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/l10n/app_localizations.dart';

const _info = ArchetypeInfo(
  slug: 'deep-ocean',
  name: 'Deep Ocean',
  tagline: 'Sinks into stillness',
  summary: 'You drift into deep, quiet water and let the night hold you.',
);

Soundscape _s(String slug, String title) => Soundscape(
  id: 'id-$slug',
  slug: slug,
  titleI18n: {'en': title},
  archetypeAffinity: const ['deep-ocean'],
  version: 1,
);

Future<void> _pump(
  WidgetTester tester,
  String slug,
  List<Override> overrides,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // Varsayılan: uygun ses yok → bölüm gizli. İlgili test kendi kurar.
        soundscapesForArchetypeProvider.overrideWith(
          (ref, arg) async => <Soundscape>[],
        ),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
        home: ArchetypeDetailScreen(slug: slug),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bilinen slug → isim + tagline + özet gösterilir', (
    tester,
  ) async {
    await _pump(tester, 'deep-ocean', [
      archetypeContentProvider.overrideWith(
        (ref) async => const {'deep-ocean': _info},
      ),
    ]);
    expect(find.byKey(const Key('detail-name')), findsOneWidget);
    expect(find.text('Deep Ocean'), findsOneWidget);
    expect(find.text('Sinks into stillness'), findsOneWidget);
    expect(find.textContaining('deep, quiet water'), findsOneWidget);
  });

  testWidgets('bilinmeyen slug → "Unknown identity"', (tester) async {
    await _pump(tester, 'nope', [
      archetypeContentProvider.overrideWith(
        (ref) async => const {'deep-ocean': _info},
      ),
    ]);
    expect(find.byKey(const Key('identity-unknown')), findsOneWidget);
    expect(find.byKey(const Key('detail-name')), findsNothing);
  });

  testWidgets('içerik hatası → retry butonu', (tester) async {
    await _pump(tester, 'deep-ocean', [
      archetypeContentProvider.overrideWith(
        (ref) async => throw Exception('ağ'),
      ),
    ]);
    expect(find.byKey(const Key('detail-retry')), findsOneWidget);
  });

  testWidgets('uygun sesler listelenir ("sana uygun sesler")', (tester) async {
    await _pump(tester, 'deep-ocean', [
      archetypeContentProvider.overrideWith(
        (ref) async => const {'deep-ocean': _info},
      ),
      soundscapesForArchetypeProvider.overrideWith(
        (ref, arg) async => [_s('abyss', 'Abyss'), _s('tide', 'Tide')],
      ),
    ]);
    expect(find.byKey(const Key('sounds-heading')), findsOneWidget);
    expect(find.byKey(const Key('detail-sound-abyss')), findsOneWidget);
    expect(find.text('Abyss'), findsOneWidget);
    expect(find.text('Tide'), findsOneWidget);
  });

  testWidgets('uygun ses yoksa bölüm gizli (detay yine görünür)', (
    tester,
  ) async {
    await _pump(tester, 'deep-ocean', [
      archetypeContentProvider.overrideWith(
        (ref) async => const {'deep-ocean': _info},
      ),
      // default: boş liste
    ]);
    expect(find.byKey(const Key('sounds-heading')), findsNothing);
    expect(
      find.byKey(const Key('detail-name')),
      findsOneWidget,
    ); // detay bloklanmaz
  });

  testWidgets('ses listesi hatası detayı bloklamaz (bölüm gizli)', (
    tester,
  ) async {
    await _pump(tester, 'deep-ocean', [
      archetypeContentProvider.overrideWith(
        (ref) async => const {'deep-ocean': _info},
      ),
      soundscapesForArchetypeProvider.overrideWith(
        (ref, arg) async => throw Exception('ağ'),
      ),
    ]);
    expect(find.byKey(const Key('sounds-heading')), findsNothing);
    expect(find.byKey(const Key('detail-name')), findsOneWidget);
  });
}
