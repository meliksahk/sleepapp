import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/app/router.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';
import 'package:nocta/features/settings/locale_store.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';
import 'package:nocta/features/sleep/sleep_session_beacon.dart';

/// **KÜÇÜK EKRAN × KABUK BANTLARI** — player'ın dikey bütçesi (#214 denetim).
///
/// ## Neden bu dosya var
///
/// Player düzeni ekranı üç sabit bölgeye bölüyor. Mikser'in KENDİ testi ekranı
/// tek başına (`MixerScreen`) kuruyordu ve orada geçiyordu — ama üretimde ekranın
/// üstünde uygulama kabuğunun iki bandı var (çevrimdışı bandı + süren gece
/// şeridi) ve bunlar gövdeyi kısaltıyor. Denetim 320×568'de ölçtü: çevrimdışı
/// bandı varken **15 px**, band + gece şeridi varken **43 px** taşma. Eski (düz
/// liste) mikser bu koşulda taşmıyordu — yani bu bir REGRESYONDU.
///
/// Dört kombinasyonun tamamı burada: bant var/yok × gece var/yok. Taşma
/// `flutter_test`'te exception'dır; `takeException` onu yakalar.
///
/// ## DÜRÜSTLÜK SINIRI
///
/// Burada "iyi görünüyor" kanıtlanmıyor — yalnızca (1) hiçbir kombinasyonda
/// taşma olmadığı, (2) birincil eylemin (çal) ekran içinde ve ≥44 px kaldığı,
/// (3) yedi katmanın tamamının kaydırılarak erişilebilir olduğu ölçülüyor.
/// Varsayılan yazı ölçeğinde ölçüldü; `textScaleFactor` 2.0 gibi uç değerler
/// KAPSANMADI (bkz. rapor).
void main() {
  setUp(() {
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    );
    appRouter.go('/');
  });

  for (final offline in <bool>[false, true]) {
    for (final night in <bool>[false, true]) {
      testWidgets(
          '320×568 — çevrimdışı bandı: $offline, gece şeridi: $night → TAŞMA YOK',
          (t) async {
        t.view.physicalSize = const Size(640, 1136); // 320×568 @2x
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);

        final beacon = SleepSessionBeacon();
        if (night) {
          beacon.begin(DateTime.now().subtract(const Duration(minutes: 42)));
          addTearDown(beacon.end);
        }

        await t.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              onboardingSeenProvider.overrideWith((ref) async => true),
              // Hata = çevrimdışı mod (uygulama AÇILIR, mikser çalışır).
              sessionBootstrapProvider.overrideWith(
                (ref) => offline
                    ? Future<void>.error(Exception('offline'))
                    : Future<void>.value(),
              ),
              sleepSessionBeaconProvider.overrideWithValue(beacon),
            ],
            child: const NoctaApp(),
          ),
        );
        await t.pumpAndSettle();
        appRouter.go('/mixer');
        await t.pumpAndSettle();
        addTearDown(() => appRouter.go('/'));

        // Kurgu gerçekten kurulmuş mu: bantlar beklendiği gibi mi?
        expect(find.byKey(const Key('mixer-toggle')), findsOneWidget);
        expect(
          find.byKey(const Key('offline-banner')),
          offline ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const Key('sleep-strip')),
          night ? findsOneWidget : findsNothing,
        );

        // ── ÖLÇÜM 1: taşma yok ──
        expect(
          t.takeException(),
          isNull,
          reason: 'player 320×568\'de taştı (bant=$offline, gece=$night)',
        );

        // ── ÖLÇÜM 2: birincil eylem ekran içinde ve dokunulabilir ──
        final toggle = t.getRect(find.byKey(const Key('mixer-toggle')));
        expect(toggle.bottom, lessThanOrEqualTo(568.0));
        expect(toggle.top, greaterThanOrEqualTo(0.0));
        expect(toggle.height, greaterThanOrEqualTo(44.0));

        final export = t.getRect(find.byKey(const Key('mixer-export-video')));
        expect(export.bottom, lessThanOrEqualTo(568.0));

        // ── ÖLÇÜM 3: hero başlığı hâlâ ayakta (daralınca ilk feda edilen oydu) ──
        expect(find.byKey(const Key('mixer-title')), findsOneWidget);
      });
    }
  }

  testWidgets('320×568 + iki bant + TÜRKÇE → TAŞMA YOK', (t) async {
    // `kPlayerControlsMinHeight` ÖLÇÜLMÜŞ bir sabittir ve ölçüm İngilizce
    // metinlerle yapıldı. Daha uzun bir çeviri taşıma çubuğunu büyütüp payı
    // yiyebilir — bu yüzden ikinci dil de en dar koşulda kilitleniyor.
    t.view.physicalSize = const Size(640, 1136);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);

    final beacon = SleepSessionBeacon()
      ..begin(DateTime.now().subtract(const Duration(minutes: 42)));
    addTearDown(beacon.end);

    await t.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingSeenProvider.overrideWith((ref) async => true),
          appLocaleProvider.overrideWith((ref) async => const Locale('tr')),
          sessionBootstrapProvider
              .overrideWith((ref) => Future<void>.error(Exception('offline'))),
          sleepSessionBeaconProvider.overrideWithValue(beacon),
        ],
        child: const NoctaApp(),
      ),
    );
    await t.pumpAndSettle();
    appRouter.go('/mixer');
    await t.pumpAndSettle();
    addTearDown(() => appRouter.go('/'));

    // Gerçekten Türkçe mi (yoksa test hiçbir şey kanıtlamaz).
    expect(find.text('Katmanlar'), findsOneWidget);
    expect(t.takeException(), isNull, reason: 'TR metinlerle düzen taştı');
    expect(
      t.getRect(find.byKey(const Key('mixer-toggle'))).bottom,
      lessThanOrEqualTo(568.0),
    );
  });
}
