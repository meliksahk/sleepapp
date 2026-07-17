// identity public API — diğer modüller YALNIZCA buradan tüketir (docs/02 §2 boundary).
export { IdentityModule } from './identity.module';
export { AuthGuard, type AuthedRequest } from './presentation/auth.guard';
export { RolesGuard } from './presentation/roles.guard';
export { Roles } from './presentation/roles.decorator';
export { CurrentUser } from './presentation/current-user.decorator';
export { ADMIN_ROLES, isAdminRole, type AdminRole } from './domain/roles';
export type { AccessTokenClaims } from './domain/user.entity';
export { GetActiveSessionsUseCase } from './application/get-active-sessions.usecase';
export type { ActiveSessionInfo } from './domain/user.entity';
