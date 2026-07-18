import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import 'launch_phase.dart';

/// Açılış anının çizim katmanı — **saf CustomPainter, shader/varlık yok**.
///
/// ## Neden CustomPainter (repo deseni)
///
/// `ambient_painter.dart` ile aynı gerekçe: GLSL `FragmentProgram` widget
/// testinde yüklenmez, yani "ay gerçekten çizildi mi", "faz sesle aynı mı"
/// sorularını CI'da kanıtlayamazdık (CLAUDE.md §0: kanıtsız "çalışıyor" yok).
/// Lottie/GIF ise APK'ya varlık ekler ve token renklerini takip edemez.
///
/// ## "Dalgalanma" nasıl yorumlandı — ve neden ay BOZULMUYOR
///
/// İlk akla gelen çözüm ayın siluetini dalgalandırmaktı. Denemeden reddedildi:
/// genlik görünür olacak kadar büyütüldüğünde ay AY OLMAKTAN çıkıp amorf bir
/// damlaya dönüşür — launcher ikonuyla (hilal) kurulan marka tanınırlığı
/// tam da açılış anında kaybedilirdi. Bunun yerine dalgalanma ÜÇ yerde:
///
/// 1. **Kenarda nefes gibi bir deformasyon** — genlik R'nin %3.2'siyle SINIRLI
///    (`_rimWobble`) ve yalnız 3. + 5. harmonikler. Siluet hilal kalır, kenar
///    canlı olur. θ'daki harmonikler TAM SAYI → yol her karede kapanır.
/// 2. **İçinden geçen ışık dalgası** — gölge dairesinin uzaklığı zarfla nefes
///    alır, yani hilal ses yükselirken KALINLAŞIR, sönerken incelir. Terminatör
///    (aydınlık/karanlık sınırı) böylece sesin içinden geçiyormuş gibi kayar.
///    Kullanıcının "dalgalanma" derken kastettiği hareketin merkezi bu.
/// 3. **Dışa açılan halkalar** — suya düşen damla gibi. Ayın kendisini bozmadan
///    "dalga" fikrini taşıyan katman.
///
/// Üçünün de genliği [LaunchPhase.glow] ile çarpılır: **ses yoksa hareket de yok.**
///
/// ⚠️ Bu sınıf ayın DOĞRU çizildiğini kanıtlar, GÜZEL olduğunu kanıtlamaz
/// (CLAUDE.md §1.1) — o yargı ekrana bakan insana aittir.
class MoonPainter extends CustomPainter {
  MoonPainter({required this.phase, this.scale = 1.0})
      : super(repaint: phase);

  /// Faz kaynağı. `repaint:` olarak verilir → kare başına yalnızca `paint`
  /// çalışır, widget ağacı yeniden KURULMAZ (ambient ile aynı desen).
  final ValueListenable<LaunchPhase> phase;

  /// Çıkış mikroanimasyonunda ay küçülür (1.0 → 0.88).
  final double scale;

  /// Ayın yarıçapı (kısa kenar oranı). 0.155 → 400 px genişlikte ~62 px:
  /// launcher ikonunun ekrandaki algısal boyutuna yakın.
  static const double _radiusFactor = 0.155;

  /// Kenar deformasyonunun azami genliği (R oranı). Bkz. sınıf notu.
  static const double _rimWobble = 0.032;

  /// Gölge dairesinin yarıçapı (R oranı) — marka ikonundan ölçüldü (~0.92).
  static const double _shadowRadius = 0.92;

  /// Hilalin açılma yönü — marka ikonunda sağ-üst.
  static const double _shadowAngle = -math.pi * 0.20;

  /// Yıldızların ay merkezine göre kutupsal konumları: (açı, R katı).
  /// Sabit ve deterministik — parıltı ZAMANLAMASI sesten gelir, konum tasarımdan.
  static const List<List<double>> _starSlots = <List<double>>[
    <double>[-2.55, 2.30],
    <double>[-0.72, 2.05],
    <double>[0.55, 2.65],
    <double>[2.35, 1.95],
    <double>[-1.85, 3.00],
    <double>[1.55, 2.45],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = phase.value;
    final shortSide = math.min(size.width, size.height);
    // Dikeyde tam ortada değil: 0.44 optik merkez (altta içerik nefes alsın).
    final center = Offset(size.width / 2, size.height * 0.44);
    final r = shortSide * _radiusFactor * scale * (1 + 0.05 * p.glow);

    _paintHalo(canvas, center, r, p);
    _paintRipples(canvas, center, r, p);
    _paintCrescent(canvas, center, r, p);
    _paintStars(canvas, center, r, p);
  }

  /// Ayın çevresindeki ışıma — zarfla parlar.
  void _paintHalo(Canvas canvas, Offset center, double r, LaunchPhase p) {
    final radius = r * 3.4;
    final alpha = (0.05 + 0.22 * p.glow).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        // `plus`: ışık gibi toplanır, srcOver gibi altını kesmez (blur'dan ucuz).
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[
            NoctaColors.accentAurora.withValues(alpha: alpha),
            NoctaColors.accentAurora.withValues(alpha: 0),
          ],
          stops: const <double>[0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  /// Dışa açılan halkalar — "dalgalanma"nın taşıyıcısı.
  ///
  /// Üç halka eşit faz aralığıyla; her biri doğarken parlak, uzaklaşırken söner.
  void _paintRipples(Canvas canvas, Offset center, double r, LaunchPhase p) {
    if (p.glow <= 0.01) return;
    const rings = 3;
    const period = 1.9; // sn — bir halkanın doğup sönme süresi
    for (var i = 0; i < rings; i++) {
      final u = ((p.t / period) + i / rings) % 1.0;
      final ring = r * (1.02 + 2.1 * u);
      // (1-u)² sönüm: halka uzaklaştıkça hızla kaybolur, kenarda çizgi bırakmaz.
      final alpha = (0.16 * p.glow * (1 - u) * (1 - u)).clamp(0.0, 1.0);
      if (alpha < 0.004) continue;

      // **Stroke DEĞİL, tüylendirilmiş bant.** İlk sürüm `PaintingStyle.stroke`
      // kullanıyordu; render edilip bakıldığında keskin eş merkezli çemberler
      // "radar hedefi" gibi okunuyordu — suya düşen damla değil. Radyal gradyanla
      // yapılan bant, kenarları yumuşak olduğu için dalga izlenimi veriyor.
      final band = r * (0.35 + 0.35 * u); // uzaklaştıkça yayılır
      final outer = ring + band;
      canvas.drawCircle(
        center,
        outer,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              NoctaColors.accentDeep.withValues(alpha: 0),
              NoctaColors.accentDeep.withValues(alpha: alpha),
              NoctaColors.accentDeep.withValues(alpha: 0),
            ],
            stops: <double>[
              ((ring - band) / outer).clamp(0.0, 1.0),
              (ring / outer).clamp(0.0, 1.0),
              1.0,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: outer)),
      );
    }
  }

  /// Hilalin kendisi: dalgalanan disk EKSİ kayan gölge dairesi.
  ///
  /// `Path.combine(difference, ...)` kullanılıyor çünkü gölgeyi zemin rengiyle
  /// ÜSTÜNE çizmek halonun üstüne de basardı (ayın etrafında koyu bir leke).
  /// Fark alarak hilali GERÇEK bir şekil olarak üretiyoruz.
  void _paintCrescent(Canvas canvas, Offset center, double r, LaunchPhase p) {
    final disc = _wobbledDisc(center, r, p);

    // Gölge uzaklığı zarfla nefes alır: ses yükseldikçe gölge çekilir, hilal
    // kalınlaşır (marka ikonundaki oran 0.78 bu aralığın ortasında).
    final distance = r * (0.66 + 0.20 * p.glow);
    final shadowCenter = center +
        Offset(math.cos(_shadowAngle), math.sin(_shadowAngle)) * distance;
    final shadow = Path()
      ..addOval(Rect.fromCircle(center: shadowCenter, radius: r * _shadowRadius));

    final crescent = Path.combine(PathOperation.difference, disc, shadow);
    final bounds = Rect.fromCircle(center: center, radius: r);

    // Renk: tilt ("gökyüzü açılıyor") parlaklığı sürer → ay yavaşça açılır.
    final bright = Color.lerp(
      NoctaColors.inkSecondary,
      NoctaColors.inkPrimary,
      p.open.clamp(0.0, 1.0),
    )!;
    final tint = Color.lerp(bright, NoctaColors.accentAurora, 0.32)!;
    // Taban 0.45 — ay ilk karede ZATEN ORADA, sonra canlanıyor.
    //
    // **Neden sıfırdan başlamıyor:** native splash ekranda merkezde bir HİLAL
    // gösteriyor (`assets/icon/splash_logo.png`). Flutter ilk karesinde ayı
    // görünmez çizseydi, devralma anında logo "sönüp" yeniden doğardı — tam da
    // önlemek istediğimiz sıçrama. Zarf burada ayı yaratmıyor, UYANDIRIYOR.
    final opacity = (0.45 + 0.55 * p.glow).clamp(0.0, 1.0);

    canvas.drawPath(
      crescent,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            bright.withValues(alpha: opacity),
            tint.withValues(alpha: opacity),
          ],
        ).createShader(bounds),
    );
  }

  /// Kenarı dalgalandırılmış disk.
  ///
  /// r(θ) = R·(1 + w·(0.62·sin(3θ+φ₃) + 0.38·sin(5θ−φ₅))). θ'daki harmonikler
  /// TAM SAYI olmak zorunda: 2π'de değer ve türev aynı döner → yol dikişsiz
  /// kapanır (ambient'teki döngüsellik şartının buradaki karşılığı).
  Path _wobbledDisc(Offset center, double r, LaunchPhase p) {
    final w = _rimWobble * p.glow;
    final path = Path();
    if (w <= 0.0005) {
      path.addOval(Rect.fromCircle(center: center, radius: r));
      return path;
    }
    const segments = 96;
    const twoPi = 2 * math.pi;
    final phi3 = twoPi * p.t / 4.0;
    final phi5 = twoPi * p.t / 2.6;
    for (var i = 0; i <= segments; i++) {
      final theta = twoPi * i / segments;
      final rr = r *
          (1 + w * (0.62 * math.sin(3 * theta + phi3) + 0.38 * math.sin(5 * theta - phi5)));
      final point = center + Offset(math.cos(theta) * rr, math.sin(theta) * rr);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  /// Yıldızlar — **sesin parıltı taneleriyle aynı anda** parlar.
  void _paintStars(Canvas canvas, Offset center, double r, LaunchPhase p) {
    for (var i = 0; i < p.sparkles.length && i < _starSlots.length; i++) {
      final v = p.sparkles[i];
      if (v <= 0.01) continue;
      final slot = _starSlots[i];
      final pos = center + Offset(math.cos(slot[0]), math.sin(slot[0])) * (r * slot[1]);
      // Boyut/parlaklık ilk render'da ÖLÇÜLEREK büyütüldü: 0.055+0.075·v ile
      // yıldızlar 360 px genişlikte ~5 px kalıyor ve gökyüzünde fark edilmiyordu.
      final radius = r * (0.12 + 0.26 * v);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              NoctaColors.inkPrimary.withValues(alpha: v.clamp(0.0, 1.0)),
              NoctaColors.accentAurora.withValues(alpha: 0),
            ],
            // Küçük ve tam opak bir çekirdek + geniş sönüm: "nokta" değil "parıltı".
            stops: const <double>[0.18, 1.0],
          ).createShader(Rect.fromCircle(center: pos, radius: radius)),
      );
    }
  }

  /// Faz `repaint:` üzerinden geliyor; burada yalnızca YAPILANDIRMA farkı bakılır.
  @override
  bool shouldRepaint(MoonPainter old) => old.phase != phase || old.scale != scale;
}
