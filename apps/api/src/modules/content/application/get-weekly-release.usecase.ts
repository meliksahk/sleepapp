import type { ContentRepository, WeeklyRelease } from '../domain/soundscape';

/** En güncel haftalık soundscape yayını (yoksa null). */
export class GetWeeklyReleaseUseCase {
  constructor(private readonly content: ContentRepository) {}

  execute(): Promise<WeeklyRelease | null> {
    return this.content.findLatestWeeklyRelease();
  }
}
