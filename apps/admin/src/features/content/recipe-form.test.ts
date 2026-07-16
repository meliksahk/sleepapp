import { describe, it, expect } from 'vitest';
import { toFormLayers } from './recipe-form';

describe('toFormLayers (bozuk tarifi KURTARIR, reddetmez)', () => {
  it('geçerli tarifi olduğu gibi yükler', () => {
    expect(
      toFormLayers({ schemaVersion: 1, layers: [{ id: 'a', type: 'brown', gain: 0.3 }] }),
    ).toEqual([{ id: 'a', type: 'brown', gain: 0.3 }]);
  });

  it('boş/olmayan tarif → boş liste (yeni taslak)', () => {
    expect(toFormLayers({})).toEqual([]);
    expect(toFormLayers(null)).toEqual([]);
    expect(toFormLayers({ layers: 'bozuk' })).toEqual([]);
  });

  it('BİLİNMEYEN tür güvenli varsayılana düşer — katman KAYBOLMAZ', () => {
    // Editör "bir katman vardı, gitti" dememeli; düzeltebilmeli.
    expect(toFormLayers({ layers: [{ id: 'a', type: 'green', gain: 0.5 }] })).toEqual([
      { id: 'a', type: 'pink', gain: 0.5 },
    ]);
  });

  it('aralık dışı gain kırpılır', () => {
    expect(toFormLayers({ layers: [{ id: 'a', type: 'pink', gain: 5 }] })[0]?.gain).toBe(1);
    expect(toFormLayers({ layers: [{ id: 'a', type: 'pink', gain: -3 }] })[0]?.gain).toBe(0);
  });

  it('gain sayı değilse varsayılana düşer', () => {
    expect(toFormLayers({ layers: [{ id: 'a', type: 'pink', gain: 'çok' }] })[0]?.gain).toBe(0.5);
  });

  it("id'siz katman atılır (kurtarılamaz)", () => {
    expect(toFormLayers({ layers: [{ type: 'pink', gain: 0.5 }] })).toEqual([]);
  });

  it("8'den fazlası kırpılır (API sınırı)", () => {
    const layers = Array.from({ length: 12 }, (_, i) => ({ id: `l${i}`, type: 'pink', gain: 0.1 }));
    expect(toFormLayers({ layers })).toHaveLength(8);
  });
});
