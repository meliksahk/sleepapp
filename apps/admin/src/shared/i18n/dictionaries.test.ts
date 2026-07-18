import { describe, it, expect } from 'vitest';

import { dictionaries, locales, translate, isLocale } from './dictionaries';

/**
 * Sözlük güvenceleri.
 *
 * Mobilde EN/TR anahtar paritesini ayrı bir test koruyordu; burada TypeScript
 * zaten derleme zamanında zorluyor. Bu testler tipin göremediklerini kapatır:
 * boş çeviri, yer tutucu doldurma, bozuk dil kodu.
 */
describe('admin sözlükleri', () => {
  it('ÇEKİRDEK: her dilde TÜM anahtarlar dolu (boş string yok)', () => {
    for (const locale of locales) {
      for (const [key, value] of Object.entries(dictionaries[locale])) {
        expect(value.trim(), `${locale}.${key} boş`).not.toBe('');
      }
    }
  });

  it('ÇEKİRDEK: EN ve TR aynı anahtar kümesi (tip + runtime)', () => {
    expect(Object.keys(dictionaries.en).sort()).toEqual(Object.keys(dictionaries.tr).sort());
  });

  it('yer tutucular doldurulur', () => {
    const out = translate('tr', 'campaign.queued', { recipients: 12, queued: 12 });
    expect(out).toContain('12');
    expect(out).not.toContain('{recipients}');
  });

  it('eksik değişken anahtarı OLDUĞU GİBİ bırakır (sessiz boşluk yerine görünür işaret)', () => {
    const out = translate('en', 'campaign.queued', { recipients: 3 });
    expect(out).toContain('{queued}');
  });

  it('bozuk dil kodu reddedilir (çerez kurcalanırsa panel kilitlenmesin)', () => {
    expect(isLocale('xx')).toBe(false);
    expect(isLocale(undefined)).toBe(false);
    expect(isLocale('tr')).toBe(true);
  });
});
