import { buildNightReport } from '../../src/modules/sleep/domain/report';
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
  });

  // F0: sabit "dinginlik skoru" kaldırıldı — rapor artık yalnızca SAYDIĞI şeyi
  // taşır. Alan geri sızarsa bu test yakalar.
  it('skor alanı TAŞIMAZ (ölçmediğimizi raporlamayız)', () => {
    const report = buildNightReport('2026-01-10', [session({})]);
    expect(report).not.toHaveProperty('calmScore');
  });
});
