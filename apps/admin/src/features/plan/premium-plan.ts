/**
 * **Ücretsiz/premium sınırının panel kopyası** (F5).
 *
 * `apps/*` birbirini import EDEMEZ (CLAUDE.md §2) → bu liste mobildeki
 * `features/entitlement/premium_plan.dart` dosyasının zorunlu kopyasıdır.
 * `LAYER_SOURCES` ile aynı desen; oradaki gibi bir drift kapısı
 * (`tooling/check-premium-plan-drift.mjs`) iki tarafı SIRA DAHİL karşılaştırır.
 *
 * ## ⚠️ ARKASI BOŞ
 *
 * Panelde gösterilen bu tablo bugün bir SÖZDÜR, uygulanan bir kural değil:
 * sunucu herkese `plus` döndürüyor (`DevEntitlementService`) ve gerçek IAP en
 * son fazda bağlanacak (docs/10). Sayfa bunu açıkça yazar — panelde "premium"
 * gören bir editörün, kullanıcıların o özelliği göremediğini sanması en pahalı
 * yanlış anlama olurdu.
 */
export const PREMIUM_FEATURES = [
  'fullLibrary',
  'infiniteExtension',
  'offline',
  'smartAlarm',
  'unlimitedMixes',
  'videoExport',
  'weeklyTrends',
] as const;

export type PremiumFeature = (typeof PREMIUM_FEATURES)[number];

/** Deneme süresi (gün) — mobildeki `kTrialDays` ile aynı olmalı. */
export const TRIAL_DAYS = 7;

/** Ücretsiz katmandaki ses sayısı — mobildeki `kFreeLibrarySize`. */
export const FREE_LIBRARY_SIZE = 40;

/** Ücretsiz katmandaki kayıtlı mix sayısı — mobildeki `kFreeMixSlots`. */
export const FREE_MIX_SLOTS = 3;
