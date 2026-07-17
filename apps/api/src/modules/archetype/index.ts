// Archetype modülü public API (barrel) — modüller-arası tek kapı (CLAUDE.md §2).
export { ArchetypeModule } from './archetype.module';
export { GetLatestResultUseCase } from './application/get-latest-result.usecase';
export { ListResultsUseCase } from './application/list-results.usecase';
export type { ArchetypeResult } from './domain/ports';
