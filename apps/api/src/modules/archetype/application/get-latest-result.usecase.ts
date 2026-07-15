import type { ArchetypeResult, ArchetypeResultRepository } from '../domain/ports';

/** Kullanıcının en yeni archetype sonucu (yoksa null). */
export class GetLatestResultUseCase {
  constructor(private readonly results: ArchetypeResultRepository) {}

  execute(userId: string): Promise<ArchetypeResult | null> {
    return this.results.findLatestByUserId(userId);
  }
}
