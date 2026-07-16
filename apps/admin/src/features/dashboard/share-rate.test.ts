import { describe, it, expect } from 'vitest';
import { shareRateLabel, shareRateHint } from './share-rate';

describe('shareRateLabel', () => {
  it('ÇEKİRDEK: null → "—", "%0" DEĞİL', () => {
    // "%0" = "kimse paylaşmıyor". Kimse test bile yapmamışken bu YANLIŞ bir ifade;
    // insan ona bakıp "viral kanca çalışmıyor" diye karar verir.
    expect(shareRateLabel(null)).toBe('—');
  });

  it('gerçek sıfır ile tanımsız AYRILIR', () => {
    expect(shareRateLabel(0)).toBe('%0'); // test yapan var, paylaşan yok
    expect(shareRateLabel(null)).toBe('—'); // test yapan yok
  });

  it('oran yüzdeye çevrilir ve yuvarlanır', () => {
    expect(shareRateLabel(0.25)).toBe('%25');
    expect(shareRateLabel(1)).toBe('%100');
    expect(shareRateLabel(0.3333333)).toBe('%33');
  });
});

describe('shareRateHint', () => {
  it('ham sayıları gösterir — oran tek başına yanıltıcıdır (1/1 = %100)', () => {
    expect(shareRateHint(1, 1)).toBe('1/1 kişi');
    expect(shareRateHint(120, 30)).toBe('30/120 kişi');
  });

  it('hiç test yoksa sebebini söyler', () => {
    expect(shareRateHint(0, 0)).toBe('henüz test tamamlanmadı');
  });
});
