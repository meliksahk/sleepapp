import { DEFAULT_LOCALE, type Locale } from '../../../shared/locale';
import { ARCHETYPES, type ArchetypeSlug } from './archetype';

/**
 * Archetype tanıtım içeriği — API'nin tek kaynağı (mobil + paylaşım kartı okur).
 * SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): "relaxation & sleep ritual" dili; cure/
 * treat/therapy vb. yok. (Web SSG kendi kopyasını tutar; ileride tek kaynağa birleşir.)
 */
export interface ArchetypeInfo {
  readonly slug: ArchetypeSlug;
  readonly name: string;
  readonly tagline: string;
  readonly summary: string;
}

export const ARCHETYPE_INFO: readonly ArchetypeInfo[] = [
  {
    slug: 'deep-ocean',
    name: 'Deep Ocean',
    tagline: 'You sink into stillness the moment your head hits the pillow.',
    summary: 'You drop into deep, quiet rest quickly and rarely stir before morning.',
  },
  {
    slug: 'overthinker',
    name: '3AM Overthinker',
    tagline: 'Your body is tired, but your mind is still writing tomorrow’s list.',
    summary: 'You lie awake replaying the day; a gentle, masking soundscape quiets the chatter.',
  },
  {
    slug: 'delta-drifter',
    name: 'Delta Drifter',
    tagline: 'You float through long, vivid, half-dream nights.',
    summary: 'You sleep long and dream vividly; a steady soundscape keeps the drift smooth.',
  },
  {
    slug: 'dawn-chaser',
    name: 'Dawn Chaser',
    tagline: 'You are wired to rise with the first light.',
    summary: 'You wake early and bright; a calm wind-down ritual protects your evening hours.',
  },
];

/**
 * Türkçe tanıtım içeriği. **İsimler ÇEVRİLMEZ** — "Deep Ocean" bir marka/kimlik
 * etiketidir ve paylaşım kartında, `/a/{slug}` linkinde, sohbetlerde aynı kalmalı;
 * çevirmek viral kancanın tanınırlığını böler. Yalnızca ANLATIM çevrilir.
 *
 * SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): "rahatlama ve uyku ritüeli" dili.
 */
const ARCHETYPE_INFO_TR: Readonly<Record<ArchetypeSlug, Omit<ArchetypeInfo, 'slug' | 'name'>>> = {
  'deep-ocean': {
    tagline: 'Başını yastığa koyduğun an durulup dibe çökersin.',
    summary: 'Hızla derin ve sessiz bir dinlenmeye geçer, sabaha kadar pek kıpırdamazsın.',
  },
  overthinker: {
    tagline: 'Bedenin yorgun, ama zihnin hâlâ yarının listesini yazıyor.',
    summary:
      'Günü baştan oynatarak uyanık yatarsın; yumuşak, örtücü bir ses dokusu bu gürültüyü susturur.',
  },
  'delta-drifter': {
    tagline: 'Uzun, canlı, yarı rüya gecelerde süzülürsün.',
    summary:
      'Uzun uyur, canlı rüyalar görürsün; istikrarlı bir ses dokusu bu akışı pürüzsüz tutar.',
  },
  'dawn-chaser': {
    tagline: 'İlk ışıkla kalkmaya programlısın.',
    summary: 'Erken ve diri uyanırsın; sakin bir yavaşlama ritüeli akşam saatlerini korur.',
  },
};

/**
 * Tanıtım içeriğini verilen dilde döner. Çevirisi olmayan dil → İngilizce (sessiz
 * düşüş: eksik çeviri yüzünden sonuç ekranı BOŞ kalmamalı).
 */
export function getArchetypeInfo(
  slug: string,
  locale: Locale = DEFAULT_LOCALE,
): ArchetypeInfo | undefined {
  const base = ARCHETYPE_INFO.find((a) => a.slug === slug);
  if (!base || locale === DEFAULT_LOCALE) return base;
  const tr = ARCHETYPE_INFO_TR[base.slug];
  return tr ? { ...base, ...tr } : base;
}

/** Tüm arketiplerin içeriği, verilen dilde. */
export function listArchetypeInfo(locale: Locale = DEFAULT_LOCALE): readonly ArchetypeInfo[] {
  return ARCHETYPE_INFO.map((a) => getArchetypeInfo(a.slug, locale) ?? a);
}

/** Tüm slug'ların içeriği tanımlı mı? (derleme-zamanı güvence + test). */
export function hasAllArchetypeInfo(): boolean {
  return ARCHETYPES.every((slug) => ARCHETYPE_INFO.some((a) => a.slug === slug));
}
