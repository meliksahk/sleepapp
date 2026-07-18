import { describe, it, expect } from 'vitest';
import { flagErrorMessage } from './flag-error-message';

describe('flagErrorMessage', () => {
  it('geçersiz anahtar AYIRT EDİCİ mesaj verir', () => {
    expect(flagErrorMessage(400, 'flag_key_invalid')).toContain('Anahtar geçersiz');
  });

  it('403 owner-özel yetki mesajı', () => {
    expect(flagErrorMessage(403)).toContain('yalnızca owner');
  });

  it('400 girdi doğrulama ipucu (yüzde/sürüm)', () => {
    expect(flagErrorMessage(400)).toContain('0-100');
  });

  it('bilinmeyen hata genel mesaj (sessiz başarısızlık yok)', () => {
    expect(flagErrorMessage(500)).toBe('Kaydedilemedi. Lütfen tekrar deneyin.');
  });
});
