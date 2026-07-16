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
  /**
   * Kullanıcının TÜM sonuçları, yeniden eskiye. Sınır YOK (bilinçli): testi
   * tekrar etmek kayıt üretir ve kimlik geçmişi kullanıcının kendi verisidir —
   * kırpmak sessizce eksik geçmiş göstermek olurdu. Hacim küçük (test başına 1).
   */
  listByUserId(userId: string): Promise<ArchetypeResult[]>;
}

export const ARCHETYPE_RESULT_REPOSITORY = Symbol('ArchetypeResultRepository');
