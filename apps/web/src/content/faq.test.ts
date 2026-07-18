import { describe, it, expect } from 'vitest';
import { FAQ_ITEMS, FAQ_ITEMS_TR, getFaqItems } from './faq';

describe('FAQ içeriği', () => {
  it('her öğe dolu soru + anlamlı cevap', () => {
    expect(FAQ_ITEMS.length).toBeGreaterThanOrEqual(4);
    for (const item of FAQ_ITEMS) {
      expect(item.question.trim().endsWith('?')).toBe(true);
      expect(item.answer.length).toBeGreaterThan(20);
    }
  });

  it('soru metinleri benzersiz', () => {
    const qs = FAQ_ITEMS.map((i) => i.question);
    expect(new Set(qs).size).toBe(qs.length);
  });

  it('sağlık iddiası taraması — yasak kelime yok (CLAUDE.md §1.1)', () => {
    const forbidden =
      /\b(cure|cures|treat|treats|treatment|therapy|therapeutic|clinically proven|doctor.approved|medical|disease|tedavi)\b/i;
    for (const item of FAQ_ITEMS) {
      expect(`${item.question} ${item.answer}`).not.toMatch(forbidden);
    }
  });
});

describe('Türkçe SSS içeriği', () => {
  it('EN ile aynı sayıda soru, her biri dolu', () => {
    expect(FAQ_ITEMS_TR).toHaveLength(FAQ_ITEMS.length);
    for (const item of FAQ_ITEMS_TR) {
      expect(item.question.trim().endsWith('?')).toBe(true);
      expect(item.answer.length).toBeGreaterThan(20);
    }
  });

  it('getFaqItems dile göre doğru listeyi verir', () => {
    expect(getFaqItems('en')).toBe(FAQ_ITEMS);
    expect(getFaqItems('tr')).toBe(FAQ_ITEMS_TR);
  });

  it('sağlık iddiası taraması — TR yasak kelime yok (CLAUDE.md §1.1)', () => {
    const forbidden = /(?<![\p{L}])(tedavi|terapi|terapötik|klinik|tıbb|hastalık|iyileştir|şifa)/iu;
    for (const item of FAQ_ITEMS_TR) {
      expect(`${item.question} ${item.answer}`).not.toMatch(forbidden);
    }
  });
});
