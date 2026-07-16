import { describe, it, expect } from 'vitest';
import { auditActionLabel } from './audit-label';

describe('auditActionLabel', () => {
  it('bilinen eylemler Türkçeye çevrilir', () => {
    expect(auditActionLabel('soundscape.publish')).toBe('yayınladı');
    expect(auditActionLabel('soundscape.recipe')).toBe('ses tarifini değiştirdi');
  });

  it('BİLİNMEYEN eylem yutulmaz, ham değer gösterilir', () => {
    // Denetim izinde "bir şey oldu ama tanımıyorum" görmek, hiçbir şey
    // görmemekten iyidir.
    expect(auditActionLabel('soundscape.delete')).toBe('soundscape.delete');
  });
});
