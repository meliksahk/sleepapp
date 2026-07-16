import { MAX_MIXER_LAYERS, parseMixerState } from '../../src/modules/content/domain/mixer-state';

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
