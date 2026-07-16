import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/archetype/presentation/archetype_detail_screen.dart';

const _info = ArchetypeInfo(
  slug: 'deep-ocean',
  name: 'Deep Ocean',
  tagline: 'Sinks into stillness',
  summary: 'You drift into deep, quiet water and let the night hold you.',
);

Future<void> _pump(WidgetTester tester, String slug, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildNoctaDarkTheme(),
        home: ArchetypeDetailScreen(slug: slug),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bilinen slug → isim + tagline + özet gösterilir', (tester) async {
    await _pump(tester, 'deep-ocean', [
      archetypeContentProvider.overrideWith((ref) async => const {'deep-ocean': _info}),
    ]);
    expect(find.byKey(const Key('detail-name')), findsOneWidget);
    expect(find.text('Deep Ocean'), findsOneWidget);
    expect(find.text('Sinks into stillness'), findsOneWidget);
    expect(find.textContaining('deep, quiet water'), findsOneWidget);
  });

  testWidgets('bilinmeyen slug → "Unknown identity"', (tester) async {
    await _pump(tester, 'nope', [
      archetypeContentProvider.overrideWith((ref) async => const {'deep-ocean': _info}),
    ]);
    expect(find.byKey(const Key('identity-unknown')), findsOneWidget);
    expect(find.byKey(const Key('detail-name')), findsNothing);
  });

  testWidgets('içerik hatası → retry butonu', (tester) async {
    await _pump(tester, 'deep-ocean', [
      archetypeContentProvider.overrideWith((ref) async => throw Exception('ağ')),
    ]);
    expect(find.byKey(const Key('detail-retry')), findsOneWidget);
  });
}
