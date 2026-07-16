import 'reflect-metadata';
import { ForbiddenException, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from '../../src/modules/identity/presentation/roles.guard';

/**
 * RolesGuard karar dalları. e2e yalnızca "gerçek istek" yolunu kanıtlar; buradaki
 * iki dal (metadata yok / metadata boş) e2e'den görünmez ama davranışları bilinçli
 * tasarım kararlarıdır — sabitlenmezse sessizce tersine dönebilirler.
 */
describe('RolesGuard', () => {
  const contextWith = (
    roles: string[] | undefined,
    aud: 'app' | 'admin' = 'admin',
  ): ExecutionContext =>
    ({
      switchToHttp: () => ({
        getRequest: () => (roles ? { user: { sub: 'u1', roles, aud } } : {}),
      }),
      getHandler: () => () => undefined,
      getClass: () => class {},
    }) as unknown as ExecutionContext;

  const guardFor = (required: readonly string[] | undefined): RolesGuard => {
    const reflector = new Reflector();
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(required);
    return new RolesGuard(reflector);
  };

  it('@Roles yoksa karar vermez (kapıyı AuthGuard tutar)', () => {
    expect(guardFor(undefined).canActivate(contextWith(['owner']))).toBe(true);
  });

  it('@Roles() BOŞSA reddeder — "herkes girsin" demek değil, programlama hatasıdır', () => {
    expect(() => guardFor([]).canActivate(contextWith(['owner']))).toThrow(ForbiddenException);
  });

  it('istenen rollerden herhangi biri yeterlidir', () => {
    expect(guardFor(['owner', 'editor']).canActivate(contextWith(['editor']))).toBe(true);
  });

  it('rol yoksa reddeder', () => {
    expect(() => guardFor(['owner']).canActivate(contextWith([]))).toThrow(ForbiddenException);
  });

  it('rol yeterli ama audience "app" → reddeder (mobil token panel anahtarı değildir)', () => {
    expect(() => guardFor(['owner']).canActivate(contextWith(['owner'], 'app'))).toThrow(
      ForbiddenException,
    );
  });

  it('req.user hiç yoksa reddeder (guard sırası yanlış kurulmuşsa AÇIK BIRAKMAZ)', () => {
    expect(() => guardFor(['owner']).canActivate(contextWith(undefined))).toThrow(
      ForbiddenException,
    );
  });
});
