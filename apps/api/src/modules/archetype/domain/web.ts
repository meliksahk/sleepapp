import type { ArchetypeSlug, Scores } from './archetype';

/** Anonim web testi sonucu (kullanıcı yok; paylaşım slug'ı ile erişilir). */
export interface WebArchetypeResult {
  readonly shareSlug: string;
  readonly archetypeSlug: ArchetypeSlug;
  readonly scores: Scores;
  readonly version: number;
  readonly createdAt: Date;
}

export interface SaveWebArchetypeResult {
  readonly shareSlug: string;
  readonly archetypeSlug: ArchetypeSlug;
  readonly scores: Scores;
  readonly version: number;
}

export interface WebArchetypeResultRepository {
  save(result: SaveWebArchetypeResult): Promise<WebArchetypeResult>;
  findBySlug(shareSlug: string): Promise<WebArchetypeResult | null>;
}

/** Kısa, URL-güvenli paylaşım slug'ı üretir. */
export interface SlugGenerator {
  generate(): string;
}

export const WEB_ARCHETYPE_RESULT_REPOSITORY = Symbol('WebArchetypeResultRepository');
export const SLUG_GENERATOR = Symbol('SlugGenerator');
