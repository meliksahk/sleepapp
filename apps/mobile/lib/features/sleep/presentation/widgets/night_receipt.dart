import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// **Gece makbuzu** — Elegy'nin imza bileşeni (docs/06 "Night Receipt").
///
/// Bir gecenin özeti bir rapor ekranı gibi değil, **kağıt bir makbuz** gibi
/// görünür: krem zemin, delikli kenar, noktalı ayraç, mono anahtar → değer
/// satırları, altta italik serif bir cümle. Ekran görüntüsü alınmak için
/// tasarlandı; paylaşım kartıyla aynı anatomiyi kullanır ki iki yüzey
/// birbirinden sapmasın.
class NightReceipt extends StatelessWidget {
  const NightReceipt({
    super.key,
    required this.header,
    required this.date,
    required this.duration,
    required this.rows,
    this.insight,
    this.insightKey,
    this.disclaimer,
    this.scale = 1,
  });

  final String header;
  final String date;

  /// Zaten biçimlenmiş süre ("7 sa 12 dk") — biçim çağıranın işi (i18n).
  final Widget duration;
  final List<NightReceiptRow> rows;
  final String? insight;

  /// İçgörü cümlesi ekran testlerinde anahtarla aranıyor.
  final Key? insightKey;
  final String? disclaimer;

  /// Paylaşım kartı 1080×1920'de aynı anatomiyi büyüterek kullanır.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final String? insight0 = insight;
    final String? disclaimer0 = disclaimer;
    return Stack(
      children: <Widget>[
        Container(
          color: NoctaColors.bgPaper,
          padding: EdgeInsets.symmetric(
            horizontal: NoctaSpace.s6 * scale,
            vertical: NoctaSpace.s8 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Flexible(
                    child: NMono(
                      header,
                      color: NoctaColors.inkOnPaperSoft,
                      track: NoctaTrack.wide * scale,
                      size: NoctaFontSize.micro * scale,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: NoctaSpace.s3),
                  NMono(
                    date,
                    color: NoctaColors.inkOnPaperSoft,
                    track: NoctaTrack.tight * scale,
                    size: NoctaFontSize.micro * scale,
                  ),
                ],
              ),
              SizedBox(height: NoctaSpace.s4 * scale),
              duration,
              SizedBox(height: NoctaSpace.s5 * scale),
              _DottedRule(scale: scale, strong: true),
              for (final row in rows) _ReceiptRow(row: row, scale: scale),
              _DottedRule(scale: scale, strong: true),
              if (insight0 != null) ...<Widget>[
                SizedBox(height: NoctaSpace.s5 * scale),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 26 * scale,
                      height: 34 * scale,
                      margin: EdgeInsets.only(top: 4 * scale),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0B0B),
                        borderRadius: BorderRadius.circular(NoctaRadius.full),
                      ),
                    ),
                    SizedBox(width: NoctaSpace.s4 * scale),
                    Expanded(
                      child: Text(
                        insight0,
                        key: insightKey,
                        style: TextStyle(
                          fontFamily: NoctaFont.display,
                          fontStyle: FontStyle.italic,
                          fontSize: 18 * scale,
                          height: 1.4,
                          color: NoctaColors.inkOnPaper,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (disclaimer0 != null) ...<Widget>[
                SizedBox(height: NoctaSpace.s4 * scale),
                NMono(
                  disclaimer0,
                  // Sağlık iddiası feragati (CLAUDE.md §1.1) makbuzun PARÇASI:
                  // paylaşılan görselde de görünmeli, ekranda kalmamalı.
                  color: NoctaColors.inkOnPaperSoft,
                  size: NoctaFontSize.micro * scale,
                  track: NoctaTrack.tight * scale,
                  height: 1.6,
                ),
              ],
            ],
          ),
        ),
        // Delikli kenar: makbuzun koparıldığı yer. Delikler zeminin rengiyle
        // çizilir — kağıdın DELİNMİŞ olduğu izlenimi böyle doğar.
        Positioned(
          top: -7 * scale,
          left: 0,
          right: 0,
          child: _Perforation(scale: scale),
        ),
        Positioned(
          bottom: -7 * scale,
          left: 0,
          right: 0,
          child: _Perforation(scale: scale),
        ),
      ],
    );
  }
}

/// Makbuz satırı: anahtar … değer.
class NightReceiptRow {
  const NightReceiptRow({
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.row, required this.scale});

  final NightReceiptRow row;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: NoctaSpace.s2 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: NMono(
              row.label,
              color: NoctaColors.inkOnPaperSoft,
              size: NoctaFontSize.micro * scale,
              track: NoctaTrack.tight * scale,
              height: 1.2,
              maxLines: 2,
            ),
          ),
          SizedBox(width: NoctaSpace.s2 * scale),
          Expanded(child: _DottedRule(scale: scale)),
          SizedBox(width: NoctaSpace.s2 * scale),
          Text(
            row.value,
            key: row.valueKey,
            style: TextStyle(
              fontFamily: NoctaFont.mono,
              fontSize: NoctaFontSize.caption * scale,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: NoctaColors.inkOnPaper,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Noktalı ayraç — `Divider` düz çizgi çiziyor; makbuzda kesik çizgi şart.
class _DottedRule extends StatelessWidget {
  const _DottedRule({required this.scale, this.strong = false});

  final double scale;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: strong ? NoctaSpace.s3 * scale : 1 * scale,
      child: Center(
        child: CustomPaint(
          size: Size(double.infinity, 1 * scale),
          painter: _DottedPainter(
            color:
                (strong ? NoctaColors.inkOnPaper : NoctaColors.inkOnPaperSoft)
                    .withValues(alpha: strong ? 0.35 : 0.5),
            dash: (strong ? 4 : 1) * scale,
            gap: (strong ? 5 : 4) * scale,
            thickness: 1 * scale,
          ),
        ),
      ),
    );
  }
}

class _DottedPainter extends CustomPainter {
  const _DottedPainter({
    required this.color,
    required this.dash,
    required this.gap,
    required this.thickness,
  });

  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedPainter old) =>
      old.color != color || old.dash != dash || old.gap != gap;
}

class _Perforation extends StatelessWidget {
  const _Perforation({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final double d = 13 * scale;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int count =
              ((constraints.maxWidth - 12 * scale) / (d + 8 * scale))
                  .floor()
                  .clamp(4, 24);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 6 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List<Widget>.generate(
                count,
                (_) => Container(
                  width: d,
                  height: d,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: NoctaColors.bgBase,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
