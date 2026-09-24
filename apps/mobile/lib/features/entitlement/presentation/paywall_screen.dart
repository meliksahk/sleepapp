import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';

/// Paywall (docs/04 M2 monetizasyon kapısı). Kilitli bir premium özelliğe basınca
/// açılır (route: `/paywall`).
///
/// **GERÇEK SATIN ALMA YOK (CLAUDE.md §6):** IAP en son fazdır; "Premium'a geç" şimdilik
/// yalnızca "çok yakında" der. Satın alma akışı `EntitlementService`'in arkasına
/// sonradan tak-çıkar bağlanır — bu ekran o gün değişmeden kalır, yalnızca CTA gerçek
/// StoreKit çağrısına döner.
///
/// **Viral kancalar FREE kalır (§1.1):** kimlik kartı / gece raporu / mix-to-video
/// paylaşımı premium DEĞİL — cömert free tier. Buradaki premium değer içgörü/ekstra.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoctaSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              NDisplay(
                l10n.paywallTitle,
                key: const Key('paywall-title'),
                size: NoctaFontSize.display,
                height: 1.04,
              ),
              const SizedBox(height: NoctaSpace.s3),
              Text(
                l10n.paywallTagline,
                style: const TextStyle(
                  fontSize: NoctaFontSize.body,
                  height: 1.7,
                  color: NoctaColors.inkSecondary,
                ),
              ),
              const SizedBox(height: NoctaSpace.s6),
              _benefit(context, l10n.paywallBenefitTrends),
              _benefit(context, l10n.paywallBenefitMore),
              const Spacer(),
              NButton(
                key: const Key('paywall-cta'),
                label: l10n.paywallCta,
                expand: true,
                rule: true,
                // Gerçek IAP yok (§6): şimdilik yalnızca bilgilendirir.
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.paywallComingSoon))),
              ),
              const SizedBox(height: NoctaSpace.s2),
              TextButton(
                key: const Key('paywall-later'),
                onPressed: () => context.pop(),
                child: NMono(l10n.paywallLater),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fayda satiri. Elegy'de tik ikonu yok: kizil bir isaret blogu + metin.
  Widget _benefit(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: NoctaSpace.s4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 6),
          color: NoctaColors.accentAurora,
        ),
        const SizedBox(width: NoctaSpace.s4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: NoctaFontSize.body,
              height: 1.6,
              color: NoctaColors.inkPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
