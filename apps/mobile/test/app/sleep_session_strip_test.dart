import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/app/router.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';
import 'package:nocta/features/sleep/presentation/sleep_mode_screen.dart';
import 'package:nocta/features/sleep/presentation/sleep_session_strip.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';
import 'package:nocta/features/sleep/sleep_session_beacon.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// **Süren gece HER EKRANDA görünür** — kabuk şeridi sözleşmesi.
///
/// ## Neden bu test var
///
/// Sayaç yalnızca uyku modu ekranındaydı. Kullanıcı geceyi başlatıp mikser'e ya
/// da kütüphaneye geçtiğinde oturumun sürdüğünü GÖREMİYORDU — ve bir uyku
/// takibinde "çalışıyor mu?" sorusunun cevabı ancak sabah öğrenilirse çok geçtir.
///
/// Şerit uygulama KABUĞUNDA (çevrimdışı bandıyla aynı katman) yaşıyor. Bu testler
/// üç şeyi kilitliyor: (1) oturum yokken hiç yok, (2) oturum varken birden fazla
/// farklı rotada var, (3) uyku modu ekranında ÇİFT sayaç yok.
class _FakeSleep implements SleepController {
  @override
  Future<SleepSession> recordSession(SleepSessionDraft draft) async {
    return SleepSession(
      id: 's1',
      startedAt: draft.startedAt.toIso8601String(),
      endedAt: draft.endedAt.toIso8601String(),
      nightDate: '2026-07-17',
      durationMinutes: draft.duration.inMinutes,
      movementEvents: draft.movementEvents,
      soundEvents: draft.soundEvents,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUp(() {
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    );
    // `appRouter` GLOBAL: bir test /mixer'da bitirirse sonraki test orada başlar.
    appRouter.go('/');
  });

  Float32List frame(double a, {int n = 256}) {
    final f = Float32List(n);
    for (var i = 0; i < n; i++) {
      f[i] = i.isEven ? a : -a;
    }
    return f;
  }

  /// Uyku modu ekranını test edilebilir kılan controller: gerçek mikrofon,
  /// foreground servis ve güvenli depo yerine sahteler. (Üretim provider'ı bu
  /// testte kurulsaydı platform kanalları olmayan ortamda anlamsız olurdu.)
  SleepModeController fakeController(SleepSessionBeacon beacon) {
    return SleepModeController(
      recorder: SleepRecorder(
        mic: FakeMicSource(List.generate(40, (_) => frame(0.0001))),
        now: () => DateTime.utc(2026, 7, 17, 23),
      ),
      sleep: _FakeSleep(),
      nightService: FakeNightService(),
      beacon: beacon,
    );
  }

  Widget appWith(SleepSessionBeacon beacon) {
    return ProviderScope(
      overrides: [
        onboardingSeenProvider.overrideWith((ref) async => true),
        sessionBootstrapProvider.overrideWith((ref) => Future<void>.value()),
        sleepSessionBeaconProvider.overrideWithValue(beacon),
        sleepModeControllerProvider.overrideWithValue(fakeController(beacon)),
      ],
      child: const NoctaApp(),
    );
  }

  testWidgets('oturum YOKKEN şerit hiçbir ekranda görünmez', (t) async {
    await t.pumpWidget(appWith(SleepSessionBeacon()));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sleep-strip')), findsNothing);

    // Başka bir rotada da yok — şerit "her zaman görünen" bir süs değil.
    appRouter.go('/mixer');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sleep-strip')), findsNothing);
  });

  testWidgets('ÇEKİRDEK: oturum varken şerit ANA EKRANDA görünür ve süreyi yazar',
      (t) async {
    final beacon = SleepSessionBeacon()
      ..begin(DateTime.now().subtract(const Duration(hours: 1, minutes: 30)));

    await t.pumpWidget(appWith(beacon));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sleep-strip')), findsOneWidget);
    expect(find.byKey(const Key('sleep-strip-status')), findsOneWidget);
    // Geçen süre doğru: 1sa 30dk önce başlamış bir gece. Saniye alanı gevşek
    // bırakıldı — bu testte saat GERÇEK ve pump'lar birkaç yüz ms sürebiliyor.
    final text = t
        .widget<Text>(find.byKey(const Key('sleep-strip-elapsed')))
        .data;
    expect(
      text,
      matches(RegExp(r'^01:30:0\d$')),
      reason: 'şerit geçen süreyi sa:dk:sn yazmalı, bulunan: $text',
    );
  });

  testWidgets('ÇEKİRDEK: oturum varken şerit MİKSER ve KÜTÜPHANE ekranlarında da var',
      (t) async {
    final beacon = SleepSessionBeacon()..begin(DateTime.now());

    await t.pumpWidget(appWith(beacon));
    await t.pumpAndSettle();

    // Kullanıcının gece ritüelinde gerçekten gittiği iki yer.
    appRouter.go('/mixer');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('mixer-toggle')), findsOneWidget,
        reason: 'gerçekten mikser ekranındayız');
    expect(find.byKey(const Key('sleep-strip')), findsOneWidget);

    appRouter.go('/library');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sleep-strip')), findsOneWidget);
  });

  testWidgets('ÇEKİRDEK: şeride dokununca uyku modu ekranı açılır', (t) async {
    final beacon = SleepSessionBeacon()..begin(DateTime.now());

    await t.pumpWidget(appWith(beacon));
    await t.pumpAndSettle();

    appRouter.go('/mixer');
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('sleep-strip')));
    await t.pumpAndSettle();

    expect(find.byType(SleepModeScreen), findsOneWidget);
  });

  testWidgets('ÇEKİRDEK: uyku modu ekranında ÇİFT sayaç YOK (şerit gizlenir)',
      (t) async {
    final beacon = SleepSessionBeacon()..begin(DateTime.now());

    await t.pumpWidget(appWith(beacon));
    await t.pumpAndSettle();

    appRouter.go(sleepModeRoutePath);
    await t.pumpAndSettle();

    expect(find.byType(SleepModeScreen), findsOneWidget);
    // Ekranda zaten büyük sayaç var; şerit ikinci bir sayaç göstermemeli.
    expect(find.byKey(const Key('sleep-strip')), findsNothing);
    expect(find.byKey(const Key('sleep-strip-elapsed')), findsNothing);
  });

  testWidgets('şeritten PUSH ile gelindiğinde de çift sayaç yok', (t) async {
    // `push` rotayı `RouteMatchList.uri`'ye yansıtmaz; rota tespiti bunu
    // kaçırsaydı kullanıcı şeride basınca iki sayaç birden görürdü.
    final beacon = SleepSessionBeacon()..begin(DateTime.now());

    await t.pumpWidget(appWith(beacon));
    await t.pumpAndSettle();

    appRouter.go('/library');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('sleep-strip')));
    await t.pumpAndSettle();

    expect(find.byType(SleepModeScreen), findsOneWidget);
    expect(find.byKey(const Key('sleep-strip')), findsNothing);
  });

  testWidgets('gece BİTİNCE şerit kaybolur (asılı kalmaz)', (t) async {
    final beacon = SleepSessionBeacon()..begin(DateTime.now());

    await t.pumpWidget(appWith(beacon));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sleep-strip')), findsOneWidget);

    beacon.end();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sleep-strip')), findsNothing);
  });

  testWidgets(
      'ÇEKİRDEK: sayaç saniyede ilerler ama KOMŞU AĞACI yeniden çizdirmez',
      (t) async {
    // Saat ENJEKTE: widget testinde `pump(1sn)` zamanlayıcıyı tetikler ama
    // `DateTime.now()` yerinde sayar — saati biz sürmezsek sayacın gerçekten
    // ilerlediğini kanıtlayamayız.
    var fakeNow = DateTime(2026, 7, 17, 23);
    final beacon = SleepSessionBeacon()..begin(fakeNow);

    // Şeridin YANINDAKİ ağaç: ekran ağacını temsil eder. Saniyelik tazeleme
    // buraya sızarsa gece boyu her saniye tüm ekran yeniden çizilir = pil.
    var siblingBuilds = 0;

    late final GoRouter router;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                SleepSessionStrip(router: router, now: () => fakeNow),
                Builder(
                  builder: (_) {
                    siblingBuilds++;
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );

    await t.pumpWidget(
      ProviderScope(
        overrides: [sleepSessionBeaconProvider.overrideWithValue(beacon)],
        child: MaterialApp.router(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('00:00:00'), findsOneWidget);
    final buildsAfterMount = siblingBuilds;

    fakeNow = fakeNow.add(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('00:00:01'), findsOneWidget,
        reason: 'sayaç canlı olmalı, donmuş değil');

    fakeNow = fakeNow.add(const Duration(minutes: 5));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('00:05:01'), findsOneWidget);

    // İki tazeleme geçti; komşu ağaç HİÇ yeniden çizilmedi.
    expect(
      siblingBuilds,
      buildsAfterMount,
      reason: 'saniyelik tazeleme yalnızca sayaç Text\'ini kapsamalı',
    );

    beacon.end();
    await t.pumpAndSettle();
  });

  testWidgets('şeridin dokunma hedefi ≥44px (CLAUDE.md §7)', (t) async {
    final beacon = SleepSessionBeacon()..begin(DateTime.now());

    await t.pumpWidget(appWith(beacon));
    await t.pumpAndSettle();

    final size = t.getSize(find.byKey(const Key('sleep-strip')));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('ÇEVRİMDIŞI bandı ile şerit BİRLİKTE yaşar (biri diğerini yemez)',
      (t) async {
    final beacon = SleepSessionBeacon()..begin(DateTime.now());

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingSeenProvider.overrideWith((ref) async => true),
          sessionBootstrapProvider.overrideWith(
            (ref) => Future<void>.error(Exception('ağ yok')),
          ),
          sleepSessionBeaconProvider.overrideWithValue(beacon),
          sleepModeControllerProvider.overrideWithValue(fakeController(beacon)),
        ],
        child: const NoctaApp(),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.byKey(const Key('sleep-strip')), findsOneWidget);

    beacon.end();
    await t.pumpAndSettle();
  });

  testWidgets('çentik boşluğu İKİ KEZ uygulanmaz (bantlar üst üsteyken)',
      (t) async {
    // Kardeş widget'lar aynı MediaQuery'yi görür: iki `SafeArea` üst üste
    // gelirse çentik payı iki kez eklenir ve bantların arasında koca bir boşluk
    // kalır. Testte varsayılan çentik SIFIR olduğu için bunu ancak gerçek bir
    // üst pay vererek yakalayabiliriz.
    t.view.padding = const FakeViewPadding(top: 120); // 120 fiziksel / dpr 3 = 40
    addTearDown(t.view.reset);

    final beacon = SleepSessionBeacon()..begin(DateTime.now());
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingSeenProvider.overrideWith((ref) async => true),
          sessionBootstrapProvider.overrideWith(
            (ref) => Future<void>.error(Exception('ağ yok')),
          ),
          sleepSessionBeaconProvider.overrideWithValue(beacon),
          sleepModeControllerProvider.overrideWithValue(fakeController(beacon)),
        ],
        child: const NoctaApp(),
      ),
    );
    await t.pumpAndSettle();

    final bannerBottom =
        t.getRect(find.byKey(const Key('offline-banner'))).bottom;
    final stripTop = t.getRect(find.byKey(const Key('sleep-strip'))).top;

    // Aradaki tek boşluk bandın alt iç boşluğu (8px). 40px'lik çentik payı
    // ikinci kez uygulansaydı bu fark 40'ı aşardı.
    expect(
      stripTop - bannerBottom,
      lessThan(40),
      reason: 'çentik payı ikinci kez uygulanmış görünüyor',
    );

    beacon.end();
    await t.pumpAndSettle();
  });
}
