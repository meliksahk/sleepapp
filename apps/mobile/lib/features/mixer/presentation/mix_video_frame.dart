import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';

/// Mix-to-video'nun **tek karesi** — viral kanca #3 (docs/04 §131).
///
/// Biçim bilinçli olarak "audiogram": tüm mix'in dalga formu çizilir, üzerinde bir
/// playhead ilerler. Sosyalde bu format anında "bu bir ses" diye okunur — hareketsiz
/// bir gradyan videosu ise sessize alınmış bir akışta hiçbir şey söylemez.
///
/// Ekranda gösterilmek için değil, **kareye çevrilmek** için çizilir
/// (bkz. `renderWidgetToRgba`). Kart gibi bu da bir ÇIKTI, ekran değil.
class MixVideoFrame extends StatelessWidget {
  const MixVideoFrame({
    super.key,
    required this.title,
    required this.peaks,
    required this.progress,
    required this.gradient,
    required this.size,
  });

  final String title;

  /// Tüm mix'in özeti: sütun başına tepe genlik [0,1]. Kare başına yeniden
  /// hesaplanmaz — tüm karelerde AYNI dalga formu görünür, sadece playhead ilerler.
  final List<double> peaks;

  /// [0,1] — videonun neresindeyiz.
  final double progress;

  final LinearGradient gradient;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      // Sistem yazı boyutu paylaşılan artefaktı bozmasın (kartlarla aynı ilke).
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    key: const Key('mix-video-title'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 72,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: NoctaColors.inkPrimary,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 420,
                    child: CustomPaint(
                      painter: _WaveformPainter(peaks: peaks, progress: progress),
                      size: Size.infinite,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'NOCTA',
                    key: const Key('mix-video-wordmark'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      letterSpacing: 12,
                      color: NoctaColors.inkPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dalga formu: çalınmış kısım parlak, kalan sönük.
class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.peaks, required this.progress});

  final List<double> peaks;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final barWidth = size.width / peaks.length;
    // Çubuklar arası boşluk oransal: sütun sayısı değişse de görüntü aynı kalır.
    final gap = barWidth * 0.35;
    final playedTo = size.width * progress.clamp(0.0, 1.0);
    final mid = size.height / 2;

    for (var i = 0; i < peaks.length; i++) {
      final x = i * barWidth;
      final played = x + barWidth / 2 <= playedTo;
      // En az 4 piksel: sessiz anlarda dalga formu tamamen kaybolmasın, ses
      // "durmuş" gibi görünmesin.
      final h = math.max(4.0, peaks[i].clamp(0.0, 1.0) * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + gap / 2, mid - h / 2, barWidth - gap, h),
          const Radius.circular(4),
        ),
        Paint()
          ..color = NoctaColors.inkPrimary.withValues(alpha: played ? 0.95 : 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.peaks != peaks;
}

/// [samples]'ı [columns] sütunluk tepe özetine indirger (her sütunun mutlak tepesi).
///
/// **Tepe, RMS değil:** RMS gürültü için neredeyse düz bir çizgi verir (tanım gereği
/// durağan) ve dalga formu ölü görünür. Tepe, ses dokusunu görünür kılar.
///
/// Sonuç [0,1] aralığına **normalize edilir**: uyku mix'leri kasten kısıktır
/// (-20 dBFS civarı); ham tepeleri çizmek ekranın ortasında ince bir çizgi bırakırdı.
/// Bu görsel bir ölçek, bir ses ölçümü değil — video ses seviyesi iddia etmez.
List<double> waveformPeaks(Float32List samples, {int columns = 64}) {
  if (samples.isEmpty || columns <= 0) return const [];

  final peaks = List<double>.filled(columns, 0);
  for (var c = 0; c < columns; c++) {
    final start = samples.length * c ~/ columns;
    final end = samples.length * (c + 1) ~/ columns;
    var peak = 0.0;
    for (var i = start; i < end; i++) {
      final v = samples[i].abs();
      if (v > peak) peak = v;
    }
    peaks[c] = peak;
  }

  final maxPeak = peaks.reduce(math.max);
  // Tamamen sessiz mix: 0'a bölmek yerine düz sıfır dön — çağıran taban çizgisini
  // yine de çizer.
  if (maxPeak <= 0) return peaks;
  return [for (final p in peaks) p / maxPeak];
}
