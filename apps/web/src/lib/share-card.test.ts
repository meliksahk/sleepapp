import { describe, it, expect } from 'vitest';
import { cardFileName, wrapText, CARD_WIDTH, CARD_HEIGHT } from './share-card';

// Sahte ölçü: her karakter 10px (deterministik, canvas'sız).
const measure = (s: string) => s.length * 10;

describe('cardFileName', () => {
  it("slug'dan marka önekli png adı üretir", () => {
    expect(cardFileName('deep-ocean')).toBe('nocta-deep-ocean.png');
  });

  it('güvensiz karakterleri temizler (dosya adı enjeksiyonu yok)', () => {
    expect(cardFileName('../etc/passwd')).toBe('nocta-etcpasswd.png');
  });

  it("boş slug'da güvenli varsayılan", () => {
    expect(cardFileName('')).toBe('nocta-card.png');
  });
});

describe('wrapText', () => {
  it('sığan metin tek satır', () => {
    expect(wrapText('short', 100, measure)).toEqual(['short']);
  });

  it('uzun metni genişliğe göre böler', () => {
    // "aaa bbb ccc" her kelime 30px; maxWidth 70 → "aaa bbb"(70) sığar, "ccc" yeni satır.
    expect(wrapText('aaa bbb ccc', 70, measure)).toEqual(['aaa bbb', 'ccc']);
  });

  it("maxWidth'i aşan tek kelime kendi satırında kalır (kart bozulmaz)", () => {
    expect(wrapText('supercalifragilistic', 50, measure)).toEqual(['supercalifragilistic']);
  });

  it('boş metin boş dizi', () => {
    expect(wrapText('   ', 100, measure)).toEqual([]);
  });
});

describe('kart boyutu 9:16 (viral format)', () => {
  it('1080×1920', () => {
    expect(CARD_WIDTH / CARD_HEIGHT).toBeCloseTo(9 / 16, 5);
  });
});
