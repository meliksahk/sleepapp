import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/launch/launch_phase.dart';
import 'package:nocta/core/launch/moon_painter.dart';

/// Ayın **gerçekten çizildiğini ve gerçekten HİLAL olduğunu** ölçer.
///
/// "CustomPaint ağaçta var" demek hiçbir şey kanıtlamaz — boş bir painter da
/// ağaçta görünür. Bu dosya boyayı gerçek bir tuvale döküp PİKSEL okur.
///
/// ⚠️ Ölçtüğü şey GEOMETRİ ve PARLAKLIK; GÜZELLİK değil (CLAUDE.md §1.1).
/// Ayın hoş görünüp görünmediği cihaz ekranında insana aittir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 600);
  // Painter'ın kendi yerleşim sabitleriyle aynı hesap.
  final center = Offset(size.width / 2, size.height * 0.44);

  Future<ui.Image> render(LaunchPhase phase, {double scale = 1.0}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    MoonPainter(
      phase: ValueNotifier<LaunchPhase>(phase),
      scale: scale,
    ).paint(canvas, size);
    return recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
  }

  /// Bir pikselin toplam ışığı (0–765). Alfa ile çarpılır: saydam piksel karanlıktır.
  Future<double> lightAt(ui.Image image, Offset p) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final i = ((p.dy.round() * image.width) + p.dx.round()) * 4;
    final bytes = data!.buffer.asUint8List();
    final a = bytes[i + 3] / 255.0;
    return (bytes[i] + bytes[i + 1] + bytes[i + 2]) * a;
  }

  // Zarfın tepesi (attack 0.60 sn) — ayın en canlı anı.
  final peak = launchPhaseAt(const Duration(milliseconds: 600));

  /// Yarıçap zarfla NEFES ALIR (%5). Sabit yarıçap varsayan bir prob birkaç
  /// piksel şaşar ve yıldız gibi küçük şeyleri tamamen ıskalar — bu test
  /// yazılırken tam olarak bu oldu.
  double radiusAt(LaunchPhase p, [double scale = 1.0]) =>
      math.min(size.width, size.height) * 0.155 * scale * (1 + 0.05 * p.glow);

  // Gölge dairesinin merkezi: hilalin KARANLIK tarafı.
  final shadowDir = Offset(math.cos(-math.pi * 0.20), math.sin(-math.pi * 0.20));
  Offset darkSideAt(LaunchPhase p) =>
      center + shadowDir * (radiusAt(p) * (0.66 + 0.20 * p.glow));
  // Aydınlık limb: gölgenin tam tersi yön.
  Offset litSideAt(LaunchPhase p, [double scale = 1.0]) =>
      center - shadowDir * (radiusAt(p, scale) * 0.80);

  test('ÇEKİRDEK: çizilen şey HİLAL — aydınlık limb var, gölge tarafı karanlık', () async {
    final image = await render(peak);
    final lit = await lightAt(image, litSideAt(peak));
    final dark = await lightAt(image, darkSideAt(peak));

    expect(lit, greaterThan(200), reason: 'ayın aydınlık tarafı çizilmemiş');
    // Dolu bir disk çizilseydi bu iki değer birbirine yakın olurdu. Hilal
    // olduğunun kanıtı aradaki UÇURUM.
    expect(dark, lessThan(lit / 3), reason: 'gölge yok → bu bir hilal değil, disk');
  });

  test('ÇEKİRDEK: ay SESLE canlanır — sessizde sönük, tepede belirgin parlak', () async {
    // t=0'da ay YOK OLMAZ (native splash'taki hilalle devamlılık, bkz. painter),
    // ama sesin tepesinde belirgin biçimde canlanmalı.
    final silentPhase = launchPhaseAt(Duration.zero);
    final silent = await lightAt(await render(silentPhase), litSideAt(silentPhase));
    final loud = await lightAt(await render(peak), litSideAt(peak));

    expect(loud, greaterThan(200));
    expect(silent, greaterThan(0), reason: 'ilk kare boş → native splash ile dikiş atar');
    expect(silent, lessThan(loud * 0.65),
        reason: 'zarf ayı canlandırmıyor (senkron kopuk)');
  });

  test('ay sesin sönüşünü izler: 3.6 sn sonunda yine dinginleşmiş', () async {
    final endPhase = launchPhaseAt(const Duration(milliseconds: 3600));
    final end = await lightAt(await render(endPhase), litSideAt(endPhase));
    final loud = await lightAt(await render(peak), litSideAt(peak));
    expect(end, lessThan(loud * 0.65));
  });

  test('kenar dalgalanması siluetin HİLAL olmasını bozmuyor', () async {
    // Deformasyon genliği R'nin %3.2'siyle sınırlı: ayın merkezinden R'nin
    // %70'i uzaktaki aydınlık nokta HER karede ay içinde kalmalı, dışındaki
    // %140'lık nokta ise HER karede ay dışında.
    for (final ms in <int>[600, 900, 1400, 2000]) {
      final p = launchPhaseAt(Duration(milliseconds: ms));
      final image = await render(p);
      final inside = await lightAt(image, center - shadowDir * (radiusAt(p) * 0.70));
      final outside = await lightAt(image, center - shadowDir * (radiusAt(p) * 1.40));
      expect(inside, greaterThan(150), reason: 't=$ms ms: siluet içeri çökmüş');
      expect(outside, lessThan(inside / 2), reason: 't=$ms ms: siluet taşmış');
    }
  });

  test('çıkış mikroanimasyonunda ay KÜÇÜLÜR (ölçülebilir)', () async {
    // Tam boyuttaki ayın kenarına çok yakın bir nokta: %12 küçülünce dışarıda kalır.
    final probe = center - shadowDir * (radiusAt(peak) * 0.97);
    final full = await lightAt(await render(peak), probe);
    final shrunk = await lightAt(await render(peak, scale: 0.88), probe);
    expect(full, greaterThan(shrunk * 2),
        reason: 'scale küçültmesi ayın kapladığı alanı değiştirmiyor');
  });

  test('ÇEKİRDEK: yıldızlar sesin parıltı anında GÖRÜNÜR ışık ekler', () async {
    final grain = launchGrains.first;
    LaunchPhase at(double t) =>
        launchPhaseAt(Duration(microseconds: (t * 1e6).round()));

    // İlk yıldızın konumu painter'ın slot tablosundaki ilk kayıt.
    Offset starAt(LaunchPhase p) =>
        center + Offset(math.cos(-2.55), math.sin(-2.55)) * (radiusAt(p) * 2.30);

    final quiet = at(grain.onset - 0.05);
    final flash = at(grain.onset + launchSparkleAttack);

    final before = await lightAt(await render(quiet), starAt(quiet));
    final during = await lightAt(await render(flash), starAt(flash));

    expect(during, greaterThan(before + 20),
        reason: 'ses parıldarken gökyüzünde bir şey olmuyor');
  });
}
