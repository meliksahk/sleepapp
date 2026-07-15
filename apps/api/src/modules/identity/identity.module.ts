import { Module, type Provider } from '@nestjs/common';
import { ENV, loadEnv, type Env } from '../../shared/config/env';
import {
  ACCESS_TOKEN_SIGNER,
  CLOCK,
  ID_GENERATOR,
  OPAQUE_TOKEN_GENERATOR,
  REFRESH_TOKEN_REPOSITORY,
  TOKEN_HASHER,
  USER_REPOSITORY,
  type AccessTokenSigner,
  type Clock,
  type IdGenerator,
  type OpaqueTokenGenerator,
  type RefreshTokenRepository,
  type TokenHasher,
  type UserRepository,
} from './domain/ports';
import {
  RandomOpaqueTokenGenerator,
  Sha256TokenHasher,
  SystemClock,
  UuidIdGenerator,
} from './infrastructure/crypto-adapters';
import { JoseAccessTokenSigner } from './infrastructure/jose-access-token-signer';
import { PrismaService } from '../../shared/infra/prisma.service';
import { PrismaUserRepository } from './infrastructure/prisma/prisma-user.repository';
import { PrismaRefreshTokenRepository } from './infrastructure/prisma/prisma-refresh-token.repository';
import { SessionMinter } from './application/session-minter';
import { RegisterDeviceUseCase } from './application/register-device.usecase';
import { RefreshSessionUseCase } from './application/refresh-session.usecase';
import { AuthorizeUseCase } from './application/authorize.usecase';
import { AuthController } from './presentation/auth.controller';
import { AuthGuard } from './presentation/auth.guard';

const providers: Provider[] = [
  { provide: ENV, useFactory: (): Env => loadEnv() },
  { provide: CLOCK, useClass: SystemClock },
  { provide: ID_GENERATOR, useClass: UuidIdGenerator },
  { provide: OPAQUE_TOKEN_GENERATOR, useClass: RandomOpaqueTokenGenerator },
  { provide: TOKEN_HASHER, useClass: Sha256TokenHasher },
  // Gerçek Postgres adaptörleri (Prisma). In-memory sürümler yalnızca unit-test harness'ında.
  PrismaService,
  {
    provide: USER_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): UserRepository => new PrismaUserRepository(prisma),
  },
  {
    provide: REFRESH_TOKEN_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): RefreshTokenRepository =>
      new PrismaRefreshTokenRepository(prisma),
  },
  {
    provide: ACCESS_TOKEN_SIGNER,
    inject: [ENV],
    useFactory: (env: Env): Promise<JoseAccessTokenSigner> =>
      JoseAccessTokenSigner.create({
        privateKey: env.JWT_PRIVATE_KEY,
        publicKey: env.JWT_PUBLIC_KEY,
        allowEphemeral: env.NODE_ENV !== 'production',
      }),
  },
  {
    provide: SessionMinter,
    inject: [
      ACCESS_TOKEN_SIGNER,
      TOKEN_HASHER,
      OPAQUE_TOKEN_GENERATOR,
      ID_GENERATOR,
      CLOCK,
      REFRESH_TOKEN_REPOSITORY,
      ENV,
    ],
    useFactory: (
      signer: AccessTokenSigner,
      hasher: TokenHasher,
      opaque: OpaqueTokenGenerator,
      ids: IdGenerator,
      clock: Clock,
      refreshTokens: RefreshTokenRepository,
      env: Env,
    ): SessionMinter =>
      new SessionMinter(signer, hasher, opaque, ids, clock, refreshTokens, {
        accessTokenTtl: env.ACCESS_TOKEN_TTL,
        refreshTokenTtl: env.REFRESH_TOKEN_TTL,
      }),
  },
  {
    provide: RegisterDeviceUseCase,
    inject: [USER_REPOSITORY, ID_GENERATOR, CLOCK, SessionMinter],
    useFactory: (
      users: UserRepository,
      ids: IdGenerator,
      clock: Clock,
      sessions: SessionMinter,
    ): RegisterDeviceUseCase => new RegisterDeviceUseCase(users, ids, clock, sessions),
  },
  {
    provide: RefreshSessionUseCase,
    inject: [REFRESH_TOKEN_REPOSITORY, USER_REPOSITORY, TOKEN_HASHER, CLOCK, SessionMinter],
    useFactory: (
      refreshTokens: RefreshTokenRepository,
      users: UserRepository,
      hasher: TokenHasher,
      clock: Clock,
      sessions: SessionMinter,
    ): RefreshSessionUseCase =>
      new RefreshSessionUseCase(refreshTokens, users, hasher, clock, sessions),
  },
  {
    provide: AuthorizeUseCase,
    inject: [ACCESS_TOKEN_SIGNER],
    useFactory: (signer: AccessTokenSigner): AuthorizeUseCase => new AuthorizeUseCase(signer),
  },
  AuthGuard,
];

/**
 * identity — kendi auth sistemimiz. Diğer modüller yalnızca AuthGuard +
 * AuthorizeUseCase'i tüketir (public API); repository/kripto dışa kapalıdır.
 */
@Module({
  controllers: [AuthController],
  providers,
  exports: [AuthGuard, AuthorizeUseCase],
})
export class IdentityModule {}
