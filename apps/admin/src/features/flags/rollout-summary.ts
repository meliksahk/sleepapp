import type { FlagRules } from './types';

/**
 * Bir flag'in HEDEFLEME kurallarını tek satır insan-okunur özete çevirir (docs/03 A4).
 * Bileşenden AYRI saf fonksiyon — testlenebilsin diye. Asıl derdimiz: kapalı bir flag'i
 * "kısmen açık" gibi ya da segment kısıtını GÖRÜNMEZ göstermemek (rollout görünürlüğü).
 *
 * Not: `enabled` durumu ayrı rozette gösterilir; burada yalnızca AÇIKKEN kimin aldığı
 * özetlenir. Kapalı flag için segment kuralları yine de yazılır (editör neyi açacağını
 * görsün) ama "Kapalı" öneki tabloda rozetten bellidir.
 */
export function rolloutSummary(rules: FlagRules): string {
  const parts: string[] = [];

  // Rollout yüzdesi: tanımsız = herkes (100%), tanımlı = kova < yüzde.
  if (rules.rolloutPercentage === undefined) {
    parts.push('tüm kullanıcılar');
  } else {
    const pct = Math.max(0, Math.min(100, rules.rolloutPercentage));
    parts.push(`%${pct} kullanıcı`);
  }

  if (rules.platforms && rules.platforms.length > 0) {
    parts.push(`yalnızca ${rules.platforms.join(', ')}`);
  }
  if (rules.minAppVersion) {
    parts.push(`sürüm ≥ ${rules.minAppVersion}`);
  }

  return parts.join(' · ');
}
