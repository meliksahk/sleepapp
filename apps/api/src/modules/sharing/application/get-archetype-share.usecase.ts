import type { ArchetypeResultReader } from '../domain/ports';
import { buildArchetypeShare, type ArchetypeShare, type ShareUrls } from '../domain/share';

/** Kullanıcının archetype sonucundan paylaşım kartı üretir; sonuç yoksa null. */
export class GetArchetypeShareUseCase {
  constructor(
    private readonly reader: ArchetypeResultReader,
    private readonly urls: ShareUrls,
  ) {}

  async execute(userId: string): Promise<ArchetypeShare | null> {
    const result = await this.reader.latestFor(userId);
    if (!result) return null;
    return buildArchetypeShare(result.archetypeSlug, this.urls);
  }
}
