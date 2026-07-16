import { weeklyTrend } from '../../src/modules/sleep/domain/trend';
import type { SleepSession } from '../../src/modules/sleep/domain/sleep-session.entity';

/** Test oturumu — trend yalnızca nightDate + durationMinutes kullanır. */
function session(nightDate: string, durationMinutes: number): SleepSession {
  return {
    id: `s-${nightDate}-${durationMinutes}`,
    userId: 'u-1',
    startedAt: new Date('2026-01-01T22:00:00.000Z'),
    endedAt: new Date('2026-01-02T04:00:00.000Z'),
    nightDate,
    durationMinutes,
    movementEvents: 0,
    soundEvents: 0,
    createdAt: new Date('2026-01-02T04:00:00.000Z'),
  };
}

describe('weeklyTrend', () => {
  it('oturum yoksa 7 gece 0 döner, ortalama 0', () => {
    const trend = weeklyTrend([], '2026-07-15');
    expect(trend.nights).toHaveLength(7);
    expect(trend.nights.map((n) => n.durationMinutes)).toEqual([0, 0, 0, 0, 0, 0, 0]);
    expect(trend.nights[0]?.nightDate).toBe('2026-07-09'); // today-6
    expect(trend.nights[6]?.nightDate).toBe('2026-07-15'); // today
    expect(trend.averageDurationMinutes).toBe(0);
    expect(trend.nightsWithData).toBe(0);
  });

  it('geceler eskiden yeniye sıralı; veri olan geceler dolar', () => {
    const trend = weeklyTrend(
      [session('2026-07-15', 420), session('2026-07-13', 480)],
      '2026-07-15',
    );
    const byDate = Object.fromEntries(trend.nights.map((n) => [n.nightDate, n.durationMinutes]));
    expect(byDate['2026-07-15']).toBe(420);
    expect(byDate['2026-07-13']).toBe(480);
    expect(byDate['2026-07-14']).toBe(0); // veri yok
    // ortalama yalnızca veri olan 2 gece üzerinden: (420+480)/2 = 450
    expect(trend.averageDurationMinutes).toBe(450);
    expect(trend.nightsWithData).toBe(2);
  });

  it('aynı gecede birden fazla oturum toplanır', () => {
    const trend = weeklyTrend(
      [session('2026-07-15', 120), session('2026-07-15', 300)],
      '2026-07-15',
    );
    const last = trend.nights[6];
    expect(last?.nightDate).toBe('2026-07-15');
    expect(last?.durationMinutes).toBe(420);
    expect(trend.nightsWithData).toBe(1); // tek gece
    expect(trend.averageDurationMinutes).toBe(420);
  });

  it('pencere dışındaki oturumlar yok sayılır', () => {
    const trend = weeklyTrend(
      [session('2026-07-01', 999), session('2026-07-15', 400)],
      '2026-07-15',
    );
    expect(trend.nights).toHaveLength(7);
    expect(trend.nights.some((n) => n.nightDate === '2026-07-01')).toBe(false);
    expect(trend.nightsWithData).toBe(1);
    expect(trend.averageDurationMinutes).toBe(400);
  });

  it('ay sınırını doğru geçer (7 ardışık gece)', () => {
    const trend = weeklyTrend([], '2026-08-02');
    expect(trend.nights.map((n) => n.nightDate)).toEqual([
      '2026-07-27',
      '2026-07-28',
      '2026-07-29',
      '2026-07-30',
      '2026-07-31',
      '2026-08-01',
      '2026-08-02',
    ]);
  });
});
