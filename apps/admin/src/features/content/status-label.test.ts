import { describe, it, expect } from 'vitest';
import { statusLabel } from './status-label';

describe('statusLabel', () => {
  it('bilinen durumlar Türkçeye çevrilir', () => {
    expect(statusLabel('draft')).toBe('Taslak');
    expect(statusLabel('scheduled')).toBe('Planlandı');
    expect(statusLabel('published')).toBe('Yayında');
  });

  it('BİLİNMEYEN durum yutulmaz, ham değer gösterilir', () => {
    // API yeni bir durum eklerse panel boş hücre göstermemeli: editör
    // "burada tanımadığım bir şey var" görmeli, hiçbir şey değil.
    expect(statusLabel('archived')).toBe('archived');
  });
});
