import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio_engine/signature_player.dart';
import '../core/design_system/nocta_theme.dart';
import '../core/launch/launch_moment.dart';
import '../features/analytics/analytics_flusher.dart';
import '../features/analytics/analytics_providers.dart';
import '../features/auth/auth_providers.dart';
import '../features/onboarding/onboarding_store.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/locale_store.dart';
import '../features/settings/signature_sound_store.dart';
import '../features/sleep/presentation/sleep_session_strip.dart';
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
class NoctaApp extends ConsumerStatefulWidget {
  const NoctaApp({super.key});

  @override
  ConsumerState<NoctaApp> createState() => _NoctaAppState();
}

class _NoctaAppState extends ConsumerState<NoctaApp> {
  /// Açılış aurası ARTIK BURADA tetikleniyor — `_AppRoot`/`_OnboardingApp`'ta
  /// değil.
  ///
  /// **Neden taşındı:** o iki kök ancak açılış anı BİTTİKTEN sonra ağaca giriyor
  /// (bkz. [LaunchMoment.ready]). Ses orada tetiklenseydi, ay çoktan doğup
  /// sönerken çalmaya başlardı — yani "görsel sesle senkron" fikri tam olarak
  /// çöpe giderdi. Bu State açılışın İLK karesinde kuruluyor ve uygulama boyunca
  /// yaşıyor; ses 3.6 sn boyunca kesintisiz çalabiliyor.
  final SignaturePlayer _signature = SignaturePlayer();

  @override
  void initState() {
    super.initState();
    // Üretim `compute()` ile ayrı isolate'te olduğu için UI donmaz.
    unawaited(_maybePlaySignature());
  }

  Future<void> _maybePlaySignature() async {
    try {
      final enabled = await ref.read(signatureSoundStoreProvider).isEnabled();
      if (!enabled || !mounted) return;
      await _signature.play();
    } catch (e, st) {
      // Açılış sesi uygulamanın açılmasını asla engellemez — ama sessizce de
      // yutulmaz (CLAUDE.md §4).
      debugPrint('nocta.aura: açılış sesi tetiklenemedi: $e\n$st');
    }
  }

  @override
  void dispose() {
    unawaited(_signature.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(sessionBootstrapProvider);
    final seenOnboarding = ref.watch(onboardingSeenProvider);
    // Dil tercihi: null -> sistem dili. Coz&uuml;lene dek splash beklemeye gerek yok;
    // null zaten dogru varsayilan.
    final locale = ref.watch(appLocaleProvider).maybeWhen(data: (l) => l, orElse: () => null);
    final theme = buildNoctaDarkTheme();

    // İLK AÇILIŞ KAPISI (Faz 0 cila): karşılama akışı görülmediyse önce o gösterilir.
    // Oturum bootstrap'i ARKA PLANDA paralel ilerler — kullanıcı okurken hazır olur.
    // Flag okunamazsa (hata) akış ATLANIR: onboarding uygulamayı asla kilitlememeli.
    final needsOnboarding = seenOnboarding.maybeWhen(
      data: (seen) => !seen,
      orElse: () => false,
    );

    // Açılış anı splash'ın ARKASINDAN kalkacak içeriği burada seçiyoruz.
    // `ready`, "bu içerik gösterilebilir mi" sorusunun cevabı.
    final Widget content;
    final bool ready;
    if (seenOnboarding.isLoading) {
      // Hangi kapıya gideceğimizi HENÜZ bilmiyoruz (yerel bayrak okuması, ~ms).
      //
      // **Dürüst köşe durumu:** bu okuma üst sınırı (2.2 sn) aşarsa kullanıcı ana
      // köke düşer ve ilk açılış karşılamasını O AÇILIŞTA görmez. Kabul edildi:
      // `markSeen()` çağrılmadığı için karşılama BİR SONRAKİ açılışta yine
      // gösterilir, yani akış kaybolmaz — sadece ertelenir. Alternatif (splash'ta
      // beklemek) uygulamayı kilitlerdi.
      content = _AppRoot(theme: theme, locale: locale, offline: true);
      ready = false;
    } else if (needsOnboarding) {
      content = _OnboardingApp(
        theme: theme,
        locale: locale,
        onDone: () async {
          await ref.read(onboardingStoreProvider).markSeen();
          ref.invalidate(onboardingSeenProvider);
        },
      );
      ready = true;
    } else {
      // Oturum HENÜZ çözülmediyse çevrimdışı kabuk hazır tutulur: üst sınır
      // dolduğunda kullanıcı sonsuz splash'ta kalmaz, çalışan bir uygulamaya
      // (yerel mikser + yeniden dene çubuğu) girer. Bootstrap sonradan
      // başarırsa bu widget `offline: false` ile yeniden kurulur.
      // Hata = ÇEVRİMDIŞI MOD, kilit değil (bkz. sınıf notu).
      content = _AppRoot(theme: theme, locale: locale, offline: !bootstrap.hasValue);
      ready = !bootstrap.isLoading;
    }

    return LaunchMoment(ready: ready, child: content);
  }
}

/// Oturum kurulduktan sonraki kök — router + analitik lifecycle flush observer'ı.
class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot({required this.theme, this.locale, this.offline = false});

  final ThemeData theme;

  /// Secili dil; null ise sistem dili.
  final Locale? locale;

  /// Oturum kurulamadı → çevrimdışı mod. Uygulama AÇILIR; API isteyen ekranlar
  /// kendi hatalarını gösterir, mikser gibi yerel olanlar çalışır.
  final bool offline;

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  late final AnalyticsFlusher _flusher;

  @override
  void initState() {
    super.initState();
    _flusher = AnalyticsFlusher(ref.read(analyticsProvider));
    WidgetsBinding.instance.addObserver(_flusher);
    // AÇILIŞ AURASI ARTIK BURADA DEĞİL: `NoctaApp` açılışın ilk karesinde
    // tetikliyor (bkz. `_NoctaAppState._signature`). Bu kök splash kalktıktan
    // SONRA kuruluyor; ses burada başlasaydı animasyonun gerisinde kalırdı.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_flusher);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NOCTA',
      debugShowCheckedModeBanner: false,
      theme: widget.theme,
      // Kullanıcının seçtiği dil; null ise cihaz dili (Flutter'ın kendi çözümü).
      locale: widget.locale,
      // i18n (CLAUDE.md §4). Kaynak dil EN; TR arb eklenince kod değişmez.
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      routerConfig: appRouter,
      // KABUK KATMANI: her ekranın ÜSTÜNDE duran bantlar burada yaşar. Ekran
      // başına eklemek yasak — yeni bir ekran geldiğinde unutulur ve kullanıcı
      // ekrandan ekrana geçerken bilgi kaybolur.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        // Süren gece: sayaç HER ekranda. Oturum yokken sıfır boyutludur — yani
        // çevrimdışı olmayan normal durumda düzen eskisiyle birebir aynı.
        Widget strip = SleepSessionStrip(router: appRouter);
        if (widget.offline) {
          // İki bant üst üste gelirse çentik boşluğunu ÜSTTEKİ tüketir. Şeridin
          // kendi `SafeArea`'sı ikinci kez uygulasaydı aralarında koca bir
          // boşluk kalırdı (kardeş widget'lar aynı MediaQuery'yi görür).
          strip = MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: strip,
          );
        }
        return Column(
          children: [
            // Çevrimdışıyken kullanıcı NEDEN bazı şeylerin boş olduğunu bilmeli —
            // sessizce boş ekran göstermek "uygulama bozuk" izlenimi verirdi.
            if (widget.offline) _offlineBanner(context),
            strip,
            Expanded(child: child),
          ],
        );
      },
    );
  }

  Widget _offlineBanner(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // `Wrap`, `Row` DEĞİL — §7. Row'da "Yeniden dene" düğmesi ESNEK DEĞİLDİ:
          // iç genişliğini alıyor, metne kalanı bırakıyordu. Büyük yazı ölçeğinde
          // düğme tek başına ekranı aşıyordu. ÖLÇÜLDÜ (320×568, TR, çevrimdışı,
          // ANA EKRAN — mikser hiç açılmadan): ölçek 1.3 → 903 px, ölçek 2.0 →
          // 1376 px taşma ve düğme yatayda 393 px > 320 px. Bant HER ekranda
          // olduğu için bu, mikserdeki düzeltmeyi de görünmez kılıyordu.
          // Wrap'te sığmayan düğme alt satıra iner; taşma yapısal olarak imkânsız.
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              // Simge + metin BİRLİKTE sarılır: metin uzunsa düğme alta iner,
              // ama simge metinden kopmaz.
              // Genişlik `LayoutBuilder`'dan, `MediaQuery`'den DEĞİL: MediaQuery
              // boyutu taşımayan bir bağlamda (testler, gömülü kullanım) 0 döner
              // ve `0 - 32` negatif bir kısıt üretip çöker. Gerçek kısıt her
              // zaman doğrudur ve negatif olamaz.
              LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          AppL10n.of(context).offlineBanner,
                          key: const Key('offline-banner'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                key: const Key('offline-retry'),
                onPressed: () => ref.invalidate(sessionBootstrapProvider),
                child: Text(AppL10n.of(context).offlineRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İlk açılış karşılaması için kök — router YOK (akış tek ekran, geri yığını gereksiz).
/// l10n delegeleri şart: onboarding metinleri arb'den gelir (CLAUDE.md §4).
class _OnboardingApp extends StatelessWidget {
  const _OnboardingApp({required this.theme, required this.onDone, this.locale});

  final ThemeData theme;
  final Locale? locale;
  final Future<void> Function() onDone;

  // AURA İLK AÇILIŞTA DA ÇALAR — ama tetikleyici artık `NoctaApp` (tek yer).
  // Önceden hem burası hem `_AppRoot` tetikliyordu ve çift çalmayı yalnızca
  // SignaturePlayer'ın süreç-düzeyi bayrağı engelliyordu; artık tek çağıran var.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOCTA',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: OnboardingScreen(onDone: onDone),
    );
  }
}
