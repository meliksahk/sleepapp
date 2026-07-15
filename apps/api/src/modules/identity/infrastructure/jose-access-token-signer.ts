import {
  SignJWT,
  jwtVerify,
  importPKCS8,
  importSPKI,
  generateKeyPair,
  exportPKCS8,
  exportSPKI,
  type KeyLike,
} from 'jose';
import type { AccessTokenClaims } from '../domain/user.entity';
import type { AccessTokenSigner } from '../domain/ports';

const ALG = 'RS256';
const ISSUER = 'nocta';

/**
 * RS256 access token imzalama/doğrulama (jose). Kripto YALNIZCA identity'de
 * (docs/02 §2.1). Anahtarlar env'den PEM olarak gelir; development'ta yoksa
 * ephemeral üretilir (uyarı loglanır — üretimde ASLA olmamalı).
 */
export class JoseAccessTokenSigner implements AccessTokenSigner {
  private constructor(
    private readonly privateKey: KeyLike,
    private readonly publicKey: KeyLike,
  ) {}

  static async create(pem?: {
    privateKey?: string;
    publicKey?: string;
    allowEphemeral?: boolean;
  }): Promise<JoseAccessTokenSigner> {
    if (pem?.privateKey && pem.publicKey) {
      const priv = await importPKCS8(pem.privateKey, ALG);
      const pub = await importSPKI(pem.publicKey, ALG);
      return new JoseAccessTokenSigner(priv, pub);
    }
    if (!pem?.allowEphemeral) {
      throw new Error(
        'JWT_PRIVATE_KEY/JWT_PUBLIC_KEY tanımlı değil ve ephemeral anahtara izin yok (production).',
      );
    }
    const { privateKey, publicKey } = await generateKeyPair(ALG, { extractable: true });
    // Ephemeral anahtar: yalnızca lokal/dev. Round-trip için import edilmiş halini kullan.
    const priv = await importPKCS8(await exportPKCS8(privateKey), ALG);
    const pub = await importSPKI(await exportSPKI(publicKey), ALG);
    console.warn('[identity] EPHEMERAL RS256 anahtarı üretildi — yalnızca development.');
    return new JoseAccessTokenSigner(priv, pub);
  }

  async sign(claims: AccessTokenClaims, ttlSeconds: number): Promise<string> {
    return new SignJWT({ roles: claims.roles })
      .setProtectedHeader({ alg: ALG })
      .setSubject(claims.sub)
      .setAudience(claims.aud)
      .setIssuer(ISSUER)
      .setIssuedAt()
      .setExpirationTime(`${ttlSeconds}s`)
      .sign(this.privateKey);
  }

  async verify(token: string): Promise<AccessTokenClaims> {
    const { payload } = await jwtVerify(token, this.publicKey, {
      issuer: ISSUER,
      audience: ['app', 'admin'],
    });
    const aud = Array.isArray(payload.aud) ? payload.aud[0] : payload.aud;
    return {
      sub: String(payload.sub),
      roles: Array.isArray(payload.roles) ? (payload.roles as string[]) : [],
      aud: aud === 'admin' ? 'admin' : 'app',
    };
  }
}
