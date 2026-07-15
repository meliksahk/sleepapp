import {
  isBcp47Locale,
  isIanaTimeZone,
} from '../../src/modules/profile/presentation/field.validators';

describe('isIanaTimeZone', () => {
  it('geçerli IANA saat dilimleri', () => {
    for (const tz of ['UTC', 'Europe/Istanbul', 'America/New_York', 'Asia/Tokyo']) {
      expect(isIanaTimeZone(tz)).toBe(true);
    }
  });

  it('geçersiz / bozuk değerler', () => {
    for (const bad of ['Nowhere/Void', 'Istanbul', '', 'not a tz', 42, null, undefined]) {
      expect(isIanaTimeZone(bad)).toBe(false);
    }
  });
});

describe('isBcp47Locale', () => {
  it('geçerli dil etiketleri', () => {
    for (const loc of ['en', 'tr', 'en-US', 'pt-BR']) {
      expect(isBcp47Locale(loc)).toBe(true);
    }
  });

  it('geçersiz / bozuk değerler', () => {
    for (const bad of ['!!', 'a b', '', 'toolonglocaletag', 123, null]) {
      expect(isBcp47Locale(bad)).toBe(false);
    }
  });
});
