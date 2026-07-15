import { nightDateOf, NIGHT_BOUNDARY_HOUR } from '../../src/shared/time/night';

// Yardımcı: belirli bir yerel duvar-saatini UTC instant'a çevirmek yerine, bilinen
// UTC anlarını doğrudan veriyoruz ve tz'ye göre gece etiketini doğruluyoruz.

describe('nightDateOf (gece gruplama, 06:00 sınırı)', () => {
  it('sınır sabiti 06:00', () => {
    expect(NIGHT_BOUNDARY_HOUR).toBe(6);
  });

  it('akşam (23:00 yerel) → o günün gecesi', () => {
    // 2026-01-10T23:00 Europe/Istanbul = 2026-01-10T20:00Z (UTC+3)
    const instant = new Date('2026-01-10T20:00:00Z');
    expect(nightDateOf(instant, 'Europe/Istanbul')).toBe('2026-01-10');
  });

  it('gece yarısı sonrası ama 06:00 öncesi (02:00 yerel) → önceki günün gecesi', () => {
    // 2026-01-11T02:00 Europe/Istanbul = 2026-01-10T23:00Z
    const instant = new Date('2026-01-10T23:00:00Z');
    expect(nightDateOf(instant, 'Europe/Istanbul')).toBe('2026-01-10');
  });

  it('05:59 yerel → önceki gün; 06:00 yerel → o gün (sınır dahil)', () => {
    // 05:59 Istanbul = 02:59Z
    expect(nightDateOf(new Date('2026-01-11T02:59:00Z'), 'Europe/Istanbul')).toBe('2026-01-10');
    // 06:00 Istanbul = 03:00Z
    expect(nightDateOf(new Date('2026-01-11T03:00:00Z'), 'Europe/Istanbul')).toBe('2026-01-11');
  });

  it('aynı UTC anı farklı saat dilimlerinde farklı gece verir', () => {
    // 2026-03-01T04:00Z → Istanbul 07:00 (o gün), New York 23:00 önceki gün
    const instant = new Date('2026-03-01T04:00:00Z');
    expect(nightDateOf(instant, 'Europe/Istanbul')).toBe('2026-03-01');
    expect(nightDateOf(instant, 'America/New_York')).toBe('2026-02-28');
  });

  it('ay sınırı: 02:00 yerel 1 Oca → 31 Ara gecesi', () => {
    // 2026-01-01T02:00 Istanbul = 2025-12-31T23:00Z
    expect(nightDateOf(new Date('2025-12-31T23:00:00Z'), 'Europe/Istanbul')).toBe('2025-12-31');
  });

  it('yıl sınırı: 02:00 yerel 1 Oca → 31 Ara önceki yıl', () => {
    // 2026-01-01T03:00 Istanbul = 2026-01-01T00:00Z → 02:00'dan sonra? 03:00 yerel < 06 → önceki gün 2025-12-31
    expect(nightDateOf(new Date('2026-01-01T00:00:00Z'), 'Europe/Istanbul')).toBe('2025-12-31');
  });

  it('UTC saat dilimi ile doğrudan', () => {
    expect(nightDateOf(new Date('2026-06-15T05:00:00Z'), 'UTC')).toBe('2026-06-14'); // 05:00 < 06
    expect(nightDateOf(new Date('2026-06-15T06:00:00Z'), 'UTC')).toBe('2026-06-15'); // 06:00
  });
});
