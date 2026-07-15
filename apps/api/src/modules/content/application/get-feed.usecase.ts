import type { Cache } from '../../../shared/cache/cache.port';
import { sortByAffinity, type ContentRepository, type Soundscape } from '../domain/soundscape';

/**
 * Yayınlanmış soundscape feed'i, archetype affinity'ye göre sıralı.
 * Global içerik (kullanıcıya özel değil) → archetype başına cache'lenir (5dk).
 * Feed presigned URL içermez (onlar detay ucunda) → TTL ile güvenli.
 */
export class GetFeedUseCase {
  private static readonly TTL_SECONDS = 300; // 5 dk (docs/02 B4)

  constructor(
    private readonly content: ContentRepository,
    private readonly cache: Cache,
  ) {}

  async execute(archetype: string | undefined): Promise<Soundscape[]> {
    const key = `content:feed:${archetype ?? 'all'}`;
    const cached = await this.cache.get<Soundscape[]>(key);
    if (cached) return cached;

    const published = await this.content.findPublished();
    const sorted = sortByAffinity(published, archetype);
    await this.cache.set(key, sorted, GetFeedUseCase.TTL_SECONDS);
    return sorted;
  }
}
