import {
  MAX_PENDING_SOUNDS_PER_USER,
  SOUND_DURATION_MAX_SECONDS,
  SOUND_TITLE_MAX_LENGTH,
  sanitizeDuration,
  sanitizeTitle,
} from '../../src/modules/community/domain/user-sound';

describe('user_sound doğrulayıcıları (saf domain)', () => {
  describe('sanitizeTitle', () => {
    it('geçerli başlığı trim edip döndürür', () => {
      expect(sanitizeTitle('  Yağmurlu balkon ')).toBe('Yağmurlu balkon');
    });

    it.each([
      ['null (tip değil)', null],
      ['sayı', 42],
      ['boş string', ''],
      ['yalnız whitespace', '   '],
      ['tavan aşımı', 'x'.repeat(SOUND_TITLE_MAX_LENGTH + 1)],
    ])('%s → null', (_name, raw) => {
      expect(sanitizeTitle(raw)).toBeNull();
    });

    it('tam tavana sığan başlık geçerli', () => {
      expect(sanitizeTitle('y'.repeat(SOUND_TITLE_MAX_LENGTH))).not.toBeNull();
    });
  });

  describe('sanitizeDuration', () => {
    it.each([
      ['1 sn alt sınır', 1, 1],
      ['ondalıklı → tam sayıya yuvarlanır', 1799.6, 1800],
      ['tam tavan', SOUND_DURATION_MAX_SECONDS, SOUND_DURATION_MAX_SECONDS],
    ])('%s → %p', (_name, raw, expected) => {
      expect(sanitizeDuration(raw as number)).toBe(expected);
    });

    it.each([
      ['sıfır', 0],
      ['negatif', -5],
      ['tavan aşımı', SOUND_DURATION_MAX_SECONDS + 1],
      ['NaN', Number.NaN],
      ['Infinity', Number.POSITIVE_INFINITY],
      ['string', '60'],
      [null, null],
    ])('%s → null', (_name, raw) => {
      expect(sanitizeDuration(raw)).toBeNull();
    });
  });

  it('pending tavanı spam kancası olarak belgelenmiştir (10)', () => {
    // Sayı sabitine bağlı davranış use case testinde; burada yalnızca
    // değerin yanlışlıkla sıfırlanmaması kilitlenir.
    expect(MAX_PENDING_SOUNDS_PER_USER).toBeGreaterThan(0);
  });
});
