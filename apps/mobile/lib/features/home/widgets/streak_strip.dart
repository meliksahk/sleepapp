import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Alışkanlık serisi — dikey kart yerine YATAY şerit.
///
/// Neden şerit: seri bir *bilgi yüzeyi*, bir eylem değil. Dikey kartta ekranın
/// ortasında büyük bir blok kaplıyor ve birincil eylemle (gece ritüelini başlat)
/// dikkat yarışına giriyordu. Şerit aynı bilgiyi verir, hiyerarşide geri çekilir.
///
/// Sayı `accentDawn` (sabah/uyanış rengi) ile ayrışır — boyutla değil renkle,
/// çünkü ekranın tek `display` tipografisi ritüel başlığına ait.
class StreakStrip extends StatelessWidget {
  const StreakStrip({super.key, required this.current, required this.longest});

  final int current;
  final int longest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Kişisel rekor yalnızca güncel seriden büyükse anlamlı (aksi halde tekrar bilgi).
    final showBest = longest > current;
    // Elegy: seri bir kart degil, son 7 gecenin YIRTIK CUBUK seridi.
    // Kutu kaldirildi; sayi serif oldu, aciklama mono tek satira dustu.
    const int window = 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 30,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < window; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ClipPath(
                      clipper: const NTornClipper(
                        seed: 3,
                        teeth: 3,
                        depth: 0.12,
                      ),
                      child: Container(
                        // Son `current` gece dolu; oncesi sonuk. Yukseklik de
                        // degisiyor: ayrim yalniz renkte kalmasin.
                        height: i >= window - current ? 30 : 12,
                        color: i >= window - current
                            ? NoctaColors.accentDawn
                            : NoctaColors.lineSoft,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: NoctaSpace.s3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  // Sayı AYRI bir öge: serif ve iri. Cümlenin içine gömülseydi
                  // hem tasarımın "iri rakam" jesti kaybolurdu hem de sayıyı
                  // tek başına arayan test (find.text('5')) sessizce kırılırdı.
                  NDisplay(
                    '$current',
                    key: const Key('streak-current'),
                    size: NoctaFontSize.h2,
                    color: NoctaColors.accentDawn,
                  ),
                  const SizedBox(width: NoctaSpace.s2),
                  Flexible(
                    child: NMono(
                      l10n.homeStreakLabel(current),
                      color: NoctaColors.inkSecondary,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (showBest) ...<Widget>[
              const SizedBox(width: NoctaSpace.s3),
              NMono(
                l10n.homeStreakBest(longest),
                key: const Key('streak-best'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
