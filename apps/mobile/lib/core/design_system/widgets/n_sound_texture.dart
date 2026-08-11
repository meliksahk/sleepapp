import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio_engine/dsp/mix_render.dart';
import '../generated/nocta_tokens.dart';

/// Bir tarifin görsel imzası — hangi desen, ne sıklıkta, nereden başlayarak.
///
/// Saf veri: çizim yapmadan test edilebilir olsun diye ayrı durur.
class SoundTextureSignature {
  const SoundTextureSignature({
    required this.shape,
    required this.density,
    required this.phase,
  });

  final SoundTextureShape shape;

  /// Kaç bant/çizgi/nokta sırası — katman sayısından gelir: kalabalık mix
  /// kalabalık doku.
  final int density;

  /// [0,1) deterministik kaydırma — aynı desene sahip iki tarif üst üste
  /// binmesin diye.
  final double phase;
}

/// Desen aileleri. Her sentez kaynağı kendi ailesini alır (bkz. [soundTextureSignature]).
enum SoundTextureShape { hatch, speckle, band, wave, streak, flame, arc }

/// **Doku SESTEN türer.** Eskiden tek algoritma (slug hash'li tarama çizgisi)
/// vardı; yedi tarif yedi farklı ses olmasına rağmen yedi aynı kare görünüyordu.
/// Artık deseni mix'in BASKIN katmanı seçer: yağmur çizik, ateş dikey titrek,
/// dalga sinüs, brown kalın bant. Sıklık katman sayısından, kayma slug'dan.
///
/// [spec] null/boş olabilir (tarif çözülemedi ya da yalnızca dosya katmanı var —
/// ithal dosyanın sentez karakteri yoktur): o zaman eski tarama deseni kalır.
SoundTextureSignature soundTextureSignature(MixSpec? spec, int seed) {
  final LayerSource? dominant = _dominantSource(spec);
  final int layers = spec?.totalLayerCount ?? 0;
  return SoundTextureSignature(
    shape: _shapeOf(dominant),
    // 4..8: tek katmanlı tarif seyrek, beş+ katmanlı yoğun görünür.
    density: 4 + layers.clamp(0, 4),
    phase: (seed.abs() % 997) / 997,
  );
}

/// En yüksek kazançlı sentez katmanı = sesin karakterini kim taşıyor.
/// Eşitlikte enum sırası kazanır (deterministik — aynı tarif her açılışta aynı yüz).
LayerSource? _dominantSource(MixSpec? spec) {
  final layers = spec?.layers;
  if (layers == null || layers.isEmpty) return null;
  MixLayer best = layers.first;
  for (final l in layers.skip(1)) {
    if (l.gain > best.gain ||
        (l.gain == best.gain && l.type.index < best.type.index)) {
      best = l;
    }
  }
  return best.type;
}

SoundTextureShape _shapeOf(LayerSource? source) => switch (source) {
  LayerSource.white => SoundTextureShape.speckle,
  LayerSource.pink => SoundTextureShape.hatch,
  LayerSource.brown => SoundTextureShape.band,
  LayerSource.waves => SoundTextureShape.wave,
  LayerSource.rain => SoundTextureShape.streak,
  LayerSource.fire => SoundTextureShape.flame,
  LayerSource.pad => SoundTextureShape.arc,
  // Sentez katmanı yok (yalnız dosya, ya da tarif çözülemedi) → nötr tarama.
  null => SoundTextureShape.hatch,
};

/// Tarif karesi: "her sesin bir yüzü var" hissini görsel varlık indirmeden verir.
class NSoundTexture extends StatelessWidget {
  const NSoundTexture({
    super.key,
    required this.spec,
    required this.seed,
    this.size = 40,
  });

  final MixSpec? spec;

  /// Genelde `slug.hashCode` — aynı tarif her yerde aynı yüzü taşısın.
  final int seed;

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: NoctaColors.bgOverlay,
        child: CustomPaint(
          painter: SoundTexturePainter(soundTextureSignature(spec, seed)),
          size: Size(size, size),
        ),
      ),
    );
  }
}

/// Deseni çizen boyacı.
///
/// **TAŞMA:** `CustomPaint` çocuğunu kırpmaz — eski tarama deseni çapraz
/// çizgileri 40×40 karenin dışına, komşu satırın üstüne taşırıyordu. Her desen
/// kutunun dışına çıkabildiği için kırpma [paint]'in İLK satırında yapılır.
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
        final dot = Paint()..color = NoctaColors.inkSecondary;
        for (var i = 0; i < n * n; i++) {
          canvas.drawCircle(
            Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
            0.9,
            dot,
          );
        }
      case SoundTextureShape.band:
        // Brown: ağırlık altta, kalın yatay bantlar.
        final fill = Paint()..color = NoctaColors.inkSecondary;
        final step = size.height / n;
        for (var i = 0; i < n; i++) {
          final y = (i * step + offset) % size.height;
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, step * 0.35), fill);
        }
      case SoundTextureShape.wave:
        final step = size.height / n;
        for (var i = 0; i < n; i++) {
          final path = Path();
          final y = (i * step + offset) % size.height;
          path.moveTo(0, y);
          for (double x = 0; x <= size.width; x += 2) {
            path.lineTo(x, y + math.sin(x / size.width * math.pi * 2) * step * 0.4);
          }
          canvas.drawPath(path, paint);
        }
      case SoundTextureShape.streak:
        // Yağmur: dik, kısa, düzensiz aralıklı çizikler.
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
        // Pad: tek merkezden yayılan halkalar — sürekli, tekrar eden ton.
        final center = Offset(size.width / 2, size.height / 2);
        final step = size.width / (n * 1.5);
        for (var i = 1; i <= n; i++) {
          canvas.drawCircle(center, i * step + offset % step, paint);
        }
    }
  }

  @override
  bool shouldRepaint(SoundTexturePainter old) =>
      old.signature.shape != signature.shape ||
      old.signature.density != signature.density ||
      old.signature.phase != signature.phase;
}
