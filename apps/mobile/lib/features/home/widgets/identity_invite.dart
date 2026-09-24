import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Kimlik daveti — testi henüz çözmemiş kullanıcı için.
///
/// **Neden aynı gradyan ama SOLGUN:** hero ile davet aynı görsel dili konuşur; fark
/// doygunluktadır. "Henüz senin değil / artık senin" ayrımını ek metin olmadan anlatır.
///
/// **Neden yükleme/hata durumunda da bu gösterilir:** eskiden kimlik bloğu
/// yükleme/hatada tamamen gizleniyordu — sunucu yokken (bugünkü gerçek durum) ekranda
/// koca bir boşluk kalıyordu. Davet, ekranı ASLA boş bırakmaz ve `archetype-cta`'yı
/// her durumda tam 1 tutar (testler bunu sabitliyor).
class IdentityInvite extends StatelessWidget {
  const IdentityInvite({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Elegy: davet de kutu degil. Ayni organik leke, ama SOLGUN ve BOS
    // cerceveli — "henuz senin degil" ayrimi doygunlukla anlatiliyor.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NoctaRadius.full),
                border: Border.all(color: NoctaColors.lineStrong),
              ),
            ),
            const SizedBox(width: NoctaSpace.s4),
            Expanded(child: NDisplay(l10n.homeTagline, size: NoctaFontSize.h2)),
          ],
        ),
        const SizedBox(height: NoctaSpace.s3),
        Text(
          l10n.homeIdentityInviteBody,
          style: const TextStyle(
            fontSize: NoctaFontSize.caption,
            color: NoctaColors.inkSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: NoctaSpace.s4),
        NButton(
          key: const Key('archetype-cta'),
          label: l10n.homeFindIdentity,
          expand: true,
          rule: true,
          onPressed: () => context.push('/archetype'),
        ),
      ],
    );
  }
}
