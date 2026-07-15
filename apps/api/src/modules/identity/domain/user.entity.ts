/** Kullanıcı türü (docs/02 §3 users.kind). */
export type UserKind = 'anonymous' | 'registered' | 'admin';

/** Saf domain entity — Nest/IO bağımsız (boundary kuralı: domain hiçbir şey import etmez). */
export interface User {
  readonly id: string;
  readonly kind: UserKind;
  readonly roles: readonly string[];
  readonly createdAt: Date;
}

/** Anonim cihaz kaydı girdisi. */
export interface DeviceRegistration {
  readonly fingerprint: string;
  readonly platform: string;
}

/** DB'de saklanan refresh token kaydı (opak token'ın hash'i). */
export interface RefreshTokenRecord {
  readonly id: string;
  readonly userId: string;
  readonly tokenHash: string;
  readonly familyId: string;
  readonly expiresAt: Date;
  readonly revokedAt: Date | null;
  readonly createdAt: Date;
}

/** Access JWT içindeki iddialar. aud ayrımı mobil/admin token'ı karışmasını önler (docs/02 §2.1). */
export interface AccessTokenClaims {
  readonly sub: string;
  readonly roles: readonly string[];
  readonly aud: 'app' | 'admin';
}

/** Bir oturum akışının döndürdüğü token çifti. */
export interface IssuedSession {
  readonly accessToken: string;
  readonly refreshToken: string;
  readonly accessTokenExpiresIn: number;
  readonly userId: string;
}
