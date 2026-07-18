import { describe, it, expect } from 'vitest';
import { translate } from '@/shared/i18n/dictionaries';
import { createErrorMessage } from './error-message';

/** Anahtar → o dildeki metin. Testlerin derdi metin, dönüş değeri artık anahtar. */
const tr = (status: number, code?: string): string =>
  translate('tr', createErrorMessage(status, code));
const en = (status: number, code?: string): string =>
  translate('en', createErrorMessage(status, code));

describe('createErrorMessage', () => {
  it('slug dolu → ne yapacağını söyler', () => {
    expect(tr(409, 'slug_taken')).toContain('zaten kullanımda');
  });

  it('geçersiz slug → kuralı örnekle anlatır', () => {
    expect(tr(400, 'invalid_slug')).toContain('deep-ocean-drift');
  });

  it('403 → yetki sebebini söyler (sessizce başarısız olmaz)', () => {
    expect(tr(403)).toContain('yetkiniz yok');
  });

  it('bilinmeyen hata → genel ama eyleme dönük mesaj', () => {
    expect(tr(500)).toContain('tekrar deneyin');
  });

  it('kod, duruma göre ÖNCELİKLİ: 400+invalid_slug genel 400 mesajını ezer', () => {
    expect(createErrorMessage(400, 'invalid_slug')).toBe('content.errorInvalidSlug');
    expect(createErrorMessage(400)).toBe('content.errorBadInput');
  });

  it('boş tarif → NE YAPACAĞINI söyler, "409" demez', () => {
    const msg = tr(409, 'empty_recipe');
    expect(msg).toContain('Ses tarifi boş');
    expect(msg).not.toContain('409');
  });

  it('bulunamadı → listenin eski olabileceğini ima eder', () => {
    expect(tr(404, 'soundscape_not_found')).toContain('bulunamadı');
  });

  it('ÇEKİRDEK: aynı hata EN panelde İngilizce çıkar', () => {
    // Eskiden TR dizge dönüyordu: dil ne olursa olsun hata Türkçeydi.
    expect(en(409, 'slug_taken')).toContain('already taken');
    expect(en(403)).toContain('permission');
  });
});
