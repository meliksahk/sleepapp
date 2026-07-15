import type { IssuedSession, RefreshTokenRecord } from '../domain/user.entity';
import type {
  AccessTokenSigner,
  Clock,
  IdGenerator,
  OpaqueTokenGenerator,
  RefreshTokenRepository,
  TokenHasher,
} from '../domain/ports';

export interface SessionMinterConfig {
  readonly accessTokenTtl: number;
  readonly refreshTokenTtl: number;
}

/**
 * Access JWT + opak refresh token çifti üretir ve refresh token'ı hash'leyip
 * verilen family altında kaydeder. register + refresh akışlarının ortak çekirdeği.
 */
export class SessionMinter {
  constructor(
    private readonly signer: AccessTokenSigner,
    private readonly hasher: TokenHasher,
    private readonly opaque: OpaqueTokenGenerator,
    private readonly ids: IdGenerator,
    private readonly clock: Clock,
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly config: SessionMinterConfig,
  ) {}

  async mint(params: {
    userId: string;
    roles: readonly string[];
    familyId: string;
  }): Promise<IssuedSession> {
    const now = this.clock.now();
    const accessToken = await this.signer.sign(
      { sub: params.userId, roles: params.roles, aud: 'app' },
      this.config.accessTokenTtl,
    );

    const rawRefresh = this.opaque.generate();
    const record: RefreshTokenRecord = {
      id: this.ids.uuid(),
      userId: params.userId,
      tokenHash: this.hasher.hash(rawRefresh),
      familyId: params.familyId,
      expiresAt: new Date(now.getTime() + this.config.refreshTokenTtl * 1000),
      revokedAt: null,
      createdAt: now,
    };
    await this.refreshTokens.save(record);

    return {
      accessToken,
      refreshToken: rawRefresh,
      accessTokenExpiresIn: this.config.accessTokenTtl,
      userId: params.userId,
    };
  }
}
