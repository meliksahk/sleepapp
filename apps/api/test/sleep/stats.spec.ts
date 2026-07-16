import { aggregateStats } from '../../src/modules/sleep/domain/stats';
import type { SleepSession } from '../../src/modules/sleep/domain/sleep-session.entity';

const s = (nightDate: string, durationMinutes: number): SleepSession => ({
  id: `${nightDate}-${durationMinutes}`,
  userId: 'u',
  startedAt: new Date(),
  endedAt: new Date(),
  nightDate,
  durationMinutes,
  movementEvents: 0,
  soundEvents: 0,
  createdAt: new Date(),
});

describe('aggregateStats', () => {
  it('oturum yoksa hepsi 0', () => {
    expect(aggregateStats([])).toEqual({
      nights: 0,
      totalDurationMinutes: 0,
      averageDurationMinutes: 0,
    });
  });

  it('gece sayısı benzersiz, toplam + ortalama (yuvarlanmış)', () => {
    const stats = aggregateStats([
      s('2026-03-10', 400),
      s('2026-03-10', 20), // aynı gece (nap) → nights tekil
      s('2026-03-09', 480),
    ]);
    expect(stats.nights).toBe(2); // 2026-03-10 + 2026-03-09
    expect(stats.totalDurationMinutes).toBe(900);
    expect(stats.averageDurationMinutes).toBe(300); // 900/3
  });

  it('ortalama yuvarlar', () => {
    const stats = aggregateStats([s('2026-03-10', 100), s('2026-03-11', 101)]);
    expect(stats.averageDurationMinutes).toBe(101); // 201/2 = 100.5 → 101
  });
});
