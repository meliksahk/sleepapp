import { sortByAffinity, type ContentRepository, type Soundscape } from '../domain/soundscape';

/** Yayınlanmış soundscape feed'i, archetype affinity'ye göre sıralı. */
export class GetFeedUseCase {
  constructor(private readonly content: ContentRepository) {}

  async execute(archetype: string | undefined): Promise<Soundscape[]> {
    const published = await this.content.findPublished();
    return sortByAffinity(published, archetype);
  }
}
