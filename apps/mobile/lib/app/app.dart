import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio_engine/signature_player.dart';
import '../core/design_system/nocta_theme.dart';
import '../features/analytics/analytics_flusher.dart';
import '../features/analytics/analytics_providers.dart';
import '../features/auth/auth_providers.dart';
import '../features/onboarding/onboarding_store.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/signature_sound_store.dart';
import 'router.dart';

/// Kök uygulama widget'ı — dark-first (uygulama gece yaşar, docs/06).
///
/// Açılışta anonim oturumu kurmayı dener; çözülene dek splash.
///
/// **OTURUM HATASI UYGULAMAYI BLOKLAMAZ (CLAUDE.md §3.1).** Kural açık:
/// *"Uygulama offline-first: ses üretimi ve mikser internetsiz TAM çalışır."*
/// Önceden hata durumunda tüm uygulama bir "yeniden dene" ekranına düşüyordu —
/// yani internet yoksa **tamamen yerel olan mikser'e bile ulaşılamıyordu.** Bu,
/// uçakta/kırsalda/sunucu çökünce uygulamanın çekirdek işlevini yok ederdi.
///
/// Artık hata durumunda da router açılır: API isteyen ekranlar kendi hatalarını
/// gösterir, internetsiz çalışabilenler (mikser) çalışır.
class NoctaApp extends ConsumerWidget {
  const NoctaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(sessionBootstrapProvider);
    final seenOnboarding = ref.watch(onboardingSeenProvider);
    final theme = buildNoctaDarkTheme();

    // İLK AÇILIŞ KAPISI (Faz 0 cila): karşılama akışı görülmediyse önce o gösterilir.
    // Oturum bootstrap'i ARKA PLANDA paralel ilerler — kullanıcı okurken hazır olur.
    // Flag okunamazsa (hata) akış ATLANIR: onboarding uygulamayı asla kilitlememeli.
    if (seenOnboarding.isLoading) {
      return _SplashApp(theme: theme);
    }
    final needsOnboarding = seenOnboarding.maybeWhen(
      data: (seen) => !seen,
      orElse: () => false,
    );
    if (needsOnboarding) {
      return _OnboardingApp(
        theme: theme,
        onDone: () async {
          await ref.read(onboardingStoreProvider).markSeen();
          ref.invalidate(onboardingSeenProvider);
        },
      );
    }

    return bootstrap.when(
      data: (_) => _AppRoot(theme: theme),
      // Yükleme KISA ve belirleyici: oturum ya kurulur ya hata verir. Splash burada
      // kalır çünkü henüz hangi durumda olduğumuzu bilmiyoruz.
      loading: () => _SplashApp(theme: theme),
      // Hata = ÇEVRİMDIŞI MOD, kilit değil.
      error: (error, stack) => _AppRoot(theme: theme, offline: true),
    );
  }
}

/// Oturum kurulduktan sonraki kök — router + analitik lifecycle flush observer'ı.
class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot({required this.theme, this.offline = false});

  final ThemeData theme;

  /// Oturum kurulamadı → çevrimdışı mod. Uygulama AÇILIR; API isteyen ekranlar
  /// kendi hatalarını gösterir, mikser gibi yerel olanlar çalışır.
  final bool offline;

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  late final AnalyticsFlusher _flusher;
  final SignaturePlayer _signature = SignaturePlayer();

  @override
  void initState() {
    super.initState();
    _flusher = AnalyticsFlusher(ref.read(analyticsProvider));
    WidgetsBinding.instance.addObserver(_flusher);
    // AÇILIŞ AURASI — yalnızca COLD START'ta (bu State bir kez kurulur) ve ayar
    // açıkken. Üretim `compute()` ile ayrı isolate'te olduğu için UI donmaz.
    unawaited(_maybePlaySignature());
  }

  Future<void> _maybePlaySignature() async {
    try {
      final enabled = await ref.read(signatureSoundStoreProvider).isEnabled();
      if (!enabled || !mounted) return;
      await _signature.play();
    } catch (_) {
      // Açılış sesi uygulamanın açılmasını asla engellemez.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_flusher);
    unawaited(_signature.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NOCTA',
      debugShowCheckedModeBanner: false,
      theme: widget.theme,
      // i18n (CLAUDE.md §4). Kaynak dil EN; TR arb eklenince kod değişmez.
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) {
        if (!widget.offline || child == null) {
          return child ?? const SizedBox.shrink();
        }
        // Çevrimdışıyken kullanıcı NEDEN bazı şeylerin boş olduğunu bilmeli —
        // sessizce boş ekran göstermek "uygulama bozuk" izlenimi verirdi.
        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppL10n.of(context).offlineBanner,
                          key: const Key('offline-banner'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        key: const Key('offline-retry'),
                        onPressed: () =>
                            ref.invalidate(sessionBootstrapProvider),
                        child: Text(AppL10n.of(context).offlineRetry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// İlk açılış karşılaması için kök — router YOK (akış tek ekran, geri yığını gereksiz).
/// l10n delegeleri şart: onboarding metinleri arb'den gelir (CLAUDE.md §4).
class _OnboardingApp extends StatelessWidget {
  const _OnboardingApp({required this.theme, required this.onDone});

  final ThemeData theme;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOCTA',
      debugShowCheckedModeBanner: false,
      theme: theme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: OnboardingScreen(onDone: onDone),
    );
  }
}

/// Metinsiz açılış ekranı: yalnızca oturum ÇÖZÜLENE KADAR görünür.
///
/// Artık "yeniden dene" yolu YOK — hata durumunda uygulama bu ekranda kalmıyor,
/// çevrimdışı moda geçip router'ı açıyor (bkz. [NoctaApp]). Yeniden deneme,
/// çevrimdışı çubuğundaki butonda.
class _SplashApp extends StatelessWidget {
  const _SplashApp({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOCTA',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
