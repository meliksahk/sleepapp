import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { AccessTokenClaims } from '../domain/user.entity';
import type { AuthedRequest } from './auth.guard';

/**
 * Doğrulanmış kullanıcı context'ini controller parametresine enjekte eder.
 * Kaynak erişimi DAİMA bu sub üzerinden scope'lanır — istemciden gelen id'ye
 * asla güvenilmez ("A, B'nin verisini okuyamaz", CLAUDE.md §6).
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AccessTokenClaims => {
    const req = ctx.switchToHttp().getRequest<AuthedRequest>();
    if (!req.user) {
      throw new Error('CurrentUser AuthGuard olmadan kullanıldı.');
    }
    return req.user;
  },
);
