import { describe, it, expect } from 'vitest';
import { shareRateLabel, shareRateHint } from './share-rate';

describe('shareRateLabel', () => {
  it('ÇEKİRDEK: null → "—", "%0" DEĞİL', () => {
    // "%0" = "kimse paylaşmıyor". Kimse test bile yapmamışken bu YANLIŞ bir ifade;
    // insan ona bakıp "viral kanca çalışmıyor" diye karar verir.
    expect(shareRateLabel('tr', null)).toBe('—');
  });

  it('gerçek sıfır ile tanımsız AYRILIR', () => {
    expect(shareRateLabel('tr', 0)).toBe('%0'); // test yapan var, paylaşan yok
    expect(shareRateLabel('tr', null)).toBe('—'); // test yapan yok
  });

  it('oran yüzdeye çevrilir ve yuvarlanır', () => {
    expect(shareRateLabel('tr', 0.25)).toBe('%25');
    expect(shareRateLabel('tr', 1)).toBe('%100');
    expect(shareRateLabel('tr', 0.3333333)).toBe('%33');
  });

  it('ÇEKİRDEK: yüzde işareti DİLE göre yer değiştirir (TR %25, EN 25%)', () => {
    // Elle `%${n}` yazmak TR'yi doğru, EN'i yanlış yapıyordu.
    expect(shareRateLabel('en', 0.25)).toBe('25%');
    expect(shareRateLabel('en', 1)).toBe('100%');
  });
});

describe('shareRateHint', () => {
  it('ham sayıları gösterir — oran tek başına yanıltıcıdır (1/1 = %100)', () => {
    expect(shareRateHint('tr', 1, 1)).toBe('1/1 kişi');
    expect(shareRateHint('tr', 120, 30)).toBe('30/120 kişi');
  });

  it('EN panelde ipucu da İngilizce', () => {
    expect(shareRateHint('en', 120, 30)).toBe('30/120 people');
  });

  it('hiç test yoksa sebebini söyler', () => {
    expect(shareRateHint('tr', 0, 0)).toBe('henüz test tamamlanmadı');
    expect(shareRateHint('en', 0, 0)).toBe('no test completed yet');
  });
});
