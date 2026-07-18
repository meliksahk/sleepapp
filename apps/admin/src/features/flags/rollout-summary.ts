import { translate, type Locale } from '@/shared/i18n/dictionaries';
import { formatPercent } from '@/shared/i18n/format';
import type { FlagRules } from './types';

/**
 * Bir flag'in HEDEFLEME kurallarını tek satır insan-okunur özete çevirir (docs/03 A4).
 * Bileşenden AYRI saf fonksiyon — testlenebilsin diye. Asıl derdimiz: kapalı bir flag'i
 * "kısmen açık" gibi ya da segment kısıtını GÖRÜNMEZ göstermemek (rollout görünürlüğü).
 *
 * Not: `enabled` durumu ayrı rozette gösterilir; burada yalnızca AÇIKKEN kimin aldığı
 * özetlenir. Kapalı flag için segment kuralları yine de yazılır (editör neyi açacağını
 * görsün) ama "Kapalı" öneki tabloda rozetten bellidir.
 *
 * Yüzde Intl ile biçimlenir: elle `%${n}` yazmak TR'de doğru, EN'de yanlıştı (`25%`).
 */
export function rolloutSummary(locale: Locale, rules: FlagRules): string {
  const parts: string[] = [];

  // Rollout yüzdesi: tanımsız = herkes (100%), tanımlı = kova < yüzde.
  if (rules.rolloutPercentage === undefined) {
    parts.push(translate(locale, 'flags.rolloutAll'));
  } else {
    const pct = Math.max(0, Math.min(100, rules.rolloutPercentage));
    parts.push(
      // fractionDigits=1: rollout ELLE girilen bir değer, %12,5 gerçek veri.
      // Varsayılan 0 kalsaydı panelde %13 görünürdü (ölçülen metriklerden farklı).
      translate(locale, 'flags.rolloutPercent', { percent: formatPercent(locale, pct / 100, 1) }),
    );
  }

  if (rules.platforms && rules.platforms.length > 0) {
    parts.push(
      translate(locale, 'flags.rolloutPlatforms', { platforms: rules.platforms.join(', ') }),
    );
  }
  if (rules.minAppVersion) {
    parts.push(translate(locale, 'flags.rolloutMinVersion', { version: rules.minAppVersion }));
  }

  return parts.join(' · ');
}
