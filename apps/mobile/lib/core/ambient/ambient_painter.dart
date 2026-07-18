import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import 'ambient_phase.dart';

/// Ambiyans arka planının çizim katmanı — **saf CustomPainter, shader yok**.
///
/// ## Neden CustomPainter (a), FragmentProgram (b) değil
///
/// - (b) GLSL: repoda hiç shader yok, `pubspec.yaml`'da `shaders:` bildirimi yok.
///   Eklemek Impeller/Skia ikiliğinde platform riski açar ve en önemlisi
///   **test edilemez**: `FragmentProgram.fromAsset` widget testinde yüklenmez, yani
///   "arka plana geçince durdu mu", "faz sesle aynı mı" sorularını CI'da
///   kanıtlayamazdık. Bu proje kanıtsız "çalışıyor" demiyor (CLAUDE.md §0).
/// - (c) parçacık sistemi: N parçacık = kare başına N durum güncellemesi ve
///   döngüselliği (30 sn'de birebir başa dönme) elle garanti etmek gerekir.
///   Gece boyu açık kalacak bir ekranda en pahalı ve en kırılgan seçenek.
/// - (a) CustomPainter: kare başına ~6 shader + 6 draw. Ölçüldü (bkz.
///   `test/core/ambient/ambient_paint_cost_test.dart`), rakam raporda.
///
/// ## Döngüsellik nasıl garanti edildi
///
/// Zamana bağlı her büyüklük `sin/cos(2π·(k·p + φ))` biçimindedir; p ∈ [0,1)
/// döngüdeki konum, k **tam sayı**. Bu yüzden p=0 ve p=1'de hem değer hem türev
/// aynıdır → dikişte sıçrama yok. Ses tarafındaki `loopLockedPeriod` kısıtının
/// görsel karşılığı budur.
class AmbientPainter extends CustomPainter {
  AmbientPainter({
    required this.phase,
    required this.gradient,
    required this.drive,
  }) : super(repaint: phase);

  /// Faz kaynağı. `repaint:` olarak verildiği için widget ağacı YENİDEN
  /// KURULMAZ — kare başına yalnızca `paint` çalışır (build/layout yok).
  final ValueListenable<AmbientPhase> phase;

  /// Kimlik gradyanı (arketip) veya marka gradyanı.
  final LinearGradient gradient;

  final AmbientDrive drive;

  /// Işıma merkezlerinin döngüye kilitli parametreleri.
  ///
  /// `kx`/`ky` tam sayı olmak ZORUNDA (döngüsellik); farklı olmaları merkezlerin
  /// Lissajous benzeri, kendini tekrar etmeyen ama kapalı bir yol izlemesini sağlar.
  static const List<_Bloom> _blooms = <_Bloom>[
    _Bloom(kx: 1, ky: 1, px: 0.00, py: 0.25, ax: 0.22, ay: 0.18, r: 0.70, a: 0.30),
    _Bloom(kx: 1, ky: 2, px: 0.37, py: 0.10, ax: 0.26, ay: 0.14, r: 0.52, a: 0.24),
    _Bloom(kx: 2, ky: 1, px: 0.68, py: 0.55, ax: 0.18, ay: 0.22, r: 0.44, a: 0.20),
  ];

  /// Taban gradyanının karartma oranı.
  ///
  /// Arketip gradyanları KART için tasarlandı (küçük yüzey, yüksek doygunluk).
  /// Tüm ekranı o doygunlukta boyamak bir uyku uygulamasında hem göz yorar hem
  /// OLED'de pil yakar. Kimliğin RENK TONU korunur, parlaklık taban rengine çekilir.
  static const double _baseDarkening = 0.74;

  @override
  void paint(Canvas canvas, Size size) {
    final p = phase.value;
    final rect = Offset.zero & size;
    if (size.isEmpty) return;

    final c0 = gradient.colors.first;
    final c1 = gradient.colors.last;

    // 1) Taban: kimlik gradyanının karartılmışı.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: gradient.begin,
          end: gradient.end,
          colors: <Color>[
            Color.lerp(c0, NoctaColors.bgBase, _baseDarkening)!,
            Color.lerp(c1, NoctaColors.bgBase, _baseDarkening)!,
          ],
        ).createShader(rect),
    );

    // 2) Işımalar: nefes ile parlar, kabarma ile büyür.
    //    Kabarma (swell) SES ile aynı faz → "müziğe uygun" olan tam olarak bu.
    final highlight = Color.lerp(c1, Colors.white, 0.25 + 0.30 * drive.glow)!;
    final bloomColors = <Color>[highlight, c1, Color.lerp(c1, c0, 0.5)!];
    final shortSide = math.min(size.width, size.height);
    const twoPi = 2 * math.pi;

    for (var i = 0; i < _blooms.length; i++) {
      final b = _blooms[i];
      final cx = size.width * (0.5 + b.ax * math.sin(twoPi * (b.kx * p.loop + b.px)));
      final cy = size.height * (0.5 + b.ay * math.sin(twoPi * (b.ky * p.loop + b.py)));

      // Yarıçap: taban + kabarma. Hareketin GENLİĞİ dalga katmanının payıyla
      // ölçeklenir → dalgayı kısan kullanıcı daha durgun bir arka plan görür.
      final grow = 0.30 * p.swell * (0.35 + 0.65 * drive.motion);
      final radius = shortSide * b.r * (0.85 + grow);

      // Opaklık: nefes (pad) parlaklığı sürer; taban 0.55 → hiç sönmez.
      final alpha =
          (b.a * (0.55 + 0.45 * p.breath) * (0.5 + 0.5 * drive.glow)).clamp(0.0, 1.0);

      final circle = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          // `plus`: ışımalar üst üste bindiğinde toplanır (ışık gibi), üst üste
          // BİNDİRME (srcOver) gibi birbirini kesmez. Blur'dan çok daha ucuz.
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              bloomColors[i].withValues(alpha: alpha),
              bloomColors[i].withValues(alpha: 0),
            ],
            // 0.35'e kadar düz, sonra sönüm: merkezi olan ama kenarı olmayan bir
            // ışıma. Tek duraklı gradyan çok "spot lambası" gibi görünürdü.
            stops: const <double>[0.35, 1.0],
          ).createShader(circle),
      );
    }

    // 3) Doku bandı: yağmur/ateş payı yükseldikçe belirginleşen yatay kuşak.
    //    Yatay konum kabarmayla iner-çıkar → "gelgit çizgisi".
    if (drive.texture > 0) {
      final bandCenter = size.height * (0.62 - 0.10 * p.swell);
      final bandHeight = size.height * 0.24;
      final bandRect = Rect.fromLTRB(
        0,
        bandCenter - bandHeight / 2,
        size.width,
        bandCenter + bandHeight / 2,
      );
      final bandAlpha = (0.06 + 0.10 * drive.texture) * (0.6 + 0.4 * p.swell);
      canvas.drawRect(
        bandRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              c1.withValues(alpha: 0),
              c1.withValues(alpha: bandAlpha.clamp(0.0, 1.0)),
              c1.withValues(alpha: 0),
            ],
          ).createShader(bandRect),
      );
    }

    // 4) Alt vignette: üstüne UI içeriği geleceği için okunabilirlik zemini.
    //    Sabit — animasyon değil, bu yüzden faz ile ilgisi yok.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            NoctaColors.bgBase.withValues(alpha: 0),
            NoctaColors.bgBase.withValues(alpha: 0.45),
          ],
          stops: const <double>[0.55, 1.0],
        ).createShader(rect),
    );
  }

  /// Faz `repaint:` listenable'ından geliyor; burada yalnızca YAPILANDIRMA
  /// değişikliği (kimlik gradyanı, mikser kazançları) kontrol edilir.
  @override
  bool shouldRepaint(AmbientPainter old) =>
      old.gradient != gradient || old.drive != drive || old.phase != phase;
}

/// Tek bir ışıma merkezinin döngüye kilitli tanımı.
class _Bloom {
  const _Bloom({
    required this.kx,
    required this.ky,
    required this.px,
    required this.py,
    required this.ax,
    required this.ay,
    required this.r,
    required this.a,
  });

  /// Yatay/dikey çevrim sayısı — döngü başına TAM SAYI (döngüsellik şartı).
  final int kx;
  final int ky;

  /// Faz ofsetleri [0,1) — merkezler aynı anda aynı yerde olmasın diye.
  final double px;
  final double py;

  /// Yörünge yarı genlikleri (ekran oranı).
  final double ax;
  final double ay;

  /// Yarıçap (kısa kenar oranı) ve taban opaklık.
  final double r;
  final double a;
}
