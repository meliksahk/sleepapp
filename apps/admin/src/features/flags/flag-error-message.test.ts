import { describe, it, expect } from 'vitest';
import { translate } from '@/shared/i18n/dictionaries';
import { flagErrorMessage } from './flag-error-message';

/** Anahtar → o dildeki metin. Testlerin derdi metin, dönüş değeri artık anahtar. */
const tr = (status: number, code?: string): string =>
  translate('tr', flagErrorMessage(status, code));

describe('flagErrorMessage', () => {
  it('geçersiz anahtar AYIRT EDİCİ mesaj verir', () => {
    expect(tr(400, 'flag_key_invalid')).toContain('Anahtar geçersiz');
  });

  it('403 owner-özel yetki mesajı', () => {
    expect(tr(403)).toContain('yalnızca owner');
  });

  it('400 girdi doğrulama ipucu (yüzde/sürüm)', () => {
    expect(tr(400)).toContain('0-100');
  });

  it('bilinmeyen hata genel mesaj (sessiz başarısızlık yok)', () => {
    expect(tr(500)).toBe('Kaydedilemedi. Lütfen tekrar deneyin.');
  });

  it('ÇEKİRDEK: aynı hata EN panelde İngilizce çıkar', () => {
    expect(translate('en', flagErrorMessage(400, 'flag_key_invalid'))).toContain('Invalid key');
    expect(translate('en', flagErrorMessage(403))).toContain('only the owner');
  });
});
