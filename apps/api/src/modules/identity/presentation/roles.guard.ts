import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { AdminRole } from '../domain/roles';
import { ROLES_METADATA_KEY } from './roles.decorator';
import type { AuthedRequest } from './auth.guard';

/**
 * Rol zorlama — `@Roles(...)` ile işaretli handler'lara YALNIZCA o rollerden en az
 * birine sahip çağıran girebilir. `AuthGuard`'DAN SONRA çalışmalıdır (req.user'a
 * ihtiyaç duyar): `@UseGuards(AuthGuard, RolesGuard)`.
 *
 * NEDEN: roller şimdiye dek JWT'ye basılıyor ve request'e ekleniyordu ama HİÇBİR
 * yerde kontrol edilmiyordu (#112'de fark edildi). CLAUDE.md §3.3: "Her sayfa ve
 * her mutation server-side rol kontrolünden geçer — yalnızca UI gizleme yeterli
 * değildir." Bu guard o cümlenin sunucu tarafındaki karşılığıdır.
 *
 * VARSAYILAN GÜVENLİ: metadata yoksa guard karar vermez (true) — kapıyı AuthGuard
 * tutar. Ama metadata VARSA ve boşsa, bu bir programlama hatasıdır: "@Roles()"
 * yazıp herkesi içeri almak sessiz bir açık olurdu → açıkça reddedilir.
 *
 * AUDIENCE: `@Roles` yalnızca `AdminRole` alır (tip zorlar) → böyle işaretli her
 * handler tanım gereği bir PANEL handler'ıdır ve `aud: 'admin'` ister. Bu, JWT'nin
 * `aud` iddiasının belgelenmiş amacıdır ("mobil/admin token'ı karışmasını önler")
 * — #113'e dek iddia basılıyordu ama HİÇBİR yerde kontrol edilmiyordu. Etkisi:
 * cihazda saklanan uzun ömürlü mobil token, admin yetkisi taşıyabiliyordu.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<readonly AdminRole[] | undefined>(
      ROLES_METADATA_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (required === undefined) return true;
    if (required.length === 0) {
      throw new ForbiddenException('Bu kaynak için rol tanımlanmamış.');
    }

    const req = context.switchToHttp().getRequest<AuthedRequest>();
    if (req.user?.aud !== 'admin') {
      throw new ForbiddenException('Bu işlem için panel oturumu gerekli.');
    }
    const held = req.user.roles;
    if (!required.some((role) => held.includes(role))) {
      throw new ForbiddenException('Bu işlem için yetkiniz yok.');
    }
    return true;
  }
}
