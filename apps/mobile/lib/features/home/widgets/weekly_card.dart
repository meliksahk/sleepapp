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
    return InkWell(
      key: const Key('weekly-card'),
      borderRadius: BorderRadius.circular(NoctaRadius.card),
      onTap: () => context.push('/library'),
      child: NCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.homeWeeklyLabel,
                    style: TextStyle(
                      fontSize: NoctaFontSize.micro,
                      letterSpacing: 1.2,
                      color: NoctaColors.accentAurora,
                    ),
                  ),
                  const SizedBox(height: NoctaSpace.s2),
                  Text(
                    release.notes ?? l10n.homeWeeklyCount(count),
                    key: const Key('weekly-note'),
                    style: TextStyle(
                      fontSize: NoctaFontSize.body,
                      color: NoctaColors.inkPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: NoctaColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
