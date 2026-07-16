import { ListSleepSessionsUseCase } from '../../src/modules/sleep/application/list-sleep-sessions.usecase';
import type { SleepSessionRepository } from '../../src/modules/sleep/domain/ports';
import type { SleepSession } from '../../src/modules/sleep/domain/sleep-session.entity';

class SpyRepo implements SleepSessionRepository {
  recentLimit?: number;
  range?: { from: string; to: string };
  save(): Promise<SleepSession> {
    throw new Error('kullanılmaz');
  }
  async listRecentByUser(_userId: string, limit: number): Promise<SleepSession[]> {
    this.recentLimit = limit;
    return [];
  }
  findByNight(): Promise<SleepSession[]> {
    throw new Error('kullanılmaz');
  }
  listNightDates(): Promise<string[]> {
    throw new Error('kullanılmaz');
  }
  async listByNightRange(_userId: string, from: string, to: string): Promise<SleepSession[]> {
    this.range = { from, to };
    return [];
  }
}

describe('ListSleepSessionsUseCase', () => {
  it('from+to → aralık sorgusu', async () => {
    const repo = new SpyRepo();
    await new ListSleepSessionsUseCase(repo).execute('u', { from: '2026-07-01', to: '2026-07-31' });
    expect(repo.range).toEqual({ from: '2026-07-01', to: '2026-07-31' });
    expect(repo.recentLimit).toBeUndefined();
  });

  it('aralık yoksa → recent (limit varsayılan 30, 1-100 clamp)', async () => {
    const repo = new SpyRepo();
    await new ListSleepSessionsUseCase(repo).execute('u');
    expect(repo.recentLimit).toBe(30);

    await new ListSleepSessionsUseCase(repo).execute('u', { limit: 999 });
    expect(repo.recentLimit).toBe(100); // clamp
    await new ListSleepSessionsUseCase(repo).execute('u', { limit: 0 });
    expect(repo.recentLimit).toBe(1); // clamp
  });

  it('yalnızca from (to yok) → aralık DEĞİL, recent', async () => {
    const repo = new SpyRepo();
    await new ListSleepSessionsUseCase(repo).execute('u', { from: '2026-07-01' });
    expect(repo.range).toBeUndefined();
    expect(repo.recentLimit).toBe(30);
  });
});
