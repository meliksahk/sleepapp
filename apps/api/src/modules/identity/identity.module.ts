import { Module, type Provider } from '@nestjs/common';
import { ENV, loadEnv, type Env } from '../../shared/config/env';
import {
  ACCESS_TOKEN_SIGNER,
  CLOCK,
  ID_GENERATOR,
  MAILER,
  ONE_TIME_TOKEN_REPOSITORY,
  OPAQUE_TOKEN_GENERATOR,
  REFRESH_TOKEN_REPOSITORY,
  TOKEN_HASHER,
  USER_REPOSITORY,
  PASSWORD_HASHER,
  type AccessTokenSigner,
  type Clock,
  type IdGenerator,
  type Mailer,
  type OneTimeTokenRepository,
  type OpaqueTokenGenerator,
  type RefreshTokenRepository,
  type TokenHasher,
  type UserRepository,
  type PasswordHasher,
} from './domain/ports';
import {
  RandomOpaqueTokenGenerator,
  Sha256TokenHasher,
  SystemClock,
  UuidIdGenerator,
} from './infrastructure/crypto-adapters';
import { Argon2idPasswordHasher } from './infrastructure/argon2-password-hasher';
import { JoseAccessTokenSigner } from './infrastructure/jose-access-token-signer';
import { PrismaService } from '../../shared/infra/prisma.service';
import { PrismaUserRepository } from './infrastructure/prisma/prisma-user.repository';
import { PrismaRefreshTokenRepository } from './infrastructure/prisma/prisma-refresh-token.repository';
import { PrismaOneTimeTokenRepository } from './infrastructure/prisma/prisma-one-time-token.repository';
import { LogMailer } from './infrastructure/log-mailer';
import { RequestEmailUpgradeUseCase } from './application/request-email-upgrade.usecase';
import { VerifyEmailUpgradeUseCase } from './application/verify-email-upgrade.usecase';
import { IS_PRODUCTION } from './presentation/tokens';
import { SessionMinter } from './application/session-minter';
import { RegisterDeviceUseCase } from './application/register-device.usecase';
import { RefreshSessionUseCase } from './application/refresh-session.usecase';
import { LoginAdminUseCase } from './application/login-admin.usecase';
import { LogoutUseCase } from './application/logout.usecase';
import { DeleteAccountUseCase } from './application/delete-account.usecase';
import { RevokeOtherSessionsUseCase } from './application/revoke-other-sessions.usecase';
import { GetActiveSessionsUseCase } from './application/get-active-sessions.usecase';
import { AuthorizeUseCase } from './application/authorize.usecase';
import { AuthController } from './presentation/auth.controller';
import { AuthGuard } from './presentation/auth.guard';

const providers: Provider[] = [
  { provide: ENV, useFactory: (): Env => loadEnv() },
  { provide: CLOCK, useClass: SystemClock },
  { provide: ID_GENERATOR, useClass: UuidIdGenerator },
  { provide: OPAQUE_TOKEN_GENERATOR, useClass: RandomOpaqueTokenGenerator },
  { provide: TOKEN_HASHER, useClass: Sha256TokenHasher },
  // Gerçek Postgres adaptörleri (Prisma). PrismaService global PrismaModule'den gelir.
  // In-memory sürümler yalnızca unit-test harness'ında.
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
    provide: PASSWORD_HASHER,
    useClass: Argon2idPasswordHasher,
  },
  {
    provide: LoginAdminUseCase,
    inject: [USER_REPOSITORY, PASSWORD_HASHER, ID_GENERATOR, SessionMinter],
    useFactory: (
      users: UserRepository,
      passwords: PasswordHasher,
      ids: IdGenerator,
      sessions: SessionMinter,
    ): LoginAdminUseCase => new LoginAdminUseCase(users, passwords, ids, sessions),
  },
  {
    provide: LogoutUseCase,
    inject: [REFRESH_TOKEN_REPOSITORY, TOKEN_HASHER, CLOCK],
    useFactory: (
      refreshTokens: RefreshTokenRepository,
      hasher: TokenHasher,
      clock: Clock,
    ): LogoutUseCase => new LogoutUseCase(refreshTokens, hasher, clock),
  },
  {
    provide: DeleteAccountUseCase,
    inject: [USER_REPOSITORY],
    useFactory: (users: UserRepository): DeleteAccountUseCase => new DeleteAccountUseCase(users),
  },
  {
    provide: RevokeOtherSessionsUseCase,
    inject: [REFRESH_TOKEN_REPOSITORY, TOKEN_HASHER, CLOCK],
    useFactory: (
      refreshTokens: RefreshTokenRepository,
      hasher: TokenHasher,
      clock: Clock,
    ): RevokeOtherSessionsUseCase => new RevokeOtherSessionsUseCase(refreshTokens, hasher, clock),
  },
  {
    provide: GetActiveSessionsUseCase,
    inject: [REFRESH_TOKEN_REPOSITORY, CLOCK],
    useFactory: (refreshTokens: RefreshTokenRepository, clock: Clock): GetActiveSessionsUseCase =>
      new GetActiveSessionsUseCase(refreshTokens, clock),
  },
  {
    provide: ONE_TIME_TOKEN_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): OneTimeTokenRepository =>
      new PrismaOneTimeTokenRepository(prisma),
  },
  { provide: MAILER, useClass: LogMailer },
  {
    provide: IS_PRODUCTION,
    inject: [ENV],
    useFactory: (env: Env): boolean => env.NODE_ENV === 'production',
  },
  {
    provide: RequestEmailUpgradeUseCase,
    inject: [
      USER_REPOSITORY,
      ONE_TIME_TOKEN_REPOSITORY,
      MAILER,
      ID_GENERATOR,
      CLOCK,
      TOKEN_HASHER,
      OPAQUE_TOKEN_GENERATOR,
      ENV,
    ],
    useFactory: (
      users: UserRepository,
      ott: OneTimeTokenRepository,
      mailer: Mailer,
      ids: IdGenerator,
      clock: Clock,
      hasher: TokenHasher,
      opaque: OpaqueTokenGenerator,
      env: Env,
    ): RequestEmailUpgradeUseCase =>
      new RequestEmailUpgradeUseCase(users, ott, mailer, ids, clock, hasher, opaque, {
        ttlSeconds: env.MAGIC_LINK_TTL,
        baseUrl: env.MAGIC_LINK_BASE_URL,
      }),
  },
  {
    provide: VerifyEmailUpgradeUseCase,
    inject: [USER_REPOSITORY, ONE_TIME_TOKEN_REPOSITORY, CLOCK, TOKEN_HASHER],
    useFactory: (
      users: UserRepository,
      ott: OneTimeTokenRepository,
      clock: Clock,
      hasher: TokenHasher,
    ): VerifyEmailUpgradeUseCase => new VerifyEmailUpgradeUseCase(users, ott, clock, hasher),
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
