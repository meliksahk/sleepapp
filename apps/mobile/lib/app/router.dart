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
import '../features/community/presentation/my_shares_screen.dart';
import '../features/settings/presentation/delete_account_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sleep/presentation/alarm_setup_screen.dart';
import '../features/sleep/presentation/mic_permission_screen.dart';
import '../features/sleep/presentation/night_report_screen.dart';
import '../features/sleep/presentation/ritual_screen.dart';
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
        builder: (context, ref, _) => SleepModeScreen(
          controller: ref.read(sleepModeControllerProvider),
          // Gerekçe BİR KEZ gösterilir; kararı alınır, bir daha araya girmez.
          // Reddedilmiş izinle geri gelindiğinde ekran "ne kaybettiğini"
          // söyleyen hâliyle açılır.
          micRationale: () async {
            final flag = ref.read(micRationaleFlagProvider);
            if (await flag.seen()) return true;
            if (!context.mounted) return false;
            final denied = ref
                .read(sleepModeControllerProvider)
                .state
                .permissionDenied;
            final allowed = await context.push<bool>(
              '/sleep-mode/microphone${denied ? '?denied=1' : ''}',
            );
            await flag.markSeen();
            return allowed ?? false;
          },
          onEditAlarm: () => context.push('/sleep-mode/alarm'),
        ),
      ),
    ),
    // Akıllı alarm kurulumu — sistemin saat diyaloğu YALNIZCA saat sorar,
    // oysa buradaki alarmın asıl ayarı pencere genişliği.
    GoRoute(
      path: '/sleep-mode/alarm',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) =>
            AlarmSetupScreen(controller: ref.read(sleepModeControllerProvider)),
      ),
    ),
    // Mikrofon izin gerekçesi — sistemin izin kutusundan ÖNCE. `?denied=1`
    // "daha önce reddettin" hâlini açar (kullanıcıya ne kaybettiğini söyler).
    GoRoute(
      path: '/sleep-mode/microphone',
      builder: (context, state) => MicPermissionScreen(
        denied: state.uri.queryParameters['denied'] == '1',
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
    // Ritüel/seri — alışkanlık döngüsünün kendi ekranı (F3).
    GoRoute(path: '/ritual', builder: (context, state) => const RitualScreen()),
    GoRoute(
      path: '/report/:night',
      builder: (context, state) =>
          NightReportScreen(nightDate: state.pathParameters['night'] ?? ''),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    // Bildirim ayarları — hatırlatıcı saati + sessiz saatler (F3).
    GoRoute(
      path: '/settings/notifications',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    // Hesap silme AYRI rota: ayarların içine gömülü bir diyalog değil, kendi
    // ekranı. Yıkıcı ve geri alınamaz bir eylem, geri düğmesi olan kendi
    // sayfasında yaşamalı (App Store zorunluluğu, CLAUDE.md §6).
    GoRoute(
      path: '/settings/delete-account',
      builder: (context, state) => const DeleteAccountScreen(),
    ),
    GoRoute(
      path: '/settings/community-shares',
      builder: (context, state) => const MySharesScreen(),
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
  ],
);
