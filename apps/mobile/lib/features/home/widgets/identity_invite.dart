import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../archetype/archetype_gradient.dart';

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
    return Container(
      decoration: BoxDecoration(
        gradient: archetypeGradientForSlug(null), // nötr varsayılan gradyan
        borderRadius: BorderRadius.circular(NoctaRadius.card),
      ),
      child: Container(
        decoration: BoxDecoration(
          // Daha güçlü örtü → solgun/"henüz senin değil" hissi.
          color: NoctaColors.bgBase.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(NoctaRadius.card),
          border: Border.all(color: NoctaColors.inkPrimary.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.all(NoctaSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.homeTagline,
              style: TextStyle(
                fontSize: NoctaFontSize.h2,
                color: NoctaColors.inkPrimary,
              ),
            ),
            const SizedBox(height: NoctaSpace.s2),
            Text(
              l10n.homeIdentityInviteBody,
              style: TextStyle(
                fontSize: NoctaFontSize.caption,
                color: NoctaColors.inkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: NoctaSpace.s4),
            NButton(
              key: const Key('archetype-cta'),
              label: l10n.homeFindIdentity,
              onPressed: () => context.push('/archetype'),
            ),
          ],
        ),
      ),
    );
  }
}
