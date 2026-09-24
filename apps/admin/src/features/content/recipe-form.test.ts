import { describe, it, expect } from 'vitest';
import { normalizeLayers, toFormLayers, type RecipeLayer } from './recipe-form';

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

  it('tone katmanı: frekans KORUNUR (editör görebilmeli, kaybetmemeli)', () => {
    expect(
      toFormLayers({
        schemaVersion: 1,
        layers: [{ id: 'hum', type: 'tone', gain: 0.18, frequencyHz: 110 }],
      }),
    ).toEqual([{ id: 'hum', type: 'tone', gain: 0.18, frequencyHz: 110 }]);
  });

  it('tone katmanı frekansı aralık dışıysa kırpılır (kurtarır, reddetmez)', () => {
    const out = toFormLayers({
      layers: [
        { id: 'low', type: 'tone', gain: 0.2, frequencyHz: 5 },
        { id: 'high', type: 'tone', gain: 0.2, frequencyHz: 9999 },
      ],
    });
    expect(out[0]?.frequencyHz).toBe(20);
    expect(out[1]?.frequencyHz).toBe(2000);
  });

  it('beatHz KORUNUR — düşürülseydi binaural tarif sessizce mono olurdu', () => {
    expect(
      toFormLayers({
        layers: [{ id: 'b', type: 'tone', gain: 0.18, frequencyHz: 200, beatHz: 8 }],
      }),
    ).toEqual([{ id: 'b', type: 'tone', gain: 0.18, frequencyHz: 200, beatHz: 8 }]);
  });

  it('beat aralık dışıysa kırpılır; ton dışındaki beat SİLİNİR', () => {
    const out = toFormLayers({
      layers: [
        { id: 'hi', type: 'tone', gain: 0.2, frequencyHz: 200, beatHz: 999 },
        { id: 'noise', type: 'pink', gain: 0.5, beatHz: 8 },
      ],
    });
    expect(out[0]?.beatHz).toBe(20);
    expect(out[1]).not.toHaveProperty('beatHz');
  });
});

describe('normalizeLayers (YAZMA yolu — sunucu kapısına uygun JSON)', () => {
  it('ton DIŞI katmandan frequencyHz SİLİNİR (sunucu onu reddederdi)', () => {
    // Senaryo: editör önce tone seçip frekans girdi, sonra tipi pink yaptı —
    // yetim alan satırda kalmış olurdu.
    expect(normalizeLayers([{ id: 'a', type: 'pink', gain: 0.5, frequencyHz: 110 }])).toEqual([
      { id: 'a', type: 'pink', gain: 0.5 },
    ]);
  });

  it('ton DIŞI katmandan beatHz de SİLİNİR; tonda beat ≤ 0 silinir (yokluk=mono)', () => {
    expect(
      normalizeLayers([
        { id: 'a', type: 'pink', gain: 0.5, beatHz: 8 },
        { id: 'z', type: 'tone', gain: 0.2, frequencyHz: 110, beatHz: 0 },
      ]),
    ).toEqual([
      { id: 'a', type: 'pink', gain: 0.5 },
      { id: 'z', type: 'tone', gain: 0.2, frequencyHz: 110 },
    ]);
  });

  it('geçerli beat KORUNUR ve tavana kırpılır (>20 → 20)', () => {
    expect(
      normalizeLayers([
        { id: 'b', type: 'tone', gain: 0.2, frequencyHz: 200, beatHz: 8 } as RecipeLayer,
        { id: 'h', type: 'tone', gain: 0.2, frequencyHz: 200, beatHz: 99 } as RecipeLayer,
      ]),
    ).toEqual([
      { id: 'b', type: 'tone', gain: 0.2, frequencyHz: 200, beatHz: 8 },
      { id: 'h', type: 'tone', gain: 0.2, frequencyHz: 200, beatHz: 20 },
    ]);
  });

  it('ton katmanındaki frekans aralığa oturtulur ve tam sayıya yuvarlanır', () => {
    const input: RecipeLayer[] = [
      { id: 'l', type: 'tone', gain: 0.2, frequencyHz: 110.7 },
      { id: 'h', type: 'tone', gain: 0.2, frequencyHz: 5000 },
    ];
    expect(normalizeLayers(input)).toEqual([
      { id: 'l', type: 'tone', gain: 0.2, frequencyHz: 111 },
      { id: 'h', type: 'tone', gain: 0.2, frequencyHz: 2000 },
    ]);
  });

  it('frekanssız tone satırına dokunulmaz (formda görünür; eksiklik editörün düzeltmesi için)', () => {
    // normalizeLayers EKLEMEZ — sunucu kapısı yine reddedebilir ama formda
    // boş Hz kutusu zaten kullanıcıya "doldur" diyor.
    expect(normalizeLayers([{ id: 'l', type: 'tone', gain: 0.2 }])).toEqual([
      { id: 'l', type: 'tone', gain: 0.2 },
    ]);
  });

  it('temiz tarif DEĞİŞMEZ (idempotent)', () => {
    const recipe: RecipeLayer[] = [{ id: 'hum', type: 'tone', gain: 0.18, frequencyHz: 110 }];
    expect(normalizeLayers(recipe)).toEqual(recipe);
  });
});
