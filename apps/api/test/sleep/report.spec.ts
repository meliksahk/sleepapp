import { buildNightReport, calmScore } from '../../src/modules/sleep/domain/report';
import type { SleepSession } from '../../src/modules/sleep/domain/sleep-session.entity';

const session = (over: Partial<SleepSession>): SleepSession => ({
  id: 'x',
  userId: 'u',
  startedAt: new Date('2026-01-10T23:00:00Z'),
  endedAt: new Date('2026-01-11T05:00:00Z'),
  nightDate: '2026-01-10',
  durationMinutes: 360,
  movementEvents: 6,
  soundEvents: 0,
  createdAt: new Date(),
  ...over,
});

describe('calmScore (göreli, 0-100)', () => {
  it('rahatsızlık yoksa 100', () => {
    expect(calmScore(360, 0)).toBe(100);
  });
  it('daha çok rahatsızlık → daha düşük skor', () => {
    expect(calmScore(360, 60)).toBeLessThan(calmScore(360, 6));
  });
  it('0-100 arasına sıkıştırır', () => {
    expect(calmScore(30, 10_000)).toBe(0);
    expect(calmScore(600, 0)).toBe(100);
  });
});

describe('buildNightReport', () => {
  it('oturum yoksa null', () => {
    expect(buildNightReport('2026-01-10', [])).toBeNull();
  });

  it('birden çok oturumu toplar', () => {
    const report = buildNightReport('2026-01-10', [
      session({ durationMinutes: 300, movementEvents: 4, soundEvents: 1 }),
      session({ durationMinutes: 60, movementEvents: 2, soundEvents: 1 }),
    ]);
    expect(report).not.toBeNull();
    expect(report!.sessionCount).toBe(2);
    expect(report!.totalDurationMinutes).toBe(360);
    expect(report!.movementEvents).toBe(6);
    expect(report!.soundEvents).toBe(2);
    expect(report!.calmScore).toBeGreaterThanOrEqual(0);
    expect(report!.calmScore).toBeLessThanOrEqual(100);
  });
});
