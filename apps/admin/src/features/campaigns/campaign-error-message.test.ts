import { describe, it, expect } from 'vitest';
import { translate } from '@/shared/i18n/dictionaries';
import { campaignErrorMessage } from './campaign-error-message';

/** Anahtar → o dildeki metin. Testlerin derdi metin, dönüş değeri artık anahtar. */
const tr = (status: number): string => translate('tr', campaignErrorMessage(status));

describe('campaignErrorMessage', () => {
  it('403 owner-özel yetki mesajı', () => {
    expect(tr(403)).toContain('yalnızca owner');
  });

  it('400 girdi doğrulama ipucu', () => {
    expect(tr(400)).toContain('boş olamaz');
  });

  it('bilinmeyen hata genel mesaj (sessiz başarısızlık yok)', () => {
    expect(tr(500)).toBe('Kampanya gönderilemedi. Lütfen tekrar deneyin.');
  });

  it('ÇEKİRDEK: aynı hata EN panelde İngilizce çıkar', () => {
    expect(translate('en', campaignErrorMessage(403))).toContain('only the owner');
    expect(translate('en', campaignErrorMessage(500))).toContain('Could not send');
  });
});
