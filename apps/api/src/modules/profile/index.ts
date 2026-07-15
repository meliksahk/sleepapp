// Profile modülü public API (barrel) — modüller-arası tek kapı (CLAUDE.md §2).
export { ProfileModule } from './profile.module';
export { GetProfileUseCase } from './application/get-profile.usecase';
export type { Profile } from './domain/profile.entity';
