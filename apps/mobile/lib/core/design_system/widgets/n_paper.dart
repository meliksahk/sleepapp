import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../generated/nocta_tokens.dart';

/// Kolajın kurucu ögesi: **yırtık kenarlı krem kağıt bloğu**.
///
/// Tasarımda (NOCTA Elegy) içerik iki sınıfa ayrılıyor — gece tuvali (koyu) ve
/// üstüne yapıştırılmış kağıt (krem). Kağıdın kenarı düz değil yırtık; yüzeyinde
/// hafif bir tanecik var. Bu bileşen o yüzeyi tek yerde tanımlar.
///
/// Yırtık kenar **deterministik**: aynı [seed] her zaman aynı kenarı üretir.
/// Rastgele olsaydı her `build` farklı kenar çizerdi (kaydırmada titreşim) ve
/// golden testleri kararsız olurdu.
class NPaper extends StatelessWidget {
  const NPaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NoctaSpace.s5),
    this.color = NoctaColors.bgPaper,
    this.seed = 0,
    this.torn = true,
    this.tilt = 0,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  /// Yırtık kenarın tohumu — aynı tohum aynı kenar.
  final int seed;

  /// `false` → düz dikdörtgen kağıt (liste içi yoğun kullanımda daha sakin).
  final bool torn;

  /// Radyan cinsinden hafif eğim (kolaj hissi). Tasarımda ±0,012 rad (~0,7°).
  final double tilt;

  @override
  Widget build(BuildContext context) {
    Widget surface = Container(
      color: color,
      padding: padding,
      child: child,
    );

    // Tanecik kağıdın ÜSTÜNDE, içeriğin altında değil: kağıt matbaa gibi dursun.
    surface = Stack(
      children: <Widget>[
        surface,
        Positioned.fill(
          child: IgnorePointer(child: NGrain(seed: seed, opacity: 0.06)),
        ),
      ],
    );

    if (torn) {
      surface = ClipPath(clipper: NTornClipper(seed: seed), child: surface);
    }
    if (tilt != 0) {
      surface = Transform.rotate(angle: tilt, child: surface);
    }
    return surface;
  }
}

/// Üst ve alt kenarı yırtık bir dikdörtgen üretir. Yan kenarlar düz kalır —
/// tasarımda da öyle: kağıt yatay yırtılmış, dikey kesilmiş.
class NTornClipper extends CustomClipper<Path> {
  const NTornClipper({this.seed = 0, this.teeth = 11, this.depth = 0.045});

  /// Kenar boyunca yırtık noktası sayısı.
  final int teeth;

  /// Yırtığın derinliği — yüksekliğin oranı.
  final double depth;
  final int seed;

  @override
  Path getClip(Size size) {
    final rnd = math.Random(seed);
    final double bite = size.height * depth;
    final path = Path();

    double jitter() => rnd.nextDouble() * bite;

    path.moveTo(0, jitter());
    for (int i = 1; i <= teeth; i++) {
      path.lineTo(size.width * i / teeth, jitter());
    }
    path.lineTo(size.width, size.height - jitter());
    for (int i = teeth - 1; i >= 0; i--) {
      path.lineTo(size.width * i / teeth, size.height - jitter());
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(NTornClipper oldClipper) =>
      oldClipper.seed != seed || oldClipper.teeth != teeth || oldClipper.depth != depth;
}

/// Tanecik (grain) katmanı — kolajın "basılı" hissi.
///
/// **Bilinçli sadeleştirme:** tasarımda tanecik animasyonlu (`noctaGrain`).
/// Burada STATİK. Gece boyunca ekranda duran bir uygulamada her karede yeniden
/// çizilen tam ekran gürültü pil bütçesini (docs/04 §1.2: ekran kapalı < %4)
/// gereksiz yere yer. Hareket, kolajın anlamını taşıyan öge değil.
class NGrain extends StatelessWidget {
  const NGrain({super.key, this.seed = 0, this.opacity = 0.05, this.density = 900});

  final int seed;
  final double opacity;

  /// Tuval başına nokta sayısı. Yoğunluk arttıkça çizim maliyeti doğrusal artar.
  final int density;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GrainPainter(seed: seed, opacity: opacity, density: density),
        isComplex: true,
        willChange: false,
        size: Size.infinite,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.seed, required this.opacity, required this.density});

  final int seed;
  final double opacity;
  final int density;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rnd = math.Random(seed);
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    for (int i = 0; i < density; i++) {
      final double x = rnd.nextDouble() * size.width;
      final double y = rnd.nextDouble() * size.height;
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.seed != seed || old.opacity != opacity || old.density != density;
}
