import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../premium_plan.dart';

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
        // Plan karşılaştırması (ücretsiz + 7 premium satır) sabit bir Column'a
        // SIĞMIYOR — testte 307 px taşma olarak ölçüldü. Liste kaydırılır ama
        // KARAR BLOĞU (uyarı + CTA + geri yükleme) altta SABİT kalır: kullanıcı
        // eylemi bulmak için kaydırmak zorunda değil.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NoctaSpace.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              const SizedBox(height: NoctaSpace.s6),
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

              // ── ÜCRETSİZDE NE VAR ── Paywall'ın ilk işi korkutmak değil,
              // neyin ZATEN açık olduğunu söylemek. Cömert free tier ürünün
              // büyüme motoru (bkz. premium_plan.dart).
              NMono(l10n.paywallFreeSection, track: NoctaTrack.wide),
              const SizedBox(height: NoctaSpace.s3),
              _benefit(context, l10n.paywallFreeMixer),
              _benefit(context, l10n.paywallFreeRecordings),
              _benefit(context, l10n.paywallFreeLibrary('$kFreeLibrarySize')),

              const SizedBox(height: NoctaSpace.s5),
              const Divider(color: NoctaColors.lineHairline),
              const SizedBox(height: NoctaSpace.s3),
              NMono(l10n.paywallPremiumSection, track: NoctaTrack.wide),
              const SizedBox(height: NoctaSpace.s3),
              for (final f in PremiumFeature.values)
                _benefit(context, _featureLabel(l10n, f)),

                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NoctaSpace.s5,
                0,
                NoctaSpace.s5,
                NoctaSpace.s5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
              // DÜRÜSTLÜK: ekran gerçek bir satın alma yapmıyor. Kullanıcıya
              // "ücret alınacak" izlenimi vermeden çerçeveyi gösteriyoruz.
              Text(
                l10n.paywallNoChargeYet(kTrialDays),
                key: const Key('paywall-no-charge'),
                style: const TextStyle(
                  fontSize: NoctaFontSize.caption,
                  height: 1.6,
                  color: NoctaColors.inkSecondary,
                ),
              ),
              const SizedBox(height: NoctaSpace.s3),
              NButton(
                key: const Key('paywall-cta'),
                label: l10n.paywallTrialCta(kTrialDays),
                expand: true,
                rule: true,
                // Gerçek IAP yok (§6): şimdilik yalnızca bilgilendirir.
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.paywallComingSoon))),
              ),
              const SizedBox(height: NoctaSpace.s2),
              TextButton(
                key: const Key('paywall-restore'),
                // Satın alma yok → geri yükleme de yok. Düğmeyi GİZLEMİYORUZ
                // (mağaza kılavuzları ister) ama ne yaptığını dürüstçe söylüyor.
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.paywallComingSoon))),
                child: NMono(l10n.paywallRestore),
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
          ],
        ),
      ),
    );
  }

  /// Premium özelliğin kullanıcıya görünen adı. Tablo `premium_plan.dart`'ta;
  /// burada YALNIZCA metne çevriliyor.
  String _featureLabel(AppL10n l10n, PremiumFeature f) => switch (f) {
    PremiumFeature.fullLibrary => l10n.premiumFullLibrary,
    PremiumFeature.infiniteExtension => l10n.premiumInfiniteExtension,
    PremiumFeature.offline => l10n.premiumOffline,
    PremiumFeature.smartAlarm => l10n.premiumSmartAlarm,
    PremiumFeature.unlimitedMixes => l10n.premiumUnlimitedMixes('$kFreeMixSlots'),
    PremiumFeature.videoExport => l10n.premiumVideoExport,
    PremiumFeature.weeklyTrends => l10n.premiumWeeklyTrends,
  };

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
