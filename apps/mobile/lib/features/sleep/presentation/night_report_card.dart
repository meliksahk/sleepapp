import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/media/card_renderer.dart';

/// Paylaşılabilir gece raporu — **viral kanca #2** (docs/04 §119).
///
/// "Gece makbuzu" estetiği: dar, tek sütun, hizalı satırlar, üstte ve altta tırtıklı
/// kenar. Makbuz metaforu bilinçli — bir gece "harcanmış" bir şeydir ve makbuz,
/// sağlık raporundan farklı olarak **iddia taşımaz**, yalnızca kayıt tutar.
/// CLAUDE.md §1.1: sağlık iddiası yasak; makbuz tam da bunun görsel karşılığı.
///
/// Ekranda gösterilmek için değil, **görsele çevrilmek** için çizilir
/// (bkz. `renderWidgetToPng` — kart hiçbir zaman ağaçta olmaz).
class NightReportCard extends StatelessWidget {
  const NightReportCard({
    super.key,
    required this.nightDate,
    required this.durationMinutes,
    required this.soundEvents,
    required this.calmScore,
    required this.streak,
    required this.archetypeName,
    required this.gradient,
    required this.labels,
  });

  final String nightDate;
  final int durationMinutes;

  /// **`movementEvents` BİLEREK YOK.** Ölçmüyoruz (docs/04 §120 fixture'ları yok,
  /// bkz. `SleepRecorder`) ve her zaman 0 dönüyor. "Movement: 0" göstermek,
  /// ölçmediğimiz bir şeyi ölçmüş gibi sunmaktır — sıfır bile bir iddiadır.
  final int soundEvents;

  final int calmScore;
  final int streak;
  final String? archetypeName;
  final LinearGradient gradient;

  /// i18n metinleri — `core`/kart l10n'a bağlı olmasın diye dışarıdan gelir.
  final NightReportCardLabels labels;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      // Sistem yazı boyutu paylaşılan artefaktı bozmasın (kimlik kartıyla aynı ilke).
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: shareCardSize.width,
          height: shareCardSize.height,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
            child: Center(
              child: Container(
                width: 820,
                padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 88),
                decoration: BoxDecoration(
                  color: NoctaColors.bgBase.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      labels.header.toUpperCase(),
                      key: const Key('report-card-header'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        letterSpacing: 8,
                        color: NoctaColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      nightDate,
                      key: const Key('report-card-date'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, color: NoctaColors.inkFaint),
                    ),
                    const SizedBox(height: 56),

                    // Süre: makbuzun "tutar"ı — en büyük satır.
                    Text(
                      labels.duration,
                      key: const Key('report-card-duration'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 132,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        color: NoctaColors.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 56),
                    _rule(),
                    _row(labels.calmLabel, '$calmScore/100', keyName: 'report-card-calm'),
                    _rule(),
                    // D-10: "Sound events" DEĞİL — ölçtüğümüz şey "yüksek anlar".
                    _row(labels.loudLabel, '$soundEvents', keyName: 'report-card-loud'),
                    _rule(),
                    if (streak > 0) ...[
                      _row(labels.streakLabel, '$streak', keyName: 'report-card-streak'),
                      _rule(),
                    ],
                    if (archetypeName != null) ...[
                      _row(labels.identityLabel, archetypeName!),
                      _rule(),
                    ],

                    const SizedBox(height: 40),
                    // SAĞLIK İDDİASI DEĞİL (CLAUDE.md §1.1). Kart paylaşılıyor:
                    // uyarı kartın ÜSTÜNDE olmalı, uygulamanın içinde kalmamalı.
                    Text(
                      labels.disclaimer,
                      key: const Key('report-card-disclaimer'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.4,
                        color: NoctaColors.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'NOCTA',
                      key: const Key('report-card-wordmark'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        letterSpacing: 10,
                        color: NoctaColors.inkPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rule() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(height: 1, color: NoctaColors.inkFaint.withValues(alpha: 0.3)),
      );

  /// Makbuz satırı: solda etiket, sağda değer.
  ///
  /// **Değer `Flexible` + `ellipsis`:** uzun bir kimlik adı ("The Extremely
  /// Overthinking Ruminator") satırı 820 piksel taşırıyordu — kart bozuk paylaşılırdı.
  /// Etiket sabit kalır (kısa ve bizim yazdığımız), taşan şey daima değer olur.
  Widget _row(String label, String value, {String? keyName}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 34, color: NoctaColors.inkSecondary),
            ),
            const SizedBox(width: 24),
            Flexible(
              child: Text(
                value,
                key: keyName == null ? null : Key(keyName),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: NoctaColors.inkPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Kartın metinleri — çağıran (l10n'u olan ekran) doldurur.
class NightReportCardLabels {
  const NightReportCardLabels({
    required this.header,
    required this.duration,
    required this.calmLabel,
    required this.loudLabel,
    required this.streakLabel,
    required this.identityLabel,
    required this.disclaimer,
  });

  final String header;

  /// Biçimlendirilmiş süre ("7h 12m") — biçim yerele bağlı, kart çevirmez.
  final String duration;

  final String calmLabel;

  /// D-10: "hareket/ses" ayrımı doğrulanmadı; ölçtüğümüz şey "yüksek anlar".
  final String loudLabel;

  final String streakLabel;
  final String identityLabel;

  /// Sağlık iddiası olmadığını söyleyen satır (CLAUDE.md §1.1).
  final String disclaimer;
}
