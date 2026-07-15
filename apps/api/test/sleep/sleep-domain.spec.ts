import { durationMinutes, isValidRange } from '../../src/modules/sleep/domain/sleep-session.entity';

describe('sleep domain (saf)', () => {
  it('durationMinutes: dakikaya yuvarlar', () => {
    const start = new Date('2026-01-10T23:00:00Z');
    const end = new Date('2026-01-11T06:42:00Z'); // 7s 42dk = 462 dk
    expect(durationMinutes(start, end)).toBe(462);
  });

  it('isValidRange: ended > started', () => {
    const a = new Date('2026-01-10T23:00:00Z');
    const b = new Date('2026-01-11T06:00:00Z');
    expect(isValidRange(a, b)).toBe(true);
    expect(isValidRange(b, a)).toBe(false);
    expect(isValidRange(a, a)).toBe(false); // eşit → geçersiz
  });
});
