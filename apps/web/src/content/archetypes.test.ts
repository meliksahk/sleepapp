import { describe, it, expect } from 'vitest';
import {
  ARCHETYPES,
  ARCHETYPES_TR,
  ARCHETYPE_SLUGS,
  getArchetype,
  getArchetypeIn,
} from './archetypes';

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

describe('Türkçe archetype içeriği', () => {
  it('SLUG SETİ EN ile birebir aynı ve AYNI SIRADA (slug çevrilmez)', () => {
    // Slug'lar paylaşım linklerinde ve derin linklerde sabit; TR sayfası aynı slug'ı
    // kullanır. Sapma olursa /tr/a/{slug} 404 verir ve hreflang zinciri kırılır.
    expect(ARCHETYPES_TR.map((a) => a.slug)).toEqual(ARCHETYPES.map((a) => a.slug));
  });

  it('her TR archetype zorunlu alanlara sahip', () => {
    for (const a of ARCHETYPES_TR) {
      expect(a.name).toBeTruthy();
      expect(a.summary.length).toBeGreaterThan(20);
      expect(a.paragraphs.length).toBeGreaterThanOrEqual(2);
      expect(a.soundsThatHelp.length).toBeGreaterThanOrEqual(1);
    }
  });

  it('metinler gerçekten çevrilmiş (EN metnin kopyası değil)', () => {
    for (const [i, tr] of ARCHETYPES_TR.entries()) {
      const en = ARCHETYPES[i]!;
      expect(tr.tagline).not.toBe(en.tagline);
      expect(tr.summary).not.toBe(en.summary);
    }
  });

  it('getArchetypeIn dile göre doğru içeriği verir', () => {
    expect(getArchetypeIn('en', 'deep-ocean')?.name).toBe('Deep Ocean');
    expect(getArchetypeIn('tr', 'deep-ocean')?.name).toBe('Derin Okyanus');
    expect(getArchetypeIn('tr', 'nope')).toBeUndefined();
  });

  it('sağlık iddiası taraması — TR yasak kelime yok (CLAUDE.md §1.1)', () => {
    // Türkçe sondan eklemeli: kök eşleşmesi kullanılır ("iyileştirir", "şifalı" de yakalanır).
    const forbidden = /(?<![\p{L}])(tedavi|terapi|terapötik|klinik|tıbb|hastalık|iyileştir|şifa)/iu;
    for (const a of ARCHETYPES_TR) {
      const text = [a.name, a.tagline, a.summary, ...a.paragraphs, ...a.soundsThatHelp].join(' ');
      expect(text).not.toMatch(forbidden);
    }
  });
});
