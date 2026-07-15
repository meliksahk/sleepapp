import type { ContentRepository, SoundscapeDetail } from '../domain/soundscape';

/** Yayınlanmış tek soundscape + preset'leri (yoksa null). */
export class GetSoundscapeUseCase {
  constructor(private readonly content: ContentRepository) {}

  execute(slug: string): Promise<SoundscapeDetail | null> {
    return this.content.findPublishedBySlug(slug);
  }
}
