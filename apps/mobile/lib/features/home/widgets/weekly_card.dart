import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/content_models.dart';

/// Haftalık yayın kartı — içerik tazeliği sinyali (yalnızca yayın varken).
///
/// Keşif rafının altında durur: bilgi yüzeyi, çağrı değil. Sağdaki chevron
/// "buranın bir devamı var" der; eskiden kart tıklanabilir olduğunu belli etmiyordu.
class WeeklyCard extends StatelessWidget {
  const WeeklyCard({super.key, required this.release});

  final WeeklyRelease release;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final count = release.soundscapes.length;
    // Elegy: haftanin tarifi KREM KAGIT uzerinde duruyor — ekranin geri
    // kalanindan doku farkiyla ayrilir, ikinci bir dolu kutuyla degil.
    return InkWell(
      key: const Key('weekly-card'),
      onTap: () => context.push('/library'),
      child: NPaper(
        seed: 12,
        padding: const EdgeInsets.all(NoctaSpace.s5),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  NMono(
                    l10n.homeWeeklyLabel,
                    color: NoctaColors.inkOnPaperSoft,
                    track: NoctaTrack.wide,
                  ),
                  const SizedBox(height: NoctaSpace.s3),
                  NDisplay(
                    release.notes ?? l10n.homeWeeklyCount(count),
                    key: const Key('weekly-note'),
                    size: NoctaFontSize.h2,
                    color: NoctaColors.inkOnPaper,
                  ),
                ],
              ),
            ),
            const SizedBox(width: NoctaSpace.s3),
            Container(width: 24, height: 1, color: NoctaColors.inkOnPaper),
          ],
        ),
      ),
    );
  }
}
