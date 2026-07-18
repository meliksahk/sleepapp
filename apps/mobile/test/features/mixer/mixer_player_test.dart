import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/app/app.dart';
import 'package:nocta/app/flavor.dart';
import 'package:nocta/app/router.dart';
import 'package:nocta/core/ambient/ambient.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/archetype/archetype_models.dart';
import 'package:nocta/features/archetype/archetype_providers.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';
import 'package:nocta/features/mixer/presentation/mixer_screen.dart';
import 'package:nocta/features/onboarding/onboarding_store.dart';
import 'package:nocta/features/auth/auth_providers.dart';
import 'package:nocta/features/sleep/sleep_providers.dart';
import 'package:nocta/features/sleep/sleep_session_beacon.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Mikser **PLAYER** sözleşmesi (#214).
///
/// Ekran düz bir sürgü listesiydi; artık arkasında ambiyans animasyonu, üstünde
/// sabit taşıma kontrolleri olan bir player. Bu dosya, o dönüşümün ölçülebilir
/// kısımlarını kilitliyor.
///
/// ## DÜRÜSTLÜK SINIRI — burada NE KANITLANMIYOR
///
/// Ekranın "güzel göründüğü" kanıtlanmıyor; hiçbir piksel görülmedi, golden yok.
/// Kanıtlanan şeyler ölçülebilir olanlar: arka planın ağaçta OLMASI, mikser
/// kazançlarını ve kimlik gradyanını ALMASI, duraklatılmışken kare üretilMEMESİ,
/// kontrollerin 7 katmanla bile ekran içinde kalması, scrim'in var olması ve
/// dokunma hedeflerinin ≥44px olması.
///
/// **Kontrast oranı ÖLÇÜLMEDİ.** Scrim'in VARLIĞI ve alfası test ediliyor; o
/// alfanın gerçek bir cihazda, karanlık odada, hareketli gradyanın en açık
/// anında AA kontrastı verdiği ölçülmedi.
class _FakePlayer implements AudioPlayer {
  @override
  bool playing = false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async =>
      Duration.zero;

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

/// Cihazsız controller: gerçek DSP koşar, yalnızca hoparlör sahtedir.
MixerController _controller(MixSpec spec) => MixerController(
      spec: spec,
      player: MixPlayer(
        loopRenderer: (r) async => renderLoopSync(r),
        loopSeconds: 1,
        sampleRate: 8000,
        playerFactory: _FakePlayer.new,
      ),
    );

Future<void> _pump(
  WidgetTester t, {
  MixSpec? spec,
  ArchetypeResult? archetype,
  String? title,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        latestArchetypeResultProvider.overrideWith((ref) async => archetype),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: MixerScreen(
          controller: _controller(spec ?? defaultMixSpec()),
          canExportVideo: true,
          title: title,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

AmbientPainter _painter(WidgetTester t) => t
    .widget<CustomPaint>(find.byKey(const Key('ambient-backdrop')))
    .painter! as AmbientPainter;

void main() {
  testWidgets('ÇEKİRDEK: ekranın ARKASINDA ambiyans animasyonu var', (t) async {
    await _pump(t);

    // Player'ın tanımı bu: kontroller bir arka planın ÜSTÜNDE duruyor.
    expect(find.byKey(const Key('ambient-backdrop')), findsOneWidget);
    expect(find.byType(AmbientBackdrop), findsOneWidget);

    // Arka plan gerçekten ARKADA: kontrol sayfası onun içinde (üstünde) yaşıyor.
    expect(
      find.descendant(
        of: find.byType(AmbientBackdrop),
        matching: find.byKey(const Key('mixer-sheet')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ÇEKİRDEK: arka plan MİKSERİN kazançlarıyla sürülür', (t) async {
    // Görsel karakter sürgülerden gelmezse arka plan yalnızca bir duvar kağıdı
    // olurdu; "çalanı gösteren" bir player olmazdı.
    const wavy = MixSpec([
      MixLayer(id: 'waves', type: LayerSource.waves, gain: 0.8),
      MixLayer(id: 'rain', type: LayerSource.rain, gain: 0.05),
    ]);
    await _pump(t, spec: wavy);
    final before = _painter(t).drive;

    // Dalgayı dibe çek → sürüş DEĞİŞMELİ.
    await t.drag(find.byKey(const Key('gain-waves')), const Offset(-500, 0));
    await t.pumpAndSettle();

    expect(
      _painter(t).drive,
      isNot(before),
      reason: 'sürgü oynadı ama arka planın sürüşü aynı kaldı',
    );
  });

  testWidgets('arketip YOKKEN arka plan nötr varsayılana düşer (ekran boş kalmaz)',
      (t) async {
    await _pump(t);
    expect(_painter(t).gradient, NoctaArchetypeGradient.overthinker);
  });

  // AYRI test, aynı testte ikinci `pumpWidget` DEĞİL: override değişince
  // FutureProvider yeniden çözülürken bir kare `AsyncLoading` oluyor ve ekran
  // (doğru davranışla) eski/nötr gradyanda kalıyor. Taze ağaç, net ölçüm.
  testWidgets('arka plan KULLANICININ arketip gradyanını taşır', (t) async {
    await _pump(
      t,
      archetype: const ArchetypeResult(
        userId: 'u1',
        archetypeSlug: 'deep-ocean',
        scores: {},
        version: 1,
        createdAt: '2026-07-18T00:00:00Z',
      ),
    );
    expect(
      _painter(t).gradient,
      NoctaArchetypeGradient.deepOcean,
      reason: 'player arka planı kimliği taşımalı (#178 tek kaynak)',
    );
  });

  testWidgets(
      'ÇEKİRDEK: DURAKLATILMIŞKEN kare üretilmez, ÇALINCA üretilir (pil + dürüstlük)',
      (t) async {
    await _pump(t);

    // Duraklatılmış: `pumpAndSettle` zaten döndü — yani ağaçta sürekli kare
    // isteyen hiçbir şey yok. Ölçüm bu: planlanmış kare SIFIR.
    expect(
      t.binding.hasScheduledFrame,
      isFalse,
      reason: 'ses yokken arka plan hâlâ kare üretiyor (pil + olmayan sesi '
          'varmış gibi gösterme)',
    );

    // Çal → hareket başlar.
    await t.tap(find.byKey(const Key('mixer-toggle')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(
      t.binding.hasScheduledFrame,
      isTrue,
      reason: 'ses çalarken arka plan donuk kalmamalı',
    );

    // Duraklat → hareket yeniden durur.
    await t.tap(find.byKey(const Key('mixer-toggle')));
    await t.pumpAndSettle();
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
      'ÇEKİRDEK: 7 katmanla bile taşıma kontrolleri EKRAN İÇİNDE (kaydırma gerekmez)',
      (t) async {
    // #213'te çal butonu listenin sonundaydı ve 7 katmanda ekranın altına
    // düşmüştü. Player düzeninde kontroller sabit; bu ölçüm o düzeni kilitler.
    await _pump(t);
    expect(defaultMixSpec().layers, hasLength(7));

    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    for (final key in <String>['mixer-toggle', 'mixer-export-video']) {
      final rect = t.getRect(find.byKey(Key(key)));
      expect(rect.bottom, lessThanOrEqualTo(screen.height),
          reason: '$key ekranın altına taşmış');
      expect(rect.top, greaterThanOrEqualTo(0));
    }

    // Katmanlar ise KAYDIRILIR — ve hepsi ağaçta (tembel liste değil).
    expect(find.byKey(const Key('mixer-layers-scroll')), findsOneWidget);
    for (final layer in defaultMixSpec().layers) {
      expect(find.byKey(Key('gain-${layer.id}')), findsOneWidget,
          reason: '${layer.id} sürgüsü ağaçta yok');
    }
  });

  testWidgets(
      'ÇEKİRDEK: YEDİ katmanın hepsi GÖRÜLEBİLİR (kaydırarak) — biri değil',
      (t) async {
    // Emülatörde yalnızca "brown" görünüyordu: hero sabit `flex: 3` payını
    // korurken kaydırılan alana 411×869'da 223 px, 390×844'te 207 px, 320×568'de
    // 35 px kalıyordu. "Ağaçta var" yeterli değil — kullanıcı GÖREBİLMELİ.
    // Bu test ağaçta olmayı değil, viewport'a girmeyi ölçer.
    t.view.physicalSize = const Size(780, 1688); // 390×844 @2x
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);

    await _pump(t);
    final scroll = find.byKey(const Key('mixer-layers-scroll'));

    Set<String> visibleNow() {
      final vp = t.getRect(scroll);
      return <String>{
        for (final l in defaultMixSpec().layers)
          if (() {
            final r = t.getRect(find.byKey(Key('gain-${l.id}')));
            return r.top >= vp.top - 0.5 && r.bottom <= vp.bottom + 0.5;
          }())
            l.id,
      };
    }

    // (1) KAYDIRMADAN kaç tane görünüyor? Tek katman kabul edilemez.
    final atRest = visibleNow();
    debugPrint('ÖLÇÜM 390×844: kaydırmadan görünen katman = ${atRest.length}/7 '
        '(${atRest.join(", ")})');
    expect(
      atRest.length,
      greaterThanOrEqualTo(4),
      reason: 'ilk bakışta ${atRest.length} katman görünüyor — mikser gibi '
          'durmuyor (regresyon: eskiden 2 idi)',
    );

    // (2) Kaydırınca HEPSİ ulaşılabilir.
    final seen = <String>{...atRest};
    for (var i = 0; i < 15 && seen.length < 7; i++) {
      await t.drag(scroll, const Offset(0, -100));
      await t.pumpAndSettle();
      seen.addAll(visibleNow());
    }
    expect(
      seen,
      hasLength(7),
      reason: 'kaydırarak bile görünmeyen katman(lar) var: '
          '${defaultMixSpec().layers.map((l) => l.id).toSet().difference(seen)}',
    );
  });

  testWidgets('DİKİŞ YOK: hero ile kontrol bölgesi AYNI scrim alfasında',
      (t) async {
    // Emülatördeki keskin yatay çizgi bir "panel kenarı" değil, iki komşu
    // bölgenin alfa farkıydı (hero altta 0.0'a sönüyor, kontrol bölgesi 0.72 ile
    // başlıyordu → 0.72'lik basamak). Ölçüm: basamak SIFIR olmalı.
    await _pump(t);

    final sheet = t.widget<Container>(find.byKey(const Key('mixer-sheet')));
    final sheetColor = (sheet.decoration! as BoxDecoration).color!;

    // Hero'nun zemini: `mixer-title`'ı taşıyan DecoratedBox.
    final heroBox = t.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(const Key('mixer-title')),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );
    final heroColor = (heroBox.decoration as BoxDecoration).color!;

    expect(heroColor.a, closeTo(sheetColor.a, 1e-9),
        reason: 'hero ile kontrol bölgesi arasında alfa basamağı var → dikiş');
    expect(sheetColor.a, closeTo(kPlayerScrimAlpha, 1e-9));
    expect(sheetColor.r, NoctaColors.bgBase.r);

    // Yuvarlatılmış köşe KALDIRILDI: dikişi üreten kenarın kendisiydi.
    expect(
      (sheet.decoration! as BoxDecoration).borderRadius,
      isNull,
      reason: 'kontrol bölgesinin köşesi geri gelmiş — kenar da geri gelir',
    );
  });

  testWidgets('KÜÇÜK EKRAN: 320×568\'de taşma YOK ve kontroller hâlâ erişilebilir',
      (t) async {
    // Player üç bölgeye bölünmüş sabit bir düzen; en gerçek risk küçük telefonda
    // dikey taşma. (RenderFlex taşması testte exception'dır — bu test onu yakalar.)
    t.view.physicalSize = const Size(640, 1136); // 320×568 @2x
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);

    await _pump(t);

    final rect = t.getRect(find.byKey(const Key('mixer-toggle')));
    expect(rect.bottom, lessThanOrEqualTo(568));
    expect(t.getSize(find.byKey(const Key('mixer-toggle'))).height,
        greaterThanOrEqualTo(44));
    // Hero başlığı da ayakta (ekran daraldığında ilk feda edilen şey oydu).
    expect(find.byKey(const Key('mixer-title')), findsOneWidget);
  });

  testWidgets('KONTRAST: kontroller hareketli gradyanın üstünde SCRIM üzerinde',
      (t) async {
    await _pump(t);
    final box = t.widget<Container>(find.byKey(const Key('mixer-sheet')));
    final decoration = box.decoration! as BoxDecoration;
    final color = decoration.color!;

    // Scrim taban rengin kendisi olmalı (ton kaymasın), ve YARIDAN opak: ince
    // etiketler/sürgü rayları saydam bir yüzeyde okunmaz.
    expect(color.r, NoctaColors.bgBase.r);
    expect(color.g, NoctaColors.bgBase.g);
    expect(color.b, NoctaColors.bgBase.b);
    expect(color.a, greaterThan(0.6));
  });

  testWidgets('dokunma hedefleri ≥44px (CLAUDE.md §7)', (t) async {
    await _pump(t);
    expect(t.getSize(find.byKey(const Key('mixer-toggle'))).height,
        greaterThanOrEqualTo(44));
    expect(t.getSize(find.byKey(const Key('mixer-export-video'))).height,
        greaterThanOrEqualTo(44));
    // Sürgüler Material'ın kendi 48px hedefini kullanır.
    expect(t.getSize(find.byKey(const Key('gain-brown'))).height,
        greaterThanOrEqualTo(44));
  });

  testWidgets('ÇALAN ŞEYİN ADI hero başlıkta; durum satırı doğru', (t) async {
    await _pump(t, title: 'Deep Ocean Hush');

    expect(
      t.widget<Text>(find.byKey(const Key('mixer-title'))).data,
      'Deep Ocean Hush',
    );
    // Duraklatılmışken "Playing" yazmak yalan olurdu.
    expect(t.widget<Text>(find.byKey(const Key('mixer-status'))).data, 'Paused');

    await t.tap(find.byKey(const Key('mixer-toggle')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(t.widget<Text>(find.byKey(const Key('mixer-status'))).data, 'Playing');

    // Ticker'ı test bitmeden durdur (aksi hâlde sonraki pump'lar sonsuz döner).
    await t.tap(find.byKey(const Key('mixer-toggle')));
    await t.pumpAndSettle();
  });

  testWidgets(
      'ÇEKİRDEK: gece sürerken player UYKU SAYACINI gösterir — ve yalnızca BİR tane',
      (t) async {
    // Kullanıcı ritüeli başlatıp mikser'e geçiyor. "Kayıt sürüyor mu?" sorusunun
    // cevabı burada görünmeli. Sayaç kabuk şeridinden gelir (her ekranda), bu
    // yüzden player'a İKİNCİ bir sayaç konulmadı — çift sayaç, uyku modu
    // ekranında bilinçle kaçınılan hatanın mikserdeki kopyası olurdu.
    FlavorConfig.current = const FlavorConfig(
      flavor: Flavor.dev,
      name: 'DEV',
      apiBaseUrl: 'http://localhost:3001',
    );
    final beacon = SleepSessionBeacon()
      ..begin(DateTime.now().subtract(const Duration(minutes: 42)));
    addTearDown(beacon.end);

    await t.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingSeenProvider.overrideWith((ref) async => true),
          sessionBootstrapProvider.overrideWith((ref) => Future<void>.value()),
          sleepSessionBeaconProvider.overrideWithValue(beacon),
        ],
        child: const NoctaApp(),
      ),
    );
    await t.pumpAndSettle();
    appRouter.go('/mixer');
    await t.pumpAndSettle();
    addTearDown(() => appRouter.go('/'));

    // Gerçekten player'dayız.
    expect(find.byKey(const Key('mixer-toggle')), findsOneWidget);
    expect(find.byKey(const Key('ambient-backdrop')), findsOneWidget);

    // Sayaç görünür ve DOĞRU (donmuş bir "00:00:00" değil).
    expect(find.byKey(const Key('sleep-strip')), findsOneWidget);
    expect(
      t.widget<Text>(find.byKey(const Key('sleep-strip-elapsed'))).data,
      matches(RegExp(r'^00:42:0\d$')),
    );
    // TEK sayaç: player kendi kopyasını çizmiyor.
    expect(find.byKey(const Key('sleep-strip-elapsed')), findsOneWidget);
  });

  testWidgets('DÜRÜSTLÜK: erken sürüm notu player düzeninde de görünür',
      (t) async {
    await _pump(t);
    // Kullanıcı duyduğu şeyin nihai kalite olmadığını bilmeli — yeniden düzenleme
    // sırasında sessizce düşmesi en kolay şeydi.
    expect(
      find.text(
        'Early build: generated locally, looped. Sound quality is not final.',
      ),
      findsOneWidget,
    );
  });
}
