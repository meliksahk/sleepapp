import type {
  AccessTokenClaims,
  DeviceRegistration,
  OneTimeTokenRecord,
  RefreshTokenRecord,
  User,
} from './user.entity';

/** Zaman kaynağı — test edilebilirlik için soyutlanır. */
export interface Clock {
  now(): Date;
}

/** UUID üretimi. */
export interface IdGenerator {
  uuid(): string;
}

/** Yüksek entropili opak refresh token üretimi. */
export interface OpaqueTokenGenerator {
  generate(): string;
}

/**
 * Deterministik hash — opak refresh token'ı DB'de aramak için (SHA-256).
 * NOT: argon2id (şifreler için) F1'de eklenir; salt'lı olduğu için deterministik
 * lookup'a uygun değildir → refresh token'da SHA-256 kullanılır (docs/02 §2.1).
 */
export interface TokenHasher {
  hash(raw: string): string;
}

/** RS256 access JWT imzalama/doğrulama — kripto YALNIZCA burada (docs/02 §2.1). */
export interface AccessTokenSigner {
  sign(claims: AccessTokenClaims, ttlSeconds: number): Promise<string>;
  verify(token: string): Promise<AccessTokenClaims>;
}

/** users + auth_devices erişimi. Repository userId scope'unu zorunlu kılar (docs/02 §2.1). */
export interface UserRepository {
  createWithDevice(user: User, device: DeviceRegistration): Promise<void>;
  findById(id: string): Promise<User | null>;
  findByDeviceFingerprint(fingerprint: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  /** Anonim kullanıcıyı e-posta ile 'registered'a yükseltir. */
  upgradeToEmail(userId: string, email: string, verifiedAt: Date): Promise<void>;
  /** Hesabı sil — FK kaskadı ile tüm ilişkili veri temizlenir (App Store zorunluluğu). */
  deleteById(id: string): Promise<void>;
}

/** one_time_tokens erişimi — magic link / e-posta doğrulama. */
export interface OneTimeTokenRepository {
  save(record: OneTimeTokenRecord): Promise<void>;
  findByHash(tokenHash: string): Promise<OneTimeTokenRecord | null>;
  markUsed(id: string, usedAt: Date): Promise<void>;
}

/** E-posta gönderimi (adaptör; sağlayıcı tek satırla değişir — docs/02 §3). */
export interface Mailer {
  sendMagicLink(email: string, link: string): Promise<void>;
}

/** refresh_tokens erişimi — rotation + reuse-detection için. */
export interface RefreshTokenRepository {
  save(record: RefreshTokenRecord): Promise<void>;
  findByHash(tokenHash: string): Promise<RefreshTokenRecord | null>;
  markRevoked(id: string, revokedAt: Date): Promise<void>;
  revokeFamily(familyId: string, revokedAt: Date): Promise<void>;
  /** userId'nin keepFamilyId HARİÇ tüm aktif token'larını iptal eder; iptal sayısı. */
  revokeAllExceptFamily(userId: string, keepFamilyId: string, revokedAt: Date): Promise<number>;
}

// DI token'ları (Nest provider'ları bu sembollerle bağlanır).
export const CLOCK = Symbol('Clock');
export const ID_GENERATOR = Symbol('IdGenerator');
export const OPAQUE_TOKEN_GENERATOR = Symbol('OpaqueTokenGenerator');
export const TOKEN_HASHER = Symbol('TokenHasher');
export const ACCESS_TOKEN_SIGNER = Symbol('AccessTokenSigner');
export const USER_REPOSITORY = Symbol('UserRepository');
export const REFRESH_TOKEN_REPOSITORY = Symbol('RefreshTokenRepository');
export const ONE_TIME_TOKEN_REPOSITORY = Symbol('OneTimeTokenRepository');
export const MAILER = Symbol('Mailer');
