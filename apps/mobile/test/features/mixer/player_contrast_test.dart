import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/ambient/ambient.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/features/archetype/archetype_gradient.dart';
import 'package:nocta/features/mixer/presentation/mixer_screen.dart';

/// KONTRAST KAPISI — player scrim'inin okunabilirliği ÖLÇÜLÜR, varsayılmaz.
///
/// **Bu dosyanın varlık sebebi:** hero başta scrim'siz bırakılmıştı ve koddaki
/// gerekçe ("orası zaten en koyu bölge") YANLIŞTI — yalnızca taban gradyanını
/// hesaba katıyor, painter'ın kendi `BlendMode.plus` ışımalarını unutuyordu.
/// Işıma merkezleri tam da metin bandına düşüyor. İki bağımsız denetim gerçek
/// render edilmiş piksellerden ölçtü: küçük metinler dört arketipte de 1.10–2.15
/// kontrast veriyordu (WCAG AA eşiği 4.5). Bu bir görüş değil, hesaplanabilir bir
/// başarısızlıktı — o yüzden artık test.
///
/// ## ⚠️ BU DOSYA BİR KEZ YALAN SÖYLEDİ — ve neden bir daha söyleyemez
///
/// Önceki hâli üretimdeki scrim'i **kopyalıyordu** ("üretimdeki değerlerle
/// BİREBİR aynı olmalı" yorumuyla birlikte). Kopya ile üretim birbirinden
/// ayrıldı: test yukarıdan aşağı KOYULAŞAN bir gradyan (0.0 → 0.93) ölçerken
/// üretimde tam tersi (0.86 → 0.0) vardı ve metin, scrim'in SIFIRA indiği yerde
/// duruyordu. Yani test yeşildi ve ölçtüğü şey ekranda yoktu.
///
/// Artık kopya yok: [kPlayerScrimAlpha] ve [playerScrimFade] doğrudan üretim
/// dosyasından import ediliyor. Üretimdeki değer değişirse buradaki ölçüm de
/// değişir.
void main() {
  /// WCAG bağıl parlaklık.
  double luminance(int r, int g, int b) {
    double ch(int v) {
      final s = v / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b);
  }

  double contrast(double l1, double l2) {
    final hi = math.max(l1, l2);
    final lo = math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Ambiyansı + ÜRETİMDEKİ scrim'i gerçekten piksellere render eder ve metnin
  /// bulunabileceği bandın EN KÖTÜ (en açık) pikselinde kontrastı döner.
  ///
  /// Ölçülen bant, yumuşama bandının BİTTİĞİ yerden ekranın altına kadar: metin
  /// (hero başlığı, katman etiketleri, yüzdeler, erken sürüm notu) yalnızca orada
  /// yaşıyor. Yumuşama bandının kendisi kasıtlı olarak yarı saydam ve orada metin
  /// YOK — AppBar'ın geri ikonu var (bkz. rapordaki açık madde).
  Future<double> worstContrast({
    required String slug,
    required Color textColor,
    required double phase,
  }) async {
    const w = 390.0;
    const h = 844.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

    // 1) Ambiyans arka planı (üretimdeki painter'ın kendisi).
    AmbientPainter(
      phase: ValueNotifier<AmbientPhase>(
        ambientPhaseAt(Duration(microseconds: (phase * 1e6).round())),
      ),
      gradient: archetypeGradientForSlug(slug),
      // EN KÖTÜ durum: tüm sürüş sonuna kadar açık (en parlak zemin).
      drive: const AmbientDrive(motion: 1.0, glow: 1.0, texture: 1.0),
    ).paint(canvas, const Size(w, h));

    // 2) Scrim — üretimin KENDİ tanımıyla. Önce yumuşama bandı, sonra düz örtü.
    const fadeTop = kToolbarHeight;
    const fadeBottom = fadeTop + kPlayerScrimFadeHeight;
    const fadeRect = Rect.fromLTRB(0, fadeTop, w, fadeBottom);
    final fade = playerScrimFade();
    canvas.drawRect(fadeRect, Paint()..shader = fade.createShader(fadeRect));
    canvas.drawRect(
      const Rect.fromLTRB(0, fadeBottom, w, h),
      Paint()..color = NoctaColors.bgBase.withValues(alpha: kPlayerScrimAlpha),
    );

    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();

    final textL = luminance(
      (textColor.r * 255).round(),
      (textColor.g * 255).round(),
      (textColor.b * 255).round(),
    );
    var worst = double.infinity;
    for (var y = fadeBottom.toInt(); y < h.toInt(); y += 3) {
      for (var x = 20; x < 370; x += 5) {
        final i = (y * w.toInt() + x) * 4;
        final c = contrast(textL, luminance(bytes[i], bytes[i + 1], bytes[i + 2]));
        if (c < worst) worst = c;
      }
    }
    image.dispose();
    return worst;
  }

  // Dört arketip x birkaç faz: kabarma tepe noktasında zemin en parlak olur.
  for (final slug in <String>['deep-ocean', 'overthinker', 'delta-drifter', 'dawn-chaser']) {
    testWidgets('$slug: KÜÇÜK metin WCAG AA geçer (≥4.5)', (tester) async {
      // `runAsync` ŞART: `toImage()` gerçek async iş yapar ve flutter_test'in
      // sahte zaman bölgesinde ASILI KALIR. Repoda aynı tuzak card_renderer'da
      // belgeli (orada sahte renderer enjekte ediliyor); burada gerçek pikselleri
      // ölçmek istediğimiz için doğru çözüm runAsync.
      var worst = double.infinity;
      await tester.runAsync(() async {
        for (final t in <double>[0.0, 2.5, 5.0, 7.5, 10.0, 15.0]) {
          final c = await worstContrast(
            slug: slug,
            textColor: NoctaColors.inkSecondary,
            phase: t,
          );
          if (c < worst) worst = c;
        }
      });
      // ignore: avoid_print
      print('ÖLÇÜM $slug inkSecondary en kötü kontrast: ${worst.toStringAsFixed(2)}');
      expect(
        worst,
        greaterThanOrEqualTo(4.5),
        reason: '$slug: küçük metin AA eşiğini geçmeli (ölçülen $worst)',
      );
    });
  }

  testWidgets('en kötü arketipte BÜYÜK başlık da rahat geçer (≥4.5)', (tester) async {
    // dawn-chaser denetimde en açık zemini veren arketipti (2.49'da kalıyordu).
    var worst = double.infinity;
    await tester.runAsync(() async {
      for (final t in <double>[0.0, 5.0, 7.5, 10.0]) {
        final c = await worstContrast(
          slug: 'dawn-chaser',
          textColor: NoctaColors.inkPrimary,
          phase: t,
        );
        if (c < worst) worst = c;
      }
    });
    // ignore: avoid_print
    print('ÖLÇÜM dawn-chaser inkPrimary en kötü kontrast: ${worst.toStringAsFixed(2)}');
    expect(worst, greaterThanOrEqualTo(4.5));
  });

  test('DİKİŞ YOK: yumuşama bandı düz örtüyle AYNI alfada bitiyor', () {
    // Emülatörde görülen keskin yatay çizginin ölçülebilir tanımı budur:
    // gradyanın bittiği alfa ile altındaki bölgenin alfası arasındaki BASAMAK.
    // Sıfır basamak = çizilecek kenar yok.
    final fade = playerScrimFade();
    expect(
      fade.colors.last.a,
      closeTo(kPlayerScrimAlpha, 1e-9),
      reason: 'yumuşama bandı, altındaki örtüden farklı bir alfada bitiyor → dikiş',
    );
    expect(
      fade.colors.first.a,
      0.0,
      reason: 'bandın üst ucu tam saydam olmalı, yoksa başladığı yerde kenar olur',
    );

    // Monotonluk: profilde geri dönüş olsaydı gözle görülür bir kuşak olurdu.
    for (var i = 1; i < fade.colors.length; i++) {
      expect(fade.colors[i].a, greaterThan(fade.colors[i - 1].a));
    }

    // Uçlarda eğim yumuşak mı (smoothstep): ilk ve son adım, ORTA adımdan
    // belirgin biçimde küçük olmalı. Doğrusal bir rampada üçü de eşit olurdu ve
    // iki uçta birer kırık (Mach bandı) kalırdı.
    final steps = <double>[
      for (var i = 1; i < fade.colors.length; i++)
        fade.colors[i].a - fade.colors[i - 1].a,
    ];
    final middle = steps[steps.length ~/ 2];
    expect(steps.first, lessThan(middle * 0.6));
    expect(steps.last, lessThan(middle * 0.6));
  });
}
