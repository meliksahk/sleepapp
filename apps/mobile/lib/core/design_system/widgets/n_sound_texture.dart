import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio_engine/dsp/mix_render.dart';
import '../generated/nocta_tokens.dart';

/// Bir tarifin görsel imzası: hangi desen, ne sıklıkta, nereden başlayarak.
///
/// Saf veri: çizim yapmadan test edilebilsin diye ayrı durur.
class SoundTextureSignature {
  const SoundTextureSignature({
    required this.shape,
    required this.density,
    required this.phase,
  });

  final SoundTextureShape shape;

  /// Kaç bant/çizgi/nokta sırası. Katman sayısından gelir: kalabalık mix
  /// kalabalık doku.
  final int density;

  /// [0,1) deterministik kaydırma: aynı desendeki iki tarif üst üste binmesin.
  final double phase;
}

/// Desen aileleri. Her sentez kaynağı kendi desenini alır (bkz. [soundTextureSignature]).
enum SoundTextureShape {
  hatch,
  speckle,
  band,
  wave,
  streak,
  flame,
  arc,
  pulse,
  chord,
  steps,
  ripple,
  hanging,
  spiral,
  zigzag,
}

/// **Doku SESTEN türer.** Eskiden tek algoritma vardı (slug hash'li tarama
/// çizgisi): gömülü 25 tarif, on farklı baskın sese rağmen aynı çizgili kare
/// olarak görünüyordu. Artık deseni mix'in BASKIN katmanı seçer: yağmur çizik,
/// ateş titrek çubuk, dalga sinüs, kahverengi gürültü kalın bant, topaç sarmal.
/// Sıklık katman sayısından, kayma slug'dan gelir.
///
/// [spec] null ya da sentez katmansız olabilir (tarif çözülemedi, ya da yalnız
/// dosya katmanı var: ithal dosyanın sentez karakteri yoktur). O zaman nötr
/// tarama deseni kalır.
SoundTextureSignature soundTextureSignature(MixSpec? spec, int seed) {
  final int layers = spec?.totalLayerCount ?? 0;
  return SoundTextureSignature(
    shape: _shapeOf(_dominantSource(spec)),
    // 4..8: tek katmanlı tarif seyrek, beş+ katmanlı yoğun görünür.
    density: 4 + layers.clamp(0, 4),
    phase: (seed.abs() % 997) / 997,
  );
}

/// En yüksek kazançlı sentez katmanı: sesin karakterini o taşır. Eşitlikte
/// enum sırası kazanır, böylece aynı tarif her açılışta aynı yüzü alır.
LayerSource? _dominantSource(MixSpec? spec) {
  final layers = spec?.layers;
  if (layers == null || layers.isEmpty) return null;
  MixLayer best = layers.first;
  for (final l in layers.skip(1)) {
    if (l.gain > best.gain || (l.gain == best.gain && l.type.index < best.type.index)) {
      best = l;
    }
  }
  return best.type;
}

/// Her kaynak AYRI bir desen alır. Yeni bir [LayerSource] eklenince bu switch
/// derlenmez: yeni sesin yüzü bilinçli seçilsin, sessizce taramaya düşmesin.
SoundTextureShape _shapeOf(LayerSource? source) => switch (source) {
  LayerSource.white => SoundTextureShape.speckle,
  LayerSource.pink => SoundTextureShape.hatch,
  LayerSource.brown => SoundTextureShape.band,
  LayerSource.waves => SoundTextureShape.wave,
  LayerSource.rain => SoundTextureShape.streak,
  LayerSource.fire => SoundTextureShape.flame,
  LayerSource.pad => SoundTextureShape.arc,
  LayerSource.tone => SoundTextureShape.pulse,
  LayerSource.chords => SoundTextureShape.chord,
  LayerSource.arpeggio => SoundTextureShape.steps,
  LayerSource.ceramic => SoundTextureShape.ripple,
  LayerSource.chimes => SoundTextureShape.hanging,
  LayerSource.topSpin => SoundTextureShape.spiral,
  LayerSource.friction => SoundTextureShape.zigzag,
  // Sentez katmanı yok (yalnız dosya, ya da tarif çözülemedi): nötr tarama.
  null => SoundTextureShape.hatch,
};

/// Deseni çizen boyacı.
///
/// **TAŞMA:** `CustomPaint` çocuğunu kırpmaz. Desenlerin çoğu kutunun dışına
/// çıkabildiği için kırpma [paint]'in İLK satırında yapılır; boyacı hangi
/// kareye konursa konsun komşu satırın üstüne taşmaz.
class SoundTexturePainter extends CustomPainter {
  const SoundTexturePainter(this.signature);

  final SoundTextureSignature signature;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    final rand = math.Random((signature.phase * 997).round() + 7);
    final paint = Paint()
      ..color = NoctaColors.inkSecondary
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = NoctaColors.inkSecondary;
    final double n = signature.density.toDouble();
    final double offset = signature.phase * size.height;

    switch (signature.shape) {
      case SoundTextureShape.hatch:
        final step = size.width / n;
        for (double i = -size.height + offset % step; i < size.width; i += step) {
          canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
        }
      case SoundTextureShape.speckle:
        // Beyaz gürültü: yönü olmayan, eşit dağılmış tanecik.
        for (var i = 0; i < n * n; i++) {
          canvas.drawCircle(
            Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
            0.9,
            fill,
          );
        }
      case SoundTextureShape.band:
        // Kahverengi gürültü: kalın yatay bantlar.
        final step = size.height / n;
        for (var i = 0; i < n; i++) {
          final y = (i * step + offset) % size.height;
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, step * 0.35), fill);
        }
      case SoundTextureShape.wave:
        final step = size.height / n;
        for (var i = 0; i < n; i++) {
          final y = (i * step + offset) % size.height;
          final path = Path()..moveTo(0, y);
          for (double x = 0; x <= size.width; x += 2) {
            path.lineTo(x, y + math.sin(x / size.width * math.pi * 2) * step * 0.4);
          }
          canvas.drawPath(path, paint);
        }
      case SoundTextureShape.streak:
        // Yağmur: eğik, kısa, düzensiz aralıklı çizikler.
        final step = size.width / n;
        for (double x = -step; x < size.width + step; x += step) {
          final top = rand.nextDouble() * size.height * 0.5;
          canvas.drawLine(
            Offset(x + offset % step, top),
            Offset(x + offset % step - size.width * 0.15, top + size.height * 0.5),
            paint,
          );
        }
      case SoundTextureShape.flame:
        // Ateş: tabandan yükselen, boyu titreyen dikey çubuklar.
        final step = size.width / n;
        for (var i = 0; i < n; i++) {
          final x = i * step + step / 2;
          final h = size.height * (0.3 + rand.nextDouble() * 0.6);
          canvas.drawLine(Offset(x, size.height), Offset(x, size.height - h), paint);
        }
      case SoundTextureShape.arc:
        // Pad: tek merkezden yayılan halkalar; sürekli, tekrar eden ton.
        final center = Offset(size.width / 2, size.height / 2);
        final step = size.width / (n * 1.5);
        for (var i = 1; i <= n; i++) {
          canvas.drawCircle(center, i * step + offset % step, paint);
        }
      case SoundTextureShape.pulse:
        // Sabit ton: eşit aralıklı dolu çubuklar; düzenliliğin kendisi desen.
        final step = size.width / n;
        for (var i = 0; i < n; i++) {
          canvas.drawRect(
            Rect.fromLTWH(i * step + step * 0.3, 0, step * 0.25, size.height),
            fill,
          );
        }
      case SoundTextureShape.chord:
        // Akor: aynı anda çalan notalar; dikey üçlü nokta kümeleri.
        final step = size.width / n;
        for (var i = 0; i < n; i++) {
          final x = i * step + step / 2;
          final base = size.height * (0.25 + rand.nextDouble() * 0.5);
          for (var k = -1; k <= 1; k++) {
            canvas.drawCircle(Offset(x, base + k * size.height * 0.12), 1.2, fill);
          }
        }
      case SoundTextureShape.steps:
        // Arpej: notalar sırayla yükselir; merdiven basamakları.
        final step = size.width / n;
        for (double y0 = offset % (size.height / 2); y0 < size.height * 1.5; y0 += size.height / 2) {
          final path = Path()..moveTo(0, y0);
          var y = y0;
          for (var i = 1; i <= n; i++) {
            path.lineTo(i * step, y);
            y -= step * 0.5;
            path.lineTo(i * step, y);
          }
          canvas.drawPath(path, paint);
        }
      case SoundTextureShape.ripple:
        // Seramik: vurulan tek noktadan yayılan halkalar; merkez köşeye yakın,
        // böylece pad'in ortalı halkalarından ayrılır.
        final center = Offset(size.width * 0.2, size.height * 0.8);
        final step = size.width / n;
        for (var i = 1; i <= n + 2; i++) {
          canvas.drawCircle(center, i * step + (offset % step) * 0.5, paint);
        }
      case SoundTextureShape.hanging:
        // Rüzgâr çanı: üstten sarkan, boyu değişen borular.
        final step = size.width / n;
        for (var i = 0; i < n; i++) {
          final x = i * step + step / 2;
          final h = size.height * (0.3 + rand.nextDouble() * 0.5);
          canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
          canvas.drawCircle(Offset(x, h), 1.4, fill);
        }
      case SoundTextureShape.spiral:
        // Topaç: merkezden açılan sarmal; yoğunluk tur sayısını artırır.
        final center = Offset(size.width / 2, size.height / 2);
        final maxR = size.width * 0.7;
        final turns = n / 2;
        final start = signature.phase * 2 * math.pi;
        final path = Path()..moveTo(center.dx, center.dy);
        const segments = 120;
        for (var i = 1; i <= segments; i++) {
          final t = i / segments;
          final a = start + t * turns * 2 * math.pi;
          path.lineTo(center.dx + math.cos(a) * t * maxR, center.dy + math.sin(a) * t * maxR);
        }
        canvas.drawPath(path, paint);
      case SoundTextureShape.zigzag:
        // Sürtünme: ileri geri sürtme; keskin dişli sıralar.
        final step = size.height / n;
        final tooth = size.width / (n * 1.5);
        for (var i = 0; i < n; i++) {
          final y = (i * step + offset) % size.height;
          final path = Path()..moveTo(0, y);
          var up = true;
          for (double x = tooth; x <= size.width + tooth; x += tooth) {
            path.lineTo(x, y + (up ? -step * 0.35 : step * 0.35));
            up = !up;
          }
          canvas.drawPath(path, paint);
        }
    }
  }

  @override
  bool shouldRepaint(SoundTexturePainter old) =>
      old.signature.shape != signature.shape ||
      old.signature.density != signature.density ||
      old.signature.phase != signature.phase;
}
