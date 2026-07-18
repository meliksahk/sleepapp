import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../archetype/archetype_gradient.dart';

/// Kullanıcının uyku kimliği — ekranın TEK doygun gradyanı.
///
/// **Neden gradyan hero:** arketip markanın kalbi ve viral kancası. Düz bir kartta
/// "Deep Ocean" yazması ile kullanıcının KENDİ arketip gradyanının ekranda yer
/// kaplaması aynı şey değil; gradyan "bu senin" der. Gradyan tek kaynaktan gelir
/// (`archetypeGradientForSlug`, #178) — bilinmeyen slug'da nötr varsayılana düşer.
///
/// **Scrim (bgBase @ .28):** gradyanın açık uçlarında (dawn-chaser/delta-drifter)
/// beyaz metin kontrastı düşer. Koyu bir örtü kontrastı geri kazandırır.
/// ⚠️ Oran ölçülmedi — gerçek cihazda karanlık odada kontrol edilmeli.
class IdentityHero extends StatelessWidget {
  const IdentityHero({
    super.key,
    required this.slug,
    required this.name,
    required this.tagline,
    required this.historyCount,
  });

  final String slug;
  final String name;
  final String? tagline;

  /// Kimlik geçmişi bağlantısı YALNIZCA birden fazla sonuç varken anlamlı.
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return InkWell(
      key: const Key('identity-card'),
      borderRadius: BorderRadius.circular(NoctaRadius.card),
      onTap: () => context.push('/identity/$slug'),
      child: Container(
        decoration: BoxDecoration(
          gradient: archetypeGradientForSlug(slug),
          borderRadius: BorderRadius.circular(NoctaRadius.card),
        ),
        child: Container(
          decoration: BoxDecoration(
            // Kontrast örtüsü — açık gradyan uçlarında metni okunur tutar.
            color: NoctaColors.bgBase.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(NoctaRadius.card),
          ),
          padding: const EdgeInsets.all(NoctaSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.homeIdentityCardLabel,
                style: TextStyle(
                  fontSize: NoctaFontSize.micro,
                  letterSpacing: 1.2,
                  color: NoctaColors.inkPrimary.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: NoctaSpace.s2),
              Text(
                name,
                key: const Key('identity-name'),
                style: TextStyle(
                  fontSize: NoctaFontSize.h2,
                  fontWeight: FontWeight.w600,
                  color: NoctaColors.inkPrimary,
                ),
              ),
              if (tagline != null && tagline!.isNotEmpty) ...<Widget>[
                const SizedBox(height: NoctaSpace.s1),
                Text(
                  tagline!,
                  style: TextStyle(
                    fontSize: NoctaFontSize.caption,
                    color: NoctaColors.inkPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: NoctaSpace.s3),
              Divider(color: NoctaColors.inkPrimary.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: NoctaSpace.s2),
              // ALT ALTA, yan yana DEĞİL: uzun geçmiş linki ("2 identities over time")
              // + buton aynı satırda 167px taşıyordu (testte yakalandı). Dikey dizilim
              // taşmayı yapısal olarak imkânsız kılar ve TR'nin daha uzun metinlerinde
              // de güvenlidir.
              if (historyCount >= 2)
                InkWell(
                  key: const Key('identity-history-link'),
                  onTap: () => context.push('/identity/history'),
                  child: Padding(
                    // Dokunma hedefi ≥44px (CLAUDE.md §7) — eski düz Text ihlaldi.
                    padding: const EdgeInsets.symmetric(vertical: NoctaSpace.s3),
                    child: Text(
                      l10n.homeIdentityHistoryLink(historyCount),
                      style: TextStyle(
                        fontSize: NoctaFontSize.caption,
                        color: NoctaColors.inkPrimary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: NoctaSpace.s2),
              Align(
                alignment: Alignment.centerLeft,
                child: NButton(
                  key: const Key('archetype-cta'),
                  label: l10n.homeRetakeTest,
                  variant: NButtonVariant.ghost,
                  onPressed: () => context.push('/archetype'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
