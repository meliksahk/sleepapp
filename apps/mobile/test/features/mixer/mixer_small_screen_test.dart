import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/app/router.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';
import 'package:nocta/features/mixer/presentation/mixer_screen.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';
import 'package:nocta/features/settings/locale_store.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';
import 'package:nocta/features/sleep/sleep_session_beacon.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Cihazsız oynatıcı — düzen testi ses donanımına dokunmamalı.
class _FakePlayer implements AudioPlayer {
  @override
  bool playing = false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async => Duration.zero;

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setLoopMode(LoopMode mode) async {}
  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Player'ı 320×568'de, verilen yazı ölçeği/dil/kabuk bandı yüksekliğiyle kurar.
///
/// **Kabuk bandı neden SİMÜLE ediliyor:** gerçek kabuk (`NoctaApp`) bantları
/// büyük yazı ölçeğinde kendisi taşırıyor (bkz. dosya başlığındaki not) — o ayrı
/// bir kusur ve ayrı bir dosyada yaşıyor. Bu matris MİKSERİ ölçüyor, bu yüzden
/// bandın gövdeye yaptığı TEK ŞEY (yüksekliği kısaltmak) doğrudan modelleniyor.
/// Böylece mikserin bütçesi, kabuğun kusurundan bağımsız olarak kilitlenir.
Future<void> _pumpPlayer(
  WidgetTester t, {
  required double scale,
  required String lang,
  required double band,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        latestArchetypeResultProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Column(
            children: <Widget>[
              SizedBox(height: band),
              Expanded(child: child!),
            ],
          ),
        ),
        home: MixerScreen(
          canExportVideo: true,
          controller: MixerController(
            spec: defaultMixSpec(),
            player: MixPlayer(
              loopRenderer: (r) async => renderLoopSync(r),
              loopSeconds: 1,
              sampleRate: 8000,
              playerFactory: _FakePlayer.new,
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

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
///
/// Yazı ölçeği artık KAPSANIYOR — dosyanın sonundaki §7 matrisi. Bu üstteki
/// blok hâlâ yalnızca varsayılan ölçeği kullanıyor çünkü GERÇEK kabuğu (bantlar
/// dahil) kuruyor; kabuğun çevrimdışı bandı büyük yazı ölçeğinde kendisi
/// taşıyor (TR 1.3'te banner 903 px, 2.0'da 1376 px — `lib/app/app.dart`,
/// mikserden bağımsız, ayrı iş olarak açıldı). O düzelene dek kabuklu testler
/// büyük ölçekte mikseri değil kabuğu ölçerdi; §7 matrisi bu yüzden bandı
/// simüle ediyor.
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
        },
      );
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
          sessionBootstrapProvider.overrideWith(
            (ref) => Future<void>.error(Exception('offline')),
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

    // Gerçekten Türkçe mi (yoksa test hiçbir şey kanıtlamaz).
    expect(find.text('Katmanlar'), findsOneWidget);
    expect(t.takeException(), isNull, reason: 'TR metinlerle düzen taştı');
    expect(
      t.getRect(find.byKey(const Key('mixer-toggle'))).bottom,
      lessThanOrEqualTo(568.0),
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // YAZI ÖLÇEĞİ MATRİSİ — CLAUDE.md §7
  // ─────────────────────────────────────────────────────────────────────────
  //
  // Yukarıdaki testler yalnızca VARSAYILAN yazı ölçeğini kapsıyordu ve bunu
  // kendi yorumlarında da söylüyordu. Denetim o boşluğu ölçtü: eski düzende
  // `kPlayerControlsMinHeight = 280` sabiti, ölçüldüğü koşulun dışında
  // geçersizdi. 320×568 + iki kabuk bandı + EN'de ölçülen taşma:
  //
  //   1.0 → yok · 1.3 → 9 px · 1.6 → 148 px · 2.0 → çal butonu ekran DIŞINDA
  //
  // Sabit kaldırıldı; kontrol bölgesindeki her şey yer daralınca kaydırılabilir
  // hâle geldi ve rezervasyon tek bir teslim edilemeyen parçaya (çal butonu)
  // indi. Bu matris o düzeltmeyi kilitler: 4 yazı ölçeği × 2 dil × bant var/yok.
  //
  // ## Ne KANITLANMIYOR
  //
  // Düzenin büyük yazı ölçeğinde "kullanışlı" olduğu değil, YIKILMADIĞI ve
  // birincil eylemin ulaşılabilir kaldığı. 2.0'da katman listesi ve video
  // butonu kaydırma gerektirir — bu bilinçli bir taviz (bkz. `_transport`).
  for (final scale in <double>[1.0, 1.3, 1.6, 2.0]) {
    for (final lang in <String>['en', 'tr']) {
      // 0 = bant yok. 124 = çevrimdışı bandı + gece şeridi, varsayılan
      // ölçekte GERÇEK kabuktan ölçülmüş yükseklik (probe: şerit 80→124).
      for (final band in <double>[0, 124]) {
        testWidgets(
          '§7 · 320×568 · ölçek $scale · $lang · bant $band → taşma YOK, '
          'çal ekranda',
          (t) async {
            t.view.physicalSize = const Size(640, 1136); // 320×568 @2x
            t.view.devicePixelRatio = 2;
            addTearDown(t.view.reset);

            await _pumpPlayer(t, scale: scale, lang: lang, band: band);

            // ── ÖLÇÜM 1: hiçbir yönde taşma yok (RenderFlex taşması = exception)
            expect(
              t.takeException(),
              isNull,
              reason: 'ölçek $scale · $lang · bant $band → düzen taştı',
            );

            // ── ÖLÇÜM 2: birincil eylem EKRAN İÇİNDE ve §7 dokunma hedefinde
            final toggle = t.getRect(find.byKey(const Key('mixer-toggle')));
            expect(
              toggle.top,
              greaterThanOrEqualTo(0.0),
              reason: 'çal butonu ekranın üstüne taşmış',
            );
            expect(
              toggle.bottom,
              lessThanOrEqualTo(568.0),
              reason: 'çal butonu ekranın altına taşmış',
            );
            expect(
              toggle.height,
              greaterThanOrEqualTo(44.0),
              reason: 'çal butonu §7 dokunma hedefinin altına inmiş',
            );

            // ── ÖLÇÜM 3: buton KIRPILMAMIŞ — taşıma çubuğu dar alanda kendi
            // içinde kaydırılıyor; çal butonu o görüntü alanının İÇİNDE kalmalı,
            // yoksa "ekranda ama görünmüyor" olurdu.
            final sheet = t.getRect(find.byKey(const Key('mixer-sheet')));
            expect(toggle.top, greaterThanOrEqualTo(sheet.top - 0.5));
            expect(toggle.bottom, lessThanOrEqualTo(sheet.bottom + 0.5));

            // ── ÖLÇÜM 4: metin KIRPILMADI — hero başlığı ve katmanların hepsi
            // hâlâ ağaçta (çözüm "metni sil" değil "kaydırılabilir yap" idi).
            expect(find.byKey(const Key('mixer-title')), findsOneWidget);
            for (final layer in defaultMixSpec().layers) {
              expect(
                find.byKey(Key('gain-${layer.id}')),
                findsOneWidget,
                reason: '${layer.id} sürgüsü düzenden düşmüş',
              );
            }
          },
        );
      }
    }
  }
}
