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
    return NCard(
      padding: const EdgeInsets.symmetric(
        horizontal: NoctaSpace.s4,
        vertical: NoctaSpace.s3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$current',
                  key: const Key('streak-current'),
                  style: TextStyle(
                    fontSize: NoctaFontSize.h1,
                    fontWeight: FontWeight.w600,
                    color: NoctaColors.accentDawn,
                  ),
                ),
                const SizedBox(width: NoctaSpace.s2),
                Flexible(
                  child: Text(
                    l10n.homeStreakLabel(current),
                    style: TextStyle(
                      fontSize: NoctaFontSize.caption,
                      color: NoctaColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showBest)
            Text(
              l10n.homeStreakBest(longest),
              key: const Key('streak-best'),
              style: TextStyle(
                fontSize: NoctaFontSize.micro,
                color: NoctaColors.inkFaint,
              ),
            ),
        ],
      ),
    );
  }
}
