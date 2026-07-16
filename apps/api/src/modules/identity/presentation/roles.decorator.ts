import { SetMetadata } from '@nestjs/common';
import type { AdminRole } from '../domain/roles';

export const ROLES_METADATA_KEY = 'nocta:roles';

/**
 * Handler/controller için gereken rolleri işaretler. `RolesGuard` bunu okur.
 * Boş liste ANLAMSIZDIR (hiçbir rol yeterli olmaz) — en az bir rol verilmelidir;
 * guard bunu çalışma zamanında da doğrular (bkz. roles.guard.ts).
 */
export const Roles = (...roles: readonly [AdminRole, ...AdminRole[]]) =>
  SetMetadata(ROLES_METADATA_KEY, roles);
