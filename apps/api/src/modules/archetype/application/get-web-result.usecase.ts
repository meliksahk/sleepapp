import type { WebArchetypeResult, WebArchetypeResultRepository } from '../domain/web';

/** Paylaşım slug'ıyla anonim web sonucu (yoksa null). Public — /a/{...} + OG. */
export class GetWebResultUseCase {
  constructor(private readonly results: WebArchetypeResultRepository) {}

  execute(shareSlug: string): Promise<WebArchetypeResult | null> {
    return this.results.findBySlug(shareSlug);
  }
}
