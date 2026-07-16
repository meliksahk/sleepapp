import { statsFromAggregate } from '../../src/modules/sleep/domain/stats';

describe('statsFromAggregate', () => {
  it('kayıt yoksa hepsi 0', () => {
    expect(statsFromAggregate({ nights: 0, sessionCount: 0, totalDurationMinutes: 0 })).toEqual({
      nights: 0,
      totalDurationMinutes: 0,
      averageDurationMinutes: 0,
    });
  });

  it('ortalama OTURUM başına hesaplanır (gece başına değil)', () => {
    // 3 oturum / 2 gece (biri nap), toplam 900 dk → 900/3 = 300 (900/2=450 DEĞİL)
    expect(statsFromAggregate({ nights: 2, sessionCount: 3, totalDurationMinutes: 900 })).toEqual({
      nights: 2,
      totalDurationMinutes: 900,
      averageDurationMinutes: 300,
    });
  });

  it('ortalama yuvarlanır', () => {
    // 201/2 = 100.5 → 101
    expect(
      statsFromAggregate({ nights: 2, sessionCount: 2, totalDurationMinutes: 201 })
        .averageDurationMinutes,
    ).toBe(101);
  });

  it('gece sayısı depodan gelir, oturum sayısından bağımsızdır', () => {
    const stats = statsFromAggregate({ nights: 1, sessionCount: 5, totalDurationMinutes: 500 });
    expect(stats.nights).toBe(1); // aynı gecede 5 oturum
    expect(stats.averageDurationMinutes).toBe(100);
  });
});
