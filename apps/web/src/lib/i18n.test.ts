import { describe, it, expect } from 'vitest';
import { dictionaries, LOCALES, isLocale, t } from './i18n';

describe('sözlükler (i18n)', () => {
  it('TR ve EN anahtar setleri BİREBİR aynı', () => {
    // Tip sistemi zaten eksik anahtarı derleme hatasına çevirir; bu test fazlalık
    // anahtarı ve boş çeviriyi de yakalar (tipin göremediği hâller).
    const en = Object.keys(dictionaries.en).sort();
    const tr = Object.keys(dictionaries.tr).sort();
    expect(tr).toEqual(en);
  });

  it('hiçbir çeviri boş değil', () => {
    for (const locale of LOCALES) {
      for (const [key, value] of Object.entries(dictionaries[locale])) {
        expect(value.trim(), `${locale}.${key}`).not.toBe('');
      }
    }
  });

  it('TR çevirileri EN metinden farklı (kopyala-yapıştır kalıntısı yok)', () => {
    // İstisna: marka/dil adları iki dilde de aynı olabilir.
    const sameAllowed = new Set(['footer.otherLocale']);
    for (const key of Object.keys(dictionaries.en) as Array<keyof typeof dictionaries.en>) {
      if (sameAllowed.has(key)) continue;
      expect(dictionaries.tr[key], `${key} çevrilmemiş`).not.toBe(dictionaries.en[key]);
    }
  });

  it('{ad} yer tutucularını doldurur, eksik değeri olduğu gibi bırakır', () => {
    expect(t('en', 'card.shareTitle', { name: 'Deep Ocean' })).toBe(
      'My sleep identity is Deep Ocean',
    );
    expect(t('tr', 'card.shareTitle', { name: 'Derin Okyanus' })).toContain('Derin Okyanus');
    expect(t('en', 'card.shareTitle', {})).toContain('{name}');
  });

  it('isLocale yalnızca desteklenen dilleri kabul eder', () => {
    expect(isLocale('tr')).toBe(true);
    expect(isLocale('en')).toBe(true);
    expect(isLocale('de')).toBe(false);
    expect(isLocale(undefined)).toBe(false);
  });

  it('SAĞLIK İDDİASI YOK — iki dilde de yasak kelime geçmez (CLAUDE.md §1.1)', () => {
    const bannedEn =
      /\b(cure|cures|treat|treats|treatment|therapy|therapeutic|clinical|medical|disease)\b/i;
    const bannedTr = /(?<![\p{L}])(tedavi|terapi|terapötik|klinik|tıbb|hastalık|iyileştir|şifa)/iu;
    for (const locale of LOCALES) {
      const blob = Object.values(dictionaries[locale]).join(' ');
      expect(blob).not.toMatch(bannedEn);
      expect(blob).not.toMatch(bannedTr);
    }
  });
});
