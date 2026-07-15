import { GetFeedUseCase } from '../../src/modules/content/application/get-feed.usecase';
import { InMemoryCache } from '../../src/shared/cache/in-memory-cache';
import type {
  ContentRepository,
  Soundscape,
  SoundscapeDetail,
  WeeklyRelease,
} from '../../src/modules/content/domain/soundscape';

const s = (slug: string, affinity: string[]): Soundscape => ({
  id: slug,
  slug,
  titleI18n: {},
  engineParams: {},
  layerDefs: {},
  archetypeAffinity: affinity,
  version: 1,
});

/** findPublished çağrılarını sayan sahte repo; diğer metodlar kullanılmaz. */
class CountingRepo implements ContentRepository {
  calls = 0;
  constructor(private readonly data: Soundscape[]) {}
  async findPublished(): Promise<Soundscape[]> {
    this.calls++;
    return this.data;
  }
  findPublishedBySlug(): Promise<SoundscapeDetail | null> {
    throw new Error('kullanılmaz');
  }
  findLatestWeeklyRelease(): Promise<WeeklyRelease | null> {
    throw new Error('kullanılmaz');
  }
}

describe('GetFeedUseCase cache', () => {
  const data = [s('a', ['deep-ocean']), s('b', ['overthinker'])];

  it('aynı archetype ikinci çağrıda cache’ten döner (repo tek kez)', async () => {
    const repo = new CountingRepo(data);
    const feed = new GetFeedUseCase(repo, new InMemoryCache());

    const first = await feed.execute('overthinker');
    const second = await feed.execute('overthinker');

    expect(first.map((x) => x.slug)).toEqual(['b', 'a']); // affinity sıralı
    expect(second).toEqual(first);
    expect(repo.calls).toBe(1); // ikinci çağrı DB'ye gitmedi
  });

  it('farklı archetype ayrı anahtar → repo yeniden çağrılır', async () => {
    const repo = new CountingRepo(data);
    const feed = new GetFeedUseCase(repo, new InMemoryCache());

    await feed.execute('overthinker');
    await feed.execute('deep-ocean');

    expect(repo.calls).toBe(2);
  });

  it('TTL (5dk) geçince yeniden sorgulanır', async () => {
    let now = 0;
    const repo = new CountingRepo(data);
    const feed = new GetFeedUseCase(repo, new InMemoryCache(() => now));

    await feed.execute(undefined);
    now = 300_000; // tam 5dk → süre doldu (<=)
    await feed.execute(undefined);

    expect(repo.calls).toBe(2);
  });
});
