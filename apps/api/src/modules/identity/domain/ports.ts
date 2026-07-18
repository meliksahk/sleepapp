import type {
  AccessTokenClaims,
  ActiveSessionInfo,
  DeviceRegistration,
  OneTimeTokenRecord,
  RefreshTokenRecord,
  User,
  UserKind,
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

/**
 * Parola hash'leme — argon2id (CLAUDE.md §3.3). SHA-256'dan (TokenHasher) AYRI bir
 * porttur ve karıştırılmamalıdır: refresh token 256-bit rastgeledir (kaba kuvvet
 * anlamsız, deterministik lookup gerekir); parola düşük entropilidir → yavaş, salt'lı,
 * bellek-zor hash şart. İkisini tek porta koymak, birini yanlış yerde kullanmayı
 * kolaylaştırırdı.
 */
export interface PasswordHasher {
  hash(plain: string): Promise<string>;
  /** Geçersiz/bozuk hash'te ATMAZ, false döner (çağıran tek bir 401 yolu izler). */
  verify(storedHash: string, plain: string): Promise<boolean>;
}

/** RS256 access JWT imzalama/doğrulama — kripto YALNIZCA burada (docs/02 §2.1). */
export interface AccessTokenSigner {
  sign(claims: AccessTokenClaims, ttlSeconds: number): Promise<string>;
  verify(token: string): Promise<AccessTokenClaims>;
}

/** Admin girişi için gereken minimum kayıt. Parola hash'i domain User'a KOYULMAZ:
 * User her yerde dolaşır (me, refresh, guard) — hash'in oraya sızma riski yaratmaz. */
export interface AdminCredentials {
  readonly userId: string;
  /** Hesabın e-postası — otpauth etiketi için. İstemciden ALINMAZ: kullanıcı kendi
   * etiketini uydurabilir ve başka hesabın anahtarıymış gibi kaydedebilirdi. */
  readonly email: string;
  readonly roles: readonly string[];
  readonly passwordHash: string;
  /** Kurulu gizli anahtar; kurulum yarıda kalmış olabilir (bkz. totpConfirmedAt). */
  readonly totpSecret: string | null;
  /**
   * 2FA yalnızca BU DOLUYSA zorunludur. Sırf `totpSecret` doluysa zorunlu kılmak,
   * kodu Authenticator'a girmeden yarıda bırakan kullanıcıyı kalıcı kilitlerdi.
   */
  readonly totpConfirmedAt: Date | null;
  /** Son kabul edilen TOTP sayacı — tekrar saldırısı kapısı (RFC 6238 §5.2). */
  readonly totpLastCounter: number | null;
}

/**
 * Admin panelinin kullanıcı arama görünümü — destek senaryosu (docs/02 §165).
 * Kişisel içerik DEĞİL: yalnızca kimlik/tür/oluşturma. E-posta destek için gerekli
 * (kullanıcıyı bulmak), ama parola/token/gizli anahtar ASLA dönmez.
 */
export interface AdminUserSummary {
  readonly id: string;
  readonly kind: UserKind;
  readonly email: string | null;
  readonly createdAt: Date;
}

/** users + auth_devices erişimi. Repository userId scope'unu zorunlu kılar (docs/02 §2.1). */
export interface UserRepository {
  createWithDevice(user: User, device: DeviceRegistration): Promise<void>;
  findById(id: string): Promise<User | null>;
  /**
   * Admin kullanıcı araması: e-posta alt-dizesi (case-insensitive) veya tam id.
   * Silinmiş (deleted_at) kullanıcılar hariç. `limit` ile sınırlı (DoS/veri sızıntısı).
   */
  searchUsers(query: string, limit: number): Promise<AdminUserSummary[]>;
  findByDeviceFingerprint(fingerprint: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  /** kind='admin' + parolası kurulu + silinmemiş kullanıcı; yoksa null. */
  findAdminCredentialsByEmail(email: string): Promise<AdminCredentials | null>;
  /** Aynısı, kimlik doğrulanmış istek için (token'da e-posta yok, yalnızca `sub`). */
  findAdminCredentialsById(userId: string): Promise<AdminCredentials | null>;
  /** Anonim kullanıcıyı e-posta ile 'registered'a yükseltir. */
  upgradeToEmail(userId: string, email: string, verifiedAt: Date): Promise<void>;
  /** Hesabı sil — FK kaskadı ile tüm ilişkili veri temizlenir (App Store zorunluluğu). */
  deleteById(id: string): Promise<void>;

  /** 2FA gizli anahtarını yazar (henüz zorunlu kılmaz — onay ayrı adım). */
  setTotpSecret(userId: string, secret: string): Promise<void>;

  /**
   * İlk geçerli kodla 2FA'yı etkinleştirir ve kullanılan sayacı işaretler.
   * Tek metot: onay ile ilk sayacın yazımı ATOMİK olmalı — arada kalırsa aynı kod
   * bir kez daha kullanılabilirdi.
   */
  confirmTotp(userId: string, confirmedAt: Date, counter: number): Promise<void>;

  /** Girişte kullanılan sayacı işaretler (aynı kod bir daha geçmesin). */
  recordTotpCounter(userId: string, counter: number): Promise<void>;

  /**
   * 2FA'yı tamamen KALDIRIR (anahtar + onay + sayaç null): parola-doğrulamalı sıfırlama
   * sonrası (#186) kullanıcı yeni cihazda yeniden kurabilsin diye.
   */
  clearTotp(userId: string): Promise<void>;
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
  /**
   * Ailede hâlâ AKTİF (iptal edilmemiş, süresi geçmemiş) token var mı?
   * Grace window'un "iyi niyetli yarış mı, ölü oturum mu?" ayrımı buna dayanır:
   * normal rotasyondan sonra aile canlıdır; çıkış/reuse sonrası değildir.
   */
  hasActiveInFamily(familyId: string, now: Date): Promise<boolean>;
  /** userId'nin keepFamilyId HARİÇ tüm aktif token'larını iptal eder; iptal sayısı. */
  revokeAllExceptFamily(userId: string, keepFamilyId: string, revokedAt: Date): Promise<number>;
  /** Kullanıcının aktif (iptal edilmemiş, süresi geçmemiş) oturumları — token'sız. */
  listActiveByUser(userId: string, now: Date): Promise<ActiveSessionInfo[]>;
}

// DI token'ları (Nest provider'ları bu sembollerle bağlanır).
export const CLOCK = Symbol('Clock');
export const ID_GENERATOR = Symbol('IdGenerator');
export const OPAQUE_TOKEN_GENERATOR = Symbol('OpaqueTokenGenerator');
export const TOKEN_HASHER = Symbol('TokenHasher');
export const PASSWORD_HASHER = Symbol('PasswordHasher');
export const ACCESS_TOKEN_SIGNER = Symbol('AccessTokenSigner');
export const USER_REPOSITORY = Symbol('UserRepository');
export const REFRESH_TOKEN_REPOSITORY = Symbol('RefreshTokenRepository');
export const ONE_TIME_TOKEN_REPOSITORY = Symbol('OneTimeTokenRepository');
export const MAILER = Symbol('Mailer');
