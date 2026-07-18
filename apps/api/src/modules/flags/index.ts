// flags public API — diğer modüller (admin) YALNIZCA buradan tüketir (docs/02 §2).
export { FlagsModule } from './flags.module';
export { ListAllFlagsUseCase } from './application/list-all-flags.usecase';
export type { Flag, FlagRules } from './domain/flag';
