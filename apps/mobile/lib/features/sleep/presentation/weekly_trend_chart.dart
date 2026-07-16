import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../sleep_models.dart';

/// Son 7 gecenin uyku süresi mini bar grafiği — saf Flutter (harici grafik
/// kütüphanesi yok, maliyet disiplini). Çubuk yüksekliği o gecenin süresiyle
/// orantılı; en yüksek gece tam yükseklik, veri olmayan gece ince taban çizgisi.
class WeeklyTrendChart extends StatelessWidget {
  const WeeklyTrendChart({super.key, required this.trend, this.height = 64});

  final WeeklyTrend trend;
  final double height;

  static const double _barWidth = 12;
  static const double _minBar = 3; // 0 dk / taban çizgisi için görünür kütük

  @override
  Widget build(BuildContext context) {
    final maxDuration = trend.nights.fold<int>(
      0,
      (m, n) => n.durationMinutes > m ? n.durationMinutes : m,
    );

    return SizedBox(
      key: const Key('weekly-trend-chart'),
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < trend.nights.length; i++)
            _bar(trend.nights[i], maxDuration, i),
        ],
      ),
    );
  }

  Widget _bar(TrendNight night, int maxDuration, int index) {
    // Oran → yükseklik. maxDuration 0 ise (hepsi boş) tüm çubuklar taban.
    final ratio = maxDuration == 0 ? 0.0 : night.durationMinutes / maxDuration;
    final barHeight = _minBar + (height - _minBar) * ratio;
    final hasData = night.durationMinutes > 0;
    return Container(
      key: Key('trend-bar-$index'),
      width: _barWidth,
      height: barHeight,
      decoration: BoxDecoration(
        color: hasData ? NoctaColors.accentAurora : NoctaColors.inkFaint,
        borderRadius: BorderRadius.circular(NoctaSpace.s1),
      ),
    );
  }
}
