import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/content/presentation/soundscape_library_screen.dart';

Soundscape _s(String slug, String title, {List<String> affinity = const []}) => Soundscape(
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
      child: MaterialApp(theme: buildNoctaDarkTheme(), home: const SoundscapeLibraryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('affinityLabel: slug\'ları okunur etikete çevirir (ilk 2)', () {
    expect(
      _s('x', 'X', affinity: const ['deep-ocean', 'delta-drifter']).affinityLabel(),
      'Deep Ocean · Delta Drifter',
    );
    expect(
      _s('x', 'X', affinity: const ['a', 'b', 'c']).affinityLabel(max: 2),
      'A · B',
    ); // yalnızca ilk 2
    expect(_s('x', 'X').affinityLabel(), ''); // boş affinity
  });

  testWidgets('feed listelenir + affinity altyazısı gösterilir', (tester) async {
    await _pump(tester, [
      soundscapeFeedProvider.overrideWith(
        (ref) async => [
          _s('deep-ocean', 'Deep Ocean', affinity: const ['deep-ocean', 'delta-drifter']),
          _s('rain', 'Rain'),
        ],
      ),
    ]);

    expect(find.byKey(const Key('soundscape-deep-ocean')), findsOneWidget);
    expect(find.text('Deep Ocean'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
    // affinity olan kartta altyazı, olmayanda yok
    expect(find.byKey(const Key('soundscape-affinity-deep-ocean')), findsOneWidget);
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
}
