import { computeStreak } from '../../src/modules/sleep/domain/streak';

describe('computeStreak', () => {
  it('kayıt yoksa hepsi 0', () => {
    expect(computeStreak([], '2026-03-10')).toEqual({ current: 0, longest: 0, totalNights: 0 });
  });

  it('bugüne kadar süren ardışık seri', () => {
    const dates = ['2026-03-08', '2026-03-09', '2026-03-10'];
    expect(computeStreak(dates, '2026-03-10')).toEqual({
      current: 3,
      longest: 3,
      totalNights: 3,
    });
  });

  it('son gece dün ise seri hâlâ canlı (bugün henüz uyunmadı)', () => {
    const dates = ['2026-03-08', '2026-03-09'];
    expect(computeStreak(dates, '2026-03-10').current).toBe(2);
  });

  it('son gece dünden eskiyse seri kopmuş (current 0)', () => {
    const dates = ['2026-03-05', '2026-03-06'];
    const r = computeStreak(dates, '2026-03-10');
    expect(r.current).toBe(0);
    expect(r.longest).toBe(2);
    expect(r.totalNights).toBe(2);
  });

  it('boşluklu geçmiş: longest > current', () => {
    // 4 ardışık (eski), sonra boşluk, sonra 2 (bugüne kadar)
    const dates = [
      '2026-01-01',
      '2026-01-02',
      '2026-01-03',
      '2026-01-04',
      '2026-03-09',
      '2026-03-10',
    ];
    const r = computeStreak(dates, '2026-03-10');
    expect(r.longest).toBe(4);
    expect(r.current).toBe(2);
    expect(r.totalNights).toBe(6);
  });

  it('tekrar eden tarihler benzersizleştirilir', () => {
    const dates = ['2026-03-10', '2026-03-10', '2026-03-09'];
    const r = computeStreak(dates, '2026-03-10');
    expect(r.totalNights).toBe(2);
    expect(r.current).toBe(2);
  });

  it('ay sınırı ardışıklığı doğru (31 Oca → 1 Şub)', () => {
    const dates = ['2026-01-31', '2026-02-01'];
    expect(computeStreak(dates, '2026-02-01').current).toBe(2);
  });
});
