import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import type { Request } from 'express';
import type { AccessTokenClaims } from '../domain/user.entity';
import { AuthorizeUseCase } from '../application/authorize.usecase';

export interface AuthedRequest extends Request {
  user?: AccessTokenClaims;
}

/**
 * Bearer access token doğrular ve { sub, roles } context'ini request'e ekler.
 * Diğer modüller yalnızca bu context'i kullanır; JWT/kripto koduna dokunmaz.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly authorize: AuthorizeUseCase) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Bearer token gerekli.');
    }
    const token = header.slice('Bearer '.length).trim();
    try {
      req.user = await this.authorize.execute(token);
      return true;
    } catch {
      throw new UnauthorizedException('Access token geçersiz.');
    }
  }
}
