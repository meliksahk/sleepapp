import { GetFeedUseCase } from '../../src/modules/content/application/get-feed.usecase';
import { InMemoryCache } from '../../src/shared/cache/in-memory-cache';
import type { UserArchetypeReader } from '../../src/modules/content/domain/user-archetype-reader';
import type {
  AdminSoundscapeView,
  ContentRepository,
  Soundscape,
  SoundscapeSummary,
  SoundscapeDetail,
  WeeklyRelease,
} from '../../src/modules/content/domain/soundscape';

/** Kullanıcının archetype'ını sabitleyen sahte reader. */
const reader = (archetype: string | undefined): UserArchetypeReader => ({
  archetypeFor: async () => archetype,
});

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
  findAllSummaries(): Promise<SoundscapeSummary[]> {
    throw new Error('kullanılmaz');
  }
  createDraft(): Promise<SoundscapeSummary | null> {
    throw new Error('kullanılmaz');
  }
  findAdminBySlug(): Promise<AdminSoundscapeView | null> {
    throw new Error('kullanılmaz');
  }
  setStatus(): Promise<SoundscapeSummary | null> {
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
    const feed = new GetFeedUseCase(repo, new InMemoryCache(), reader(undefined));

    const first = await feed.execute('u-1', 'overthinker');
    const second = await feed.execute('u-1', 'overthinker');

    expect(first.map((x) => x.slug)).toEqual(['b', 'a']); // affinity sıralı
    expect(second).toEqual(first);
    expect(repo.calls).toBe(1); // ikinci çağrı DB'ye gitmedi
  });

  it('farklı archetype ayrı anahtar → repo yeniden çağrılır', async () => {
    const repo = new CountingRepo(data);
    const feed = new GetFeedUseCase(repo, new InMemoryCache(), reader(undefined));

    await feed.execute('u-1', 'overthinker');
    await feed.execute('u-1', 'deep-ocean');

    expect(repo.calls).toBe(2);
  });

  it('TTL (5dk) geçince yeniden sorgulanır', async () => {
    let now = 0;
    const repo = new CountingRepo(data);
    const feed = new GetFeedUseCase(repo, new InMemoryCache(() => now), reader(undefined));

    await feed.execute('u-1');
    now = 300_000; // tam 5dk → süre doldu (<=)
    await feed.execute('u-1');

    expect(repo.calls).toBe(2);
  });

  it('archetype verilmezse kullanıcının kendi sonucuna göre sıralar', async () => {
    const repo = new CountingRepo(data);
    const feed = new GetFeedUseCase(repo, new InMemoryCache(), reader('overthinker'));

    const res = await feed.execute('u-1'); // explicit yok → reader 'overthinker'
    expect(res.map((x) => x.slug)).toEqual(['b', 'a']); // overthinker öne
  });

  it('açık archetype kullanıcının sonucunu geçersiz kılar (göz atma)', async () => {
    const repo = new CountingRepo(data);
    const feed = new GetFeedUseCase(repo, new InMemoryCache(), reader('overthinker'));

    const res = await feed.execute('u-1', 'deep-ocean'); // explicit öncelikli
    expect(res.map((x) => x.slug)).toEqual(['a', 'b']); // deep-ocean öne
  });

  it('kullanıcının sonucu yoksa (undefined) → all (giriş sırası korunur)', async () => {
    const repo = new CountingRepo(data);
    const feed = new GetFeedUseCase(repo, new InMemoryCache(), reader(undefined));

    const res = await feed.execute('u-1');
    expect(res.map((x) => x.slug)).toEqual(['a', 'b']); // sıralama yok → giriş sırası
  });
});
