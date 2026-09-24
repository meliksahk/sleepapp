import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/sleep/presentation/ritual_screen.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Ritüel/seri ekranı (F3).
///
/// **Neden test:** ay ızgarası kolayca yalan söyleyebilir — veri gelmemiş bir
/// geceyi "dolu" boyamak, kullanıcıya olmayan bir seri göstermek demektir.
void main() {
  SleepSession night(String date) => SleepSession(
    id: date,
    startedAt: '${date}T23:00:00Z',
    endedAt: '${date}T07:00:00Z',
    nightDate: date,
    durationMinutes: 480,
    movementEvents: 0,
    soundEvents: 2,
  );

  Future<void> pump(
    WidgetTester t, {
    required StreakStats streak,
    List<SleepSession> nights = const <SleepSession>[],
  }) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          streakProvider.overrideWith((ref) async => streak),
          recentSleepSessionsProvider.overrideWith((ref) async => nights),
          sleepStatsProvider.overrideWith(
            (ref) async => const SleepStats(
              nights: 3,
              totalDurationMinutes: 1440,
              averageDurationMinutes: 480,
            ),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildNoctaDarkTheme(),
          routerConfig: GoRouter(
            routes: <RouteBase>[
              GoRoute(path: '/', builder: (c, s) => const RitualScreen()),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('ÇEKİRDEK: seri sayısı ve istatistikler görünür', (t) async {
    await pump(
      t,
      streak: const StreakStats(current: 5, longest: 12, totalNights: 21),
    );
    expect(t.widget<Text>(find.byKey(const Key('ritual-current'))).data, '5');
    expect(find.text('12'), findsOneWidget); // en uzun
    expect(find.text('21'), findsOneWidget); // toplam
  });

  testWidgets('ÇEKİRDEK: ızgara YALNIZCA gerçek gecelerle dolar', (t) async {
    final now = DateTime.now();
    final String prefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-';
    await pump(
      t,
      streak: const StreakStats(current: 1, longest: 1, totalNights: 1),
      nights: <SleepSession>[night('${prefix}01')],
    );

    // Ayın gün sayısı kadar hücre var; yalnız BİRİ yırtık (dolu).
    final int days = DateTime(now.year, now.month + 1, 0).day;
    expect(find.byType(ClipPath), findsOneWidget);
    expect(find.byType(Container), findsAtLeast(days));
  });

  testWidgets('hiç gece yoksa BOŞ HAL — sahte ızgara çizilmez', (t) async {
    await pump(
      t,
      streak: const StreakStats(current: 0, longest: 0, totalNights: 0),
    );
    expect(find.byKey(const Key('ritual-empty')), findsOneWidget);
    expect(find.byKey(const Key('ritual-current')), findsNothing);
  });
}
