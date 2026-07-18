import {
  LAYER_SOURCES,
  MAX_MIXER_LAYERS,
  parseMixerState,
} from '../../src/modules/content/domain/mixer-state';
import { InvalidRecipeError } from '../../src/modules/content/domain/errors';

const valid = {
  layers: [
    { id: 'rain', type: 'pink', gain: 0.5 },
    { id: 'deep', type: 'brown', gain: 0.4 },
  ],
};

describe('parseMixerState (preset sözleşme kapısı)', () => {
  it('geçerli mixer_state ayrıştırılır', () => {
    const parsed = parseMixerState(valid);
    expect(parsed).not.toBeNull();
    expect(parsed?.layers).toHaveLength(2);
    expect(parsed?.layers[0]).toEqual({ id: 'rain', type: 'pink', gain: 0.5 });
  });

  it('sınır kazançlar (0 ve 1) geçerli', () => {
    expect(
      parseMixerState({
        layers: [
          { id: 'a', type: 'white', gain: 0 },
          { id: 'b', type: 'brown', gain: 1 },
        ],
      }),
    ).not.toBeNull();
  });

  describe('reddedilenler (bozuk içerik istemciye ulaşmamalı)', () => {
    const cases: Array<[string, unknown]> = [
      ['null', null],
      ['dizi', []],
      ['layers yok', {}],
      ['layers dizi değil', { layers: 'rain' }],
      ['boş layers', { layers: [] }],
      // ESKİ serbest biçim — sessizce kabul edilmemeli (tip bilgisi yok)
      ['eski {rain:0.7} biçimi', { rain: 0.7 }],
      ['bilinmeyen tip', { layers: [{ id: 'a', type: 'purple', gain: 0.5 }] }],
      ['tip yok', { layers: [{ id: 'a', gain: 0.5 }] }],
      ['id boş', { layers: [{ id: '', type: 'white', gain: 0.5 }] }],
      ['id çok uzun', { layers: [{ id: 'x'.repeat(41), type: 'white', gain: 0.5 }] }],
      ['gain aralık dışı (>1)', { layers: [{ id: 'a', type: 'white', gain: 1.2 }] }],
      ['gain negatif', { layers: [{ id: 'a', type: 'white', gain: -0.1 }] }],
      ['gain string', { layers: [{ id: 'a', type: 'white', gain: '0.5' }] }],
      ['gain NaN', { layers: [{ id: 'a', type: 'white', gain: Number.NaN }] }],
      ['gain Infinity', { layers: [{ id: 'a', type: 'white', gain: Number.POSITIVE_INFINITY }] }],
      [
        'tekrar eden id (belirsiz mix)',
        {
          layers: [
            { id: 'a', type: 'white', gain: 0.5 },
            { id: 'a', type: 'pink', gain: 0.5 },
          ],
        },
      ],
    ];

    it.each(cases)('%s → null', (_name, input) => {
      expect(parseMixerState(input)).toBeNull();
    });

    it(`${MAX_MIXER_LAYERS}'den fazla katman → null (CPU/headroom sınırı)`, () => {
      const layers = Array.from({ length: MAX_MIXER_LAYERS + 1 }, (_, i) => ({
        id: `l${i}`,
        type: 'white',
        gain: 0.1,
      }));
      expect(parseMixerState({ layers })).toBeNull();
    });

    it('tek katman bozuksa TÜM state reddedilir (kısmi yükleme yok)', () => {
      expect(
        parseMixerState({
          layers: [
            { id: 'ok', type: 'pink', gain: 0.5 },
            { id: 'bad', type: 'nope', gain: 0.5 },
          ],
        }),
      ).toBeNull();
    });
  });

  it(`tam ${MAX_MIXER_LAYERS} katman geçerli (sınır dahil)`, () => {
    const layers = Array.from({ length: MAX_MIXER_LAYERS }, (_, i) => ({
      id: `l${i}`,
      type: 'white',
      gain: 0.1,
    }));
    expect(parseMixerState({ layers })?.layers).toHaveLength(MAX_MIXER_LAYERS);
  });
});

describe('meditatif kaynaklar (#213) — sözleşme genişledi', () => {
  it.each(['waves', 'fire', 'rain', 'pad'])('yeni kaynak "%s" kabul edilir', (type) => {
    const parsed = parseMixerState({ layers: [{ id: 'l', type, gain: 0.5 }] });
    expect(parsed?.layers[0]?.type).toBe(type);
  });

  it('ESKİ tarifler aynen geçerli kalır (geriye uyum)', () => {
    // db/seed.sql'deki 6 reçete yalnız white/pink/brown kullanıyor. Yeni tip
    // eklemek eskiyi bozarsa mevcut kütüphane sessizce çalınamaz hâle gelirdi.
    for (const type of ['white', 'pink', 'brown']) {
      expect(parseMixerState({ layers: [{ id: 'l', type, gain: 0.5 }] })).not.toBeNull();
    }
  });

  it('gürültü + meditatif KARIŞIK tarif geçerli (kullanıcının asıl isteği)', () => {
    const parsed = parseMixerState({
      layers: [
        { id: 'deep', type: 'brown', gain: 0.4 },
        { id: 'swell', type: 'waves', gain: 0.3 },
        { id: 'hearth', type: 'fire', gain: 0.2 },
        { id: 'drone', type: 'pad', gain: 0.1 },
      ],
    });
    expect(parsed?.layers).toHaveLength(4);
  });

  it('TANINMAYAN tip hâlâ reddediliyor (liste genişledi, kapı gevşemedi)', () => {
    expect(parseMixerState({ layers: [{ id: 'l', type: 'thunder', gain: 0.5 }] })).toBeNull();
  });

  it('hata metni TÜM geçerli tipleri sayar (editör listeyi hatadan öğrenir)', () => {
    // Elle yazılmış bir metin, liste büyüyünce sessizce eskirdi.
    const msg = new InvalidRecipeError().message;
    for (const t of LAYER_SOURCES) {
      expect(msg).toContain(t);
    }
  });
});
