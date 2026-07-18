import { describe, it, expect } from 'vitest';
import { statusLabel } from './status-label';

describe('statusLabel', () => {
  it('bilinen durumlar Türkçeye çevrilir', () => {
    expect(statusLabel('tr', 'draft')).toBe('Taslak');
    expect(statusLabel('tr', 'scheduled')).toBe('Planlandı');
    expect(statusLabel('tr', 'published')).toBe('Yayında');
  });

  it('ÇEKİRDEK: aynı durum EN panelde İngilizce çıkar', () => {
    // Etiketler eskiden TR sabit-koduydu: dil değişse de "Taslak" yazıyordu.
    expect(statusLabel('en', 'draft')).toBe('Draft');
    expect(statusLabel('en', 'published')).toBe('Published');
  });

  it('BİLİNMEYEN durum yutulmaz, ham değer gösterilir', () => {
    // API yeni bir durum eklerse panel boş hücre göstermemeli: editör
    // "burada tanımadığım bir şey var" görmeli, hiçbir şey değil.
    expect(statusLabel('tr', 'archived')).toBe('archived');
    expect(statusLabel('en', 'archived')).toBe('archived');
  });
});
