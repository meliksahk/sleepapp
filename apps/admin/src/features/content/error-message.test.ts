import { describe, it, expect } from 'vitest';
import { createErrorMessage } from './error-message';

describe('createErrorMessage', () => {
  it('slug dolu → ne yapacağını söyler', () => {
    expect(createErrorMessage(409, 'slug_taken')).toContain('zaten kullanımda');
  });

  it('geçersiz slug → kuralı örnekle anlatır', () => {
    expect(createErrorMessage(400, 'invalid_slug')).toContain('deep-ocean-drift');
  });

  it('403 → yetki sebebini söyler (sessizce başarısız olmaz)', () => {
    expect(createErrorMessage(403)).toContain('yetkiniz yok');
  });

  it('bilinmeyen hata → genel ama eyleme dönük mesaj', () => {
    expect(createErrorMessage(500)).toContain('tekrar deneyin');
  });

  it('kod, duruma göre ÖNCELİKLİ: 400+invalid_slug genel 400 mesajını ezer', () => {
    expect(createErrorMessage(400, 'invalid_slug')).not.toContain('Girdiler geçersiz');
  });
});
