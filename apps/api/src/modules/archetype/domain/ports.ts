import type { Answers, ArchetypeSlug, Scores } from './archetype';

export interface ArchetypeResult {
  readonly userId: string;
  readonly archetypeSlug: ArchetypeSlug;
  readonly scores: Scores;
  readonly version: number;
  readonly createdAt: Date;
}

export interface SaveArchetypeResult {
  readonly archetypeSlug: ArchetypeSlug;
  readonly answers: Answers;
  readonly scores: Scores;
  readonly version: number;
}

/** archetype_results erişimi — userId ile scope'lu (docs/02 §2.1). */
export interface ArchetypeResultRepository {
  save(userId: string, result: SaveArchetypeResult): Promise<ArchetypeResult>;
  findLatestByUserId(userId: string): Promise<ArchetypeResult | null>;
}

export const ARCHETYPE_RESULT_REPOSITORY = Symbol('ArchetypeResultRepository');
