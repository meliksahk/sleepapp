import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/archetype/presentation/archetype_detail_screen.dart';
import '../features/archetype/presentation/archetype_history_screen.dart';
import '../features/archetype/presentation/archetype_test_screen.dart';
import '../features/content/presentation/soundscape_detail_screen.dart';
import '../features/content/presentation/soundscape_library_screen.dart';
import '../features/entitlement/presentation/paywall_screen.dart';
import '../features/home/home_screen.dart';
import '../features/mixer/presentation/mixer_route.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sleep/presentation/night_report_screen.dart';
import '../features/sleep/presentation/sleep_mode_screen.dart';
import '../features/sleep/presentation/sleep_history_screen.dart';
import '../features/sleep/sleep_providers.dart';

/// Uyku modu rotası — kabuk şeridi (bkz. `SleepSessionStrip`) hem oraya gitmek
/// hem de "zaten oradayım, çift sayaç gösterme" kararı için bunu okur. Sabit
/// olmasa iki yerde elle yazılırdı ve biri değişince sessizce bozulurdu.
const String sleepModeRoutePath = '/sleep-mode';

/// Uygulama route'ları — tek dosyada tip güvenli (docs/04). M1'de büyür.
final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/archetype',
      builder: (context, state) => const ArchetypeTestScreen(),
    ),
    GoRoute(
      path: '/identity/history',
      builder: (context, state) => const ArchetypeHistoryScreen(),
    ),
    GoRoute(
      path: '/identity/:slug',
      builder: (context, state) =>
          ArchetypeDetailScreen(slug: state.pathParameters['slug'] ?? ''),
    ),
    GoRoute(
      path: sleepModeRoutePath,
      builder: (context, state) => Consumer(
        builder: (context, ref, _) =>
            SleepModeScreen(controller: ref.read(sleepModeControllerProvider)),
      ),
    ),
    // `?soundscape=<slug>` → mikser O sesin tarifiyle açılır. Parametre yoksa
    // varsayılan mix. Slug çözülemezse yine varsayılan — hata ekranı YOK.
    GoRoute(
      path: '/mixer',
      builder: (context, state) =>
          MixerRoute(soundscapeSlug: state.uri.queryParameters['soundscape']),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => const SoundscapeLibraryScreen(),
    ),
    GoRoute(
      path: '/library/:slug',
      builder: (context, state) =>
          SoundscapeDetailScreen(slug: state.pathParameters['slug'] ?? ''),
    ),
    GoRoute(
      path: '/sleep',
      builder: (context, state) => const SleepHistoryScreen(),
    ),
    GoRoute(
      path: '/report/:night',
      builder: (context, state) =>
          NightReportScreen(nightDate: state.pathParameters['night'] ?? ''),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
  ],
);
