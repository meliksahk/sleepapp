// identity public API — diğer modüller YALNIZCA buradan tüketir (docs/02 §2 boundary).
export { IdentityModule } from './identity.module';
export { AuthGuard, type AuthedRequest } from './presentation/auth.guard';
export { CurrentUser } from './presentation/current-user.decorator';
export type { AccessTokenClaims } from './domain/user.entity';
