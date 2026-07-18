import { describe, it, expect } from 'vitest';
import { auditActionLabel } from './audit-label';

describe('auditActionLabel', () => {
  it('bilinen eylemler Türkçeye çevrilir', () => {
    expect(auditActionLabel('tr', 'soundscape.publish')).toBe('yayınladı');
    expect(auditActionLabel('tr', 'soundscape.recipe')).toBe('ses tarifini değiştirdi');
  });

  it('ÇEKİRDEK: aynı eylem EN panelde İngilizce çıkar', () => {
    expect(auditActionLabel('en', 'soundscape.publish')).toBe('published');
    expect(auditActionLabel('en', 'soundscape.recipe')).toBe('changed the sound recipe');
  });

  it('BİLİNMEYEN eylem yutulmaz, ham değer gösterilir', () => {
    // Denetim izinde "bir şey oldu ama tanımıyorum" görmek, hiçbir şey
    // görmemekten iyidir.
    expect(auditActionLabel('tr', 'soundscape.delete')).toBe('soundscape.delete');
  });
});
