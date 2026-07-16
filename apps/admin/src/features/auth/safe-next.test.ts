import { describe, it, expect } from 'vitest';
import { safeNextPath } from './safe-next';

describe('safeNextPath (açık yönlendirme koruması)', () => {
  it('panel içi yolu geçirir', () => {
    expect(safeNextPath('/content')).toBe('/content');
    expect(safeNextPath('/users/42?tab=x')).toBe('/users/42?tab=x');
  });

  it('yok/boşsa köke düşer', () => {
    expect(safeNextPath(undefined)).toBe('/');
    expect(safeNextPath('')).toBe('/');
  });

  it('dış URL reddedilir', () => {
    expect(safeNextPath('https://kotu.site')).toBe('/');
    expect(safeNextPath('http://kotu.site')).toBe('/');
  });

  it('protokol-bağımsız URL reddedilir — "/" ile başlar ama DIŞ adrestir', () => {
    expect(safeNextPath('//kotu.site')).toBe('/');
    expect(safeNextPath('//kotu.site/giris')).toBe('/');
  });

  it('ters bölü hilesi reddedilir (tarayıcı /\\ ifadesini // gibi çözer)', () => {
    expect(safeNextPath('/\\kotu.site')).toBe('/');
  });

  it('javascript: şeması reddedilir', () => {
    expect(safeNextPath('javascript:alert(1)')).toBe('/');
  });
});
