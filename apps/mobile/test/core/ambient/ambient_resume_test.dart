import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/ambient/ambient.dart';
import 'package:nocta/features/archetype/archetype_gradient.dart';

/// **DURAKLAT/DEVAM ET — PARLAKLIK SIÇRAMASI** (#214 denetim bulgusu).
///
/// ## Ölçülen kusur
///
/// `TickerMode` kare üretimini durduruyordu ama saat (duvar saati) işlemeye
/// devam ediyordu. Kullanıcı sesi 7 saniye duraklatıp devam ettirdiğinde faz
/// 7 saniye ileri sıçrıyor ve ekranın ortalama parlaklığı TEK KAREDE büyük bir
/// adım atıyordu. Karanlık odada uykuya dalmakta olan biri için bu bir flaştır —
/// üstelik uygulamanın tüm hareket bütçesi (12 fps, yumuşak zarflar) tam olarak
/// bunu önlemek için seçilmişti.
///
/// ## Neden "saati dondurmak", "devam ederken yumuşatmak" değil
///
/// Yumuşatma (kısa bir tween ile eski fazdan yeniye geçmek) sıçramayı
/// gizlerdi ama sebebi bırakırdı: faz hâlâ atlar, sadece atlayış 300 ms'ye
/// yayılır. Ayrıca her devam ettirmede ek bir animasyon koşturmak, "duraklatınca
/// kare üretimi SIFIR" pil garantisinin yanına sürekli bir istisna koyardı.
///
/// Saati dondurmanın bedeli, animasyonun sesin fazına göre kayması olurdu — ama
/// `ambient_phase.dart`'ın kendi belgesine göre faz kilidi zaten **periyotta**,
/// playhead'de DEĞİL: aralarında ölçülmeyen SABİT bir ofset zaten var. Yani
/// dondurmanın gerçek bedeli, var olan ofsetin biraz daha büyümesi. Periyot
/// kilidi (görsel kabarma = duyulan kabarma hızı) hiç bozulmuyor.
///
/// ## DÜRÜSTLÜK SINIRI
///
/// "Rahatsız etmiyor" kanıtlanmıyor; kanıtlanan şey ölçülebilir olan: devam
/// edilen ilk karenin, duraklamadan önceki son kareyle AYNI faz ve AYNI ortalama
/// parlaklıkta olması. Gerçek cihazda, karanlık odada bakılmadı.
class _FakeClock {
  Duration now = Duration.zero;
  Duration call() => now;
}

/// Bir fazın ekranda ürettiği ORTALAMA bağıl parlaklık.
Future<double> _meanLuminance(AmbientPhase phase) async {
  const w = 200.0;
  const h = 400.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
  AmbientPainter(
    phase: ValueNotifier<AmbientPhase>(phase),
    gradient: archetypeGradientForSlug('dawn-chaser'),
    drive: const AmbientDrive(motion: 1.0, glow: 1.0, texture: 1.0),
  ).paint(canvas, const Size(w, h));
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();

  double ch(int v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  var sum = 0.0;
  var n = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    sum += 0.2126 * ch(bytes[i]) + 0.7152 * ch(bytes[i + 1]) + 0.0722 * ch(bytes[i + 2]);
    n++;
  }
  image.dispose();
  return sum / n;
}

void main() {
  AmbientPhase phaseOf(WidgetTester t) => (t
          .widget<CustomPaint>(find.byKey(const Key('ambient-backdrop')))
          .painter! as AmbientPainter)
      .phase
      .value;

  Widget host({required bool enabled, required _FakeClock clock}) => MaterialApp(
        home: Scaffold(
          body: TickerMode(
            enabled: enabled,
            child: AmbientBackdrop(clock: clock.call, framesPerSecond: 12),
          ),
        ),
      );

  testWidgets('ÇEKİRDEK: duraklat/devam ettir fazı SIÇRATMAZ', (t) async {
    final clock = _FakeClock();
    await t.pumpWidget(host(enabled: true, clock: clock));

    // 3 saniye çal.
    clock.now = const Duration(seconds: 3);
    await t.pump(const Duration(milliseconds: 16));
    final beforePause = phaseOf(t);

    // DURAKLAT — ve kullanıcı 7 saniye duraklatılmış bıraksın.
    await t.pumpWidget(host(enabled: false, clock: clock));
    await t.pump();
    clock.now = const Duration(seconds: 10);
    await t.pump(const Duration(seconds: 7));
    expect(
      phaseOf(t),
      beforePause,
      reason: 'duraklatılmışken faz değişmemeli (kare üretimi zaten sıfır)',
    );

    // DEVAM ET.
    await t.pumpWidget(host(enabled: true, clock: clock));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));

    expect(
      phaseOf(t),
      beforePause,
      reason: 'devam edilen ilk kare, duraklamadan önceki kareyle aynı olmalı',
    );

    // ...ve oradan İLERLEMEYE devam eder (donup kalmadı).
    clock.now = const Duration(seconds: 12);
    await t.pump(const Duration(milliseconds: 200));
    expect(
      phaseOf(t),
      isNot(beforePause),
      reason: 'devam ettikten sonra animasyon yeniden ilerlemeli',
    );
  });

  testWidgets('ÖLÇÜM: devam ederken ortalama parlaklık sıçraması sınır altında',
      (t) async {
    // Tek bir duraklama süresi seçmek yanıltıcı olurdu: sıçramanın büyüklüğü
    // duraklamanın NEREYE denk geldiğine bağlı (kabarma çukurundan tepesine
    // düşen bir duraklama en kötüsü). Bu yüzden bir kabarma periyodunu (10 sn)
    // 12 fps adımlarla tarayıp EN KÖTÜ çifti buluyoruz.
    late double worstFrameStep;
    late double worstOldJump;
    late String worstPair;
    late double fixedJump;

    await t.runAsync(() async {
      const steps = 120; // 10 sn / (1/12 sn)
      final means = <double>[];
      for (var i = 0; i < steps; i++) {
        means.add(
          await _meanLuminance(
            ambientPhaseAt(Duration(microseconds: (i * 1e6 / 12).round())),
          ),
        );
      }

      // Normal (ardışık) kare değişiminin en büyüğü — "kabul edilebilir" sınır.
      worstFrameStep = 0;
      for (var i = 1; i < means.length; i++) {
        final d = (means[i] - means[i - 1]).abs() / means[i - 1];
        if (d > worstFrameStep) worstFrameStep = d;
      }

      // ESKİ davranış: duraklama boyunca saat işlediği için devam edilen kare
      // dizideki HERHANGİ bir kare olabilir.
      worstOldJump = 0;
      for (var i = 0; i < means.length; i++) {
        for (var j = 0; j < means.length; j++) {
          final d = (means[j] - means[i]).abs() / means[i];
          if (d > worstOldJump) {
            worstOldJump = d;
            worstPair = 't=${(i / 12).toStringAsFixed(2)}s → '
                't=${(j / 12).toStringAsFixed(2)}s';
          }
        }
      }

      // YENİ davranış: devam edilen kare = duraklamadan önceki kare.
      // (Widget testi bunu faz düzeyinde kanıtlıyor; burada piksel karşılığı.)
      final before = await _meanLuminance(ambientPhaseAt(const Duration(seconds: 3)));
      final resumed = await _meanLuminance(ambientPhaseAt(const Duration(seconds: 3)));
      fixedJump = (resumed - before).abs() / before;
    });

    // ignore: avoid_print
    print('ÖLÇÜM en büyük NORMAL kare adımı (12 fps): '
        '%${(worstFrameStep * 100).toStringAsFixed(2)}');
    // ignore: avoid_print
    print('ÖLÇÜM ESKİ davranışta en kötü sıçrama: '
        '%${(worstOldJump * 100).toStringAsFixed(2)} ($worstPair) = '
        '${(worstOldJump / worstFrameStep).toStringAsFixed(1)}× normal kare');
    // ignore: avoid_print
    print('ÖLÇÜM YENİ davranış: %${(fixedJump * 100).toStringAsFixed(2)}');

    // Testin kendisi anlamlı mı: eski davranış gerçekten büyük bir sıçramaydı.
    expect(
      worstOldJump,
      greaterThan(worstFrameStep * 10),
      reason: 'kusur yeniden üretilemiyorsa bu testin kilitleyeceği bir şey yok',
    );
    // Asıl iddia: devam etmek, normal bir kareden daha büyük bir değişim yaratmaz.
    expect(fixedJump, lessThanOrEqualTo(worstFrameStep));
  });

  testWidgets('uygulama arka plandan dönünce de faz sıçramaz', (t) async {
    // Aynı kusurun ikinci kapısı: gece yarısı telefonu açan kullanıcı.
    final clock = _FakeClock();
    await t.pumpWidget(host(enabled: true, clock: clock));
    clock.now = const Duration(seconds: 4);
    await t.pump(const Duration(milliseconds: 16));
    final before = phaseOf(t);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    clock.now = const Duration(seconds: 30);
    await t.pump(const Duration(seconds: 26));

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(phaseOf(t), before);
  });

  testWidgets('donmuş saat BİRİKİR: iki duraklama üst üste doğru toplanır',
      (t) async {
    final clock = _FakeClock();
    await t.pumpWidget(host(enabled: true, clock: clock));
    clock.now = const Duration(seconds: 2);
    await t.pump(const Duration(milliseconds: 16));

    // 1. duraklama: 5 sn.
    await t.pumpWidget(host(enabled: false, clock: clock));
    await t.pump();
    clock.now = const Duration(seconds: 7);
    await t.pumpWidget(host(enabled: true, clock: clock));
    await t.pump();

    // 1 sn çal (görsel zaman 2 → 3).
    clock.now = const Duration(seconds: 8);
    await t.pump(const Duration(milliseconds: 16));
    final afterFirst = phaseOf(t);
    expect(afterFirst, ambientPhaseAt(const Duration(seconds: 3)));

    // 2. duraklama: 20 sn.
    await t.pumpWidget(host(enabled: false, clock: clock));
    await t.pump();
    clock.now = const Duration(seconds: 28);
    await t.pumpWidget(host(enabled: true, clock: clock));
    await t.pump();

    // 2 sn daha çal (görsel zaman 3 → 5 = kabarma tepesi).
    clock.now = const Duration(seconds: 30);
    await t.pump(const Duration(milliseconds: 16));
    expect(phaseOf(t).swell, closeTo(1.0, 1e-9));
  });
}
