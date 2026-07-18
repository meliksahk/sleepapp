import { describe, it, expect } from 'vitest';
import { campaignErrorMessage } from './campaign-error-message';

describe('campaignErrorMessage', () => {
  it('403 owner-özel yetki mesajı', () => {
    expect(campaignErrorMessage(403)).toContain('yalnızca owner');
  });

  it('400 girdi doğrulama ipucu', () => {
    expect(campaignErrorMessage(400)).toContain('boş olamaz');
  });

  it('bilinmeyen hata genel mesaj (sessiz başarısızlık yok)', () => {
    expect(campaignErrorMessage(500)).toBe('Kampanya gönderilemedi. Lütfen tekrar deneyin.');
  });
});
