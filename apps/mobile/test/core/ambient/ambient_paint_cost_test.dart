import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/ambient/ambient_painter.dart';
import 'package:nocta/core/ambient/ambient_phase.dart';
import 'package:nocta/core/design_system/design_system.dart';

/// **Kare maliyeti ölçümü** — "ucuz" demek yetmez, sayı verilir.
///
/// ## Bu ölçüm NEYİ ölçer, NEYİ ÖLÇMEZ
///
/// ÖLÇER: `AmbientPainter.paint`'in Dart tarafındaki maliyeti — shader kurulumu,
/// geometri hesabı ve display list'e kayıt (yani UI thread'de harcanan zaman).
/// Kare bütçesini asıl bu tüketir, çünkü bu iş her karede yeniden yapılır.
///
/// ÖLÇMEZ: GPU rasterleştirme süresi. `flutter test` başsız çalışır, gerçek bir
/// raster thread yoktur. Gerçek cihaz rakamı için DevTools/`--profile` gerekir ve
/// bu YAPILMADI (bkz. rapor). Aşağıdaki sayılar bir ALT SINIRDIR, tam maliyet değil.
///
/// Ayrıca burada ölçülen makine, CI makinesi değil geliştirme makinesidir; eşik
/// bu yüzden geniş tutuldu — amaç regresyon kapısı, mikro-benchmark değil.
void main() {
  test('ÖLÇÜM: kare başına paint maliyeti', () {
    const size = Size(390, 844); // tipik telefon mantıksal ölçüsü
    final phase = ValueNotifier<AmbientPhase>(AmbientPhase.zero);
    final painter = AmbientPainter(
      phase: phase,
      gradient: NoctaArchetypeGradient.deepOcean,
      drive: AmbientDrive.fromGains(const <String, double>{
        'brown': 0.28,
        'pink': 0.12,
        'white': 0.06,
        'waves': 0.22,
        'rain': 0.14,
        'fire': 0.10,
        'pad': 0.08,
      }),
    );

    // Isıtma: ilk çağrılar JIT ve shader nesne kurulumunu içerir.
    for (var i = 0; i < 50; i++) {
      _paintOnce(painter, phase, size, i);
    }

    const iterations = 600; // 12 fps'te 50 saniyelik animasyon
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      _paintOnce(painter, phase, size, i);
    }
    sw.stop();

    final perFrameUs = sw.elapsedMicroseconds / iterations;
    // 12 fps'te saniyede harcanan UI-thread zamanının oranı.
    final dutyPercent = perFrameUs * 12 / 10000;

    debugPrint(
      'ÖLÇÜM kare maliyeti: ${perFrameUs.toStringAsFixed(1)} µs/kare '
      '($iterations kare, 390x844) → 12 fps\'te CPU görev oranı '
      '≈ %${dutyPercent.toStringAsFixed(3)}',
    );

    // Kapı: 16.7 ms'lik 60 Hz bütçesinin onda biri. Bunu aşan bir değişiklik
    // (ör. MaskFilter.blur eklemek) sessizce geçmesin.
    expect(perFrameUs, lessThan(1670));
  });

  test('ÖLÇÜM: 3 ışıma + doku bandı yerine sadece taban — fark ne kadar', () {
    const size = Size(390, 844);
    final phase = ValueNotifier<AmbientPhase>(AmbientPhase.zero);

    double measure(AmbientDrive drive) {
      final p = AmbientPainter(
        phase: phase,
        gradient: NoctaArchetypeGradient.deepOcean,
        drive: drive,
      );
      for (var i = 0; i < 30; i++) {
        _paintOnce(p, phase, size, i);
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 300; i++) {
        _paintOnce(p, phase, size, i);
      }
      sw.stop();
      return sw.elapsedMicroseconds / 300;
    }

    final withTexture = measure(
      const AmbientDrive(motion: 0.5, glow: 0.5, texture: 0.6),
    );
    final withoutTexture = measure(
      const AmbientDrive(motion: 0.5, glow: 0.5, texture: 0.0),
    );

    debugPrint(
      'ÖLÇÜM doku bandı maliyeti: ${withTexture.toStringAsFixed(1)} µs '
      'vs ${withoutTexture.toStringAsFixed(1)} µs/kare',
    );
    // İddia yok, yalnızca ikisinin de çizildiğinin ve ölçüldüğünün kaydı.
    expect(withTexture, greaterThan(0));
    expect(withoutTexture, greaterThan(0));
  });
}

/// Tek kareyi gerçek bir `Canvas`'a çizer (kayıt maliyeti dahil).
void _paintOnce(
  AmbientPainter painter,
  ValueNotifier<AmbientPhase> phase,
  Size size,
  int frame,
) {
  // Faz her karede ilerlesin: sabit fazda ölçmek, gerçek kullanımda olmayan bir
  // önbellek avantajı yaratabilirdi.
  phase.value = ambientPhaseAt(
    Duration(milliseconds: (frame * 1000 / 12).round()),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
}
