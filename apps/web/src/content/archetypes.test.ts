import { describe, it, expect } from 'vitest';
import { ARCHETYPES, ARCHETYPE_SLUGS, getArchetype } from './archetypes';

describe('archetype content', () => {
  it('4 archetype, benzersiz slug', () => {
    expect(ARCHETYPES).toHaveLength(4);
    expect(new Set(ARCHETYPE_SLUGS).size).toBe(4);
  });

  it('getArchetype bilinen/bilinmeyen slug', () => {
    expect(getArchetype('overthinker')?.name).toBe('3AM Overthinker');
    expect(getArchetype('nope')).toBeUndefined();
  });

  it('her archetype zorunlu alanlara sahip', () => {
    for (const a of ARCHETYPES) {
      expect(a.name).toBeTruthy();
      expect(a.summary.length).toBeGreaterThan(20);
      expect(a.paragraphs.length).toBeGreaterThanOrEqual(2);
      expect(a.soundsThatHelp.length).toBeGreaterThanOrEqual(1);
    }
  });

  it('sağlık iddiası taraması — yasak kelime yok (CLAUDE.md §1.1)', () => {
    const forbidden =
      /\b(cure|cures|treat|treats|treatment|therapy|therapeutic|clinically proven|doctor.approved|tedavi)\b/i;
    for (const a of ARCHETYPES) {
      const text = [a.name, a.tagline, a.summary, ...a.paragraphs, ...a.soundsThatHelp].join(' ');
      expect(text).not.toMatch(forbidden);
    }
  });
});
