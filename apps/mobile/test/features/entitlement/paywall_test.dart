import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/entitlement/entitlement_models.dart';
import 'package:nocta/features/entitlement/entitlement_providers.dart';
import 'package:nocta/features/entitlement/presentation/paywall_screen.dart';
import 'package:nocta/features/sleep/presentation/sleep_history_screen.dart';
import 'package:nocta/features/sleep/presentation/weekly_trend_chart.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';
import 'package:nocta/l10n/app_localizations.dart';

WeeklyTrend _trendWithData() => const WeeklyTrend(
      nights: [
        TrendNight(nightDate: '2026-03-10', durationMinutes: 420),
        TrendNight(nightDate: '2026-03-11', durationMinutes: 400),
      ],
      averageDurationMinutes: 410,
      nightsWithData: 2,
    );

/// GoRouter harness: gate CTA + paywall `context.pop`/`push` router ister.
Future<void> _pump(
  WidgetTester t, {
  required Entitlement entitlement,
  String initial = '/',
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (c, s) => const SleepHistoryScreen()),
      GoRoute(path: '/paywall', builder: (c, s) => const PaywallScreen()),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        entitlementProvider.overrideWith((ref) => entitlement),
        sleepTrendProvider.overrideWith((ref) async => _trendWithData()),
        recentSleepSessionsProvider.overrideWith((ref) async => <SleepSession>[]),
        sleepStatsProvider.overrideWith(
          (ref) async =>
              const SleepStats(nights: 0, totalDurationMinutes: 0, averageDurationMinutes: 0),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildNoctaDarkTheme(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  const premium = Entitlement(tier: 'plus', premium: true);
  const free = Entitlement(tier: 'free', premium: false);

  group('haftalık trend premium kapısı', () {
    testWidgets('ÇEKİRDEK: premium kullanıcı GRAFİĞİ görür, kilit YOK', (t) async {
      await _pump(t, entitlement: premium);
      expect(find.byType(WeeklyTrendChart), findsOneWidget);
      expect(find.byKey(const Key('trend-premium-lock')), findsNothing);
    });

    testWidgets('ÇEKİRDEK: free kullanıcı KİLİT + CTA görür, grafik YOK', (t) async {
      await _pump(t, entitlement: free);
      expect(find.byKey(const Key('trend-premium-lock')), findsOneWidget);
      expect(find.byKey(const Key('trend-unlock-cta')), findsOneWidget);
      expect(find.byType(WeeklyTrendChart), findsNothing);
    });

    testWidgets('ÇEKİRDEK: kilit CTA GERÇEK aksiyon — paywall açılır (ölü kod değil)', (t) async {
      await _pump(t, entitlement: free);
      await t.tap(find.byKey(const Key('trend-unlock-cta')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('paywall-title')), findsOneWidget);
    });
  });

  group('paywall ekranı', () {
    testWidgets('başlık + faydalar + CTA render eder', (t) async {
      await _pump(t, entitlement: free, initial: '/paywall');
      expect(find.byKey(const Key('paywall-title')), findsOneWidget);
      expect(find.text('Weekly sleep trends'), findsOneWidget);
      expect(find.byKey(const Key('paywall-cta')), findsOneWidget);
    });

    testWidgets('ÇEKİRDEK: CTA gerçek satın alma YAPMAZ — "yakında" der (§6)', (t) async {
      await _pump(t, entitlement: free, initial: '/paywall');
      await t.tap(find.byKey(const Key('paywall-cta')));
      await t.pump(); // snackbar
      expect(find.text('Premium is coming soon.'), findsOneWidget);
    });

    testWidgets('"belki sonra" paywall\'ı kapatır (gerçek push→pop akışı)', (t) async {
      // Gerçek yol: kilitten push edilir, "belki sonra" geri döner (stack var).
      await _pump(t, entitlement: free);
      await t.tap(find.byKey(const Key('trend-unlock-cta')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('paywall-title')), findsOneWidget);
      await t.tap(find.byKey(const Key('paywall-later')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('paywall-title')), findsNothing);
      expect(find.byKey(const Key('trend-premium-lock')), findsOneWidget); // geçmişe döndük
    });
  });
}
