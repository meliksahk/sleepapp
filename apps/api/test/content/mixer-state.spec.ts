import {
  LAYER_SOURCES,
  MAX_MIXER_LAYERS,
  parseMixerState,
  TONE_BEAT_MAX_HZ,
  TONE_BEAT_MIN_HZ,
  TONE_MAX_HZ,
  TONE_MIN_HZ,
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

describe('tone kaynağı — frekans sözleşmesi', () => {
  it('tone + geçerli frekans kabul edilir ve değer KORUNUR', () => {
    const parsed = parseMixerState({
      layers: [{ id: 'hum', type: 'tone', gain: 0.2, frequencyHz: 110 }],
    });
    expect(parsed).not.toBeNull();
    expect(parsed?.layers[0]).toEqual({
      id: 'hum',
      type: 'tone',
      gain: 0.2,
      frequencyHz: 110,
    });
  });

  it.each([
    ['frekans YOK (ton için zorunlu)', { id: 'l', type: 'tone', gain: 0.2 }],
    [
      `aralık altı (< ${TONE_MIN_HZ})`,
      { id: 'l', type: 'tone', gain: 0.2, frequencyHz: TONE_MIN_HZ - 0.1 },
    ],
    [
      `aralık üstü (> ${TONE_MAX_HZ})`,
      { id: 'l', type: 'tone', gain: 0.2, frequencyHz: TONE_MAX_HZ + 1 },
    ],
    ['frekans NaN', { id: 'l', type: 'tone', gain: 0.2, frequencyHz: Number.NaN }],
    [
      'frekans Infinity',
      { id: 'l', type: 'tone', gain: 0.2, frequencyHz: Number.POSITIVE_INFINITY },
    ],
    ['frekans string', { id: 'l', type: 'tone', gain: 0.2, frequencyHz: '110' }],
    // Ton DIŞI katmana frekans iliştirmek sözleşme ihlalidir: sessizce yok
    // saymak, editörün hatasını duyulmayan bir sapmaya çevirirdi.
    ['gürültü katmanına frekans', { id: 'l', type: 'brown', gain: 0.5, frequencyHz: 110 }],
  ])('%s → null', (_name, layer) => {
    expect(parseMixerState({ layers: [layer] })).toBeNull();
  });

  it('sınır frekanslar (tam TONE_MIN_HZ ve TONE_MAX_HZ) geçerli', () => {
    for (const hz of [TONE_MIN_HZ, TONE_MAX_HZ]) {
      expect(
        parseMixerState({ layers: [{ id: 'l', type: 'tone', gain: 0.2, frequencyHz: hz }] }),
      ).not.toBeNull();
    }
  });

  it('tone + gürültü karışık tarif geçerli (kullanıcının "istenilen frekans" isteği)', () => {
    const parsed = parseMixerState({
      layers: [
        { id: 'body', type: 'brown', gain: 0.55 },
        { id: 'hum', type: 'tone', gain: 0.18, frequencyHz: 110 },
        { id: 'air', type: 'pink', gain: 0.12 },
      ],
    });
    expect(parsed?.layers).toHaveLength(3);
    expect(parsed?.layers[1]?.frequencyHz).toBe(110);
  });

  it('tek katman bozuksa (ton frekansı eksik) TÜM state reddedilir', () => {
    expect(
      parseMixerState({
        layers: [
          { id: 'ok', type: 'brown', gain: 0.5 },
          { id: 'bad', type: 'tone', gain: 0.3 }, // frequencyHz yok
        ],
      }),
    ).toBeNull();
  });
});

describe('beatHz — binaural vuru sözleşmesi', () => {
  it('tone + beat kabul edilir ve değer KORUNUR', () => {
    const parsed = parseMixerState({
      layers: [{ id: 'b', type: 'tone', gain: 0.18, frequencyHz: 200, beatHz: 8 }],
    });
    expect(parsed?.layers[0]).toEqual({
      id: 'b',
      type: 'tone',
      gain: 0.18,
      frequencyHz: 200,
      beatHz: 8,
    });
  });

  it('beat YOKLUĞU mono demektir ve alan TELDE HİÇ GÖRÜNMEZ', () => {
    // "0 göndermek" yerine yokluk: JSON'da beatHz anahtarı olmamalı.
    const parsed = parseMixerState({
      layers: [{ id: 'mono', type: 'tone', gain: 0.2, frequencyHz: 110 }],
    });
    expect(parsed?.layers[0]).not.toHaveProperty('beatHz');
  });

  it.each([
    [
      'beat = 0 (yasak — mono alanın yokluğudur)',
      { id: 'l', type: 'tone', gain: 0.2, frequencyHz: 110, beatHz: 0 },
    ],
    [
      `beat aralık altı (< ${TONE_BEAT_MIN_HZ})`,
      { id: 'l', type: 'tone', gain: 0.2, frequencyHz: 110, beatHz: 0.1 },
    ],
    [
      `beat aralık üstü (> ${TONE_BEAT_MAX_HZ})`,
      { id: 'l', type: 'tone', gain: 0.2, frequencyHz: 110, beatHz: 25 },
    ],
    ['beat NaN', { id: 'l', type: 'tone', gain: 0.2, frequencyHz: 110, beatHz: Number.NaN }],
    ['beat string', { id: 'l', type: 'tone', gain: 0.2, frequencyHz: 110, beatHz: '8' }],
    ['ton DIŞI katmanda beat', { id: 'l', type: 'brown', gain: 0.5, beatHz: 8 }],
  ])('%s → null', (_name, layer) => {
    expect(parseMixerState({ layers: [layer] })).toBeNull();
  });

  it(`sınır vuru (tam ${TONE_BEAT_MIN_HZ} ve ${TONE_BEAT_MAX_HZ}) geçerli`, () => {
    for (const b of [TONE_BEAT_MIN_HZ, TONE_BEAT_MAX_HZ]) {
      expect(
        parseMixerState({
          layers: [{ id: 'l', type: 'tone', gain: 0.2, frequencyHz: 200, beatHz: b }],
        }),
      ).not.toBeNull();
    }
  });
});
