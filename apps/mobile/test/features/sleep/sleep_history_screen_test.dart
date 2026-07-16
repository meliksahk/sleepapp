import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';
import 'package:nocta/features/sleep/presentation/sleep_history_screen.dart';

SleepSession _s(String id, String night, int minutes) => SleepSession(
  id: id,
  startedAt: '2026-03-10T22:00:00.000Z',
  endedAt: '2026-03-11T04:00:00.000Z',
  nightDate: night,
  durationMinutes: minutes,
  movementEvents: 1,
  soundEvents: 0,
);

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // Default stats (nights:0 → başlık gizli); stats testi kendi scope'unu kurar.
        sleepStatsProvider.overrideWith(
          (ref) async =>
              const SleepStats(nights: 0, totalDurationMinutes: 0, averageDurationMinutes: 0),
        ),
        ...overrides,
      ],
      child: MaterialApp(theme: buildNoctaDarkTheme(), home: const SleepHistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('durationText biçimi', () {
    expect(_s('a', '2026-03-10', 462).durationText, '7h 42m');
    expect(_s('a', '2026-03-10', 420).durationText, '7h');
    expect(_s('a', '2026-03-10', 45).durationText, '45m');
  });

  testWidgets('oturumlar gece + süre ile listelenir', (tester) async {
    await _pump(tester, [
      recentSleepSessionsProvider.overrideWith(
        (ref) async => [_s('s1', '2026-03-10', 462), _s('s2', '2026-03-09', 420)],
      ),
    ]);

    expect(find.byKey(const Key('sleep-session-s1')), findsOneWidget);
    expect(find.text('2026-03-10'), findsOneWidget);
    expect(find.text('7h 42m'), findsOneWidget);
    expect(find.text('7h'), findsOneWidget);
  });

  testWidgets('boş → empty state', (tester) async {
    await _pump(tester, [
      recentSleepSessionsProvider.overrideWith((ref) async => <SleepSession>[]),
    ]);
    expect(find.byKey(const Key('sleep-history-empty')), findsOneWidget);
  });

  testWidgets('hata → retry', (tester) async {
    await _pump(tester, [
      recentSleepSessionsProvider.overrideWith((ref) async => throw Exception('ağ')),
    ]);
    expect(find.byKey(const Key('sleep-history-retry')), findsOneWidget);
  });

  testWidgets('istatistik başlığı gösterilir (nights + ortalama)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          recentSleepSessionsProvider.overrideWith((ref) async => [_s('s1', '2026-03-10', 462)]),
          sleepStatsProvider.overrideWith(
            (ref) async => const SleepStats(
              nights: 12,
              totalDurationMinutes: 5400,
              averageDurationMinutes: 450,
            ),
          ),
        ],
        child: MaterialApp(theme: buildNoctaDarkTheme(), home: const SleepHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sleep-stats')), findsOneWidget);
    expect(find.text('12 nights · avg 7h 30m'), findsOneWidget);
  });
}
