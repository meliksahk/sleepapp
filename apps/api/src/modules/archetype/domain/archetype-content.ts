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

export function getArchetypeInfo(slug: string): ArchetypeInfo | undefined {
  return ARCHETYPE_INFO.find((a) => a.slug === slug);
}

/** Tüm slug'ların içeriği tanımlı mı? (derleme-zamanı güvence + test). */
export function hasAllArchetypeInfo(): boolean {
  return ARCHETYPES.every((slug) => ARCHETYPE_INFO.some((a) => a.slug === slug));
}
