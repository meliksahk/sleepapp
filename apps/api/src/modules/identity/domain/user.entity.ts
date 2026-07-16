/** Kullanıcı türü (docs/02 §3 users.kind). */
export type UserKind = 'anonymous' | 'registered' | 'admin';

/** Saf domain entity — Nest/IO bağımsız (boundary kuralı: domain hiçbir şey import etmez). */
export interface User {
  readonly id: string;
  readonly kind: UserKind;
  readonly roles: readonly string[];
  readonly createdAt: Date;
}

/**
 * Token audience'ı KULLANICI TÜRÜNDEN türetilir — çağıranın seçimine bırakılmaz.
 * Neden: "hangi aud?" sorusunu her çağrı yerinde yeniden yanıtlamak, bir yerde
 * yanlış yanıtlamak demektir. Admin hesabı (kind='admin') panel oturumu açar;
 * cihaz akışı daima 'anonymous' üretir → mobil token asla 'admin' olamaz.
 */
export function audienceForKind(kind: UserKind): 'app' | 'admin' {
  return kind === 'admin' ? 'admin' : 'app';
}

/** Anonim cihaz kaydı girdisi. */
export interface DeviceRegistration {
  readonly fingerprint: string;
  readonly platform: string;
}

export type OttPurpose = 'magic_link' | 'email_verify' | 'password_reset';

/** Tek kullanımlık token (magic link vb.). email: magic_link hedefi (verify'de uygulanır). */
export interface OneTimeTokenRecord {
  readonly id: string;
  readonly userId: string;
  readonly email: string | null;
  readonly purpose: OttPurpose;
  readonly tokenHash: string;
  readonly expiresAt: Date;
  readonly usedAt: Date | null;
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

/** Aktif oturum özeti (cihaz listesi) — token HİÇ dışa verilmez. */
export interface ActiveSessionInfo {
  readonly familyId: string;
  readonly createdAt: Date;
  readonly expiresAt: Date;
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
