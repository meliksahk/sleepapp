import type { UserSound } from './user-sound';

/**
 * Depolama portu — community modülünün S3/MinIO'ya TEK dokunduğu yer.
 *
 * `AssetUrlSigner`'dan (content) AYRI bir port, çünkü ihtiyaçlar farklıdır:
 * katalog yalnızca presigned GET üretir; topluluk akışı PUT üretir VE dosyanın
 * gerçekten var olup olmadığını HEAD ile DOĞRULAR. İmza üretimi offline'dır
 * (ağ çağrısı yok); doğrulama canlı erişimdir.
 */ export interface UserSoundStorage {
  /** Yükleme için kısa ömürlü presigned PUT URL. */
  presignedPutUrl(bucket: string, key: string, expirySeconds: number): Promise<string>;

  /**
   * Nesnenin varlığını ve boyutunu döner; yoksa null. Complete adımı burada
   * "PUT gerçekten oldu mu" sorusunu cevaplar — istemciye güvenilmez.
   */
  headObject(bucket: string, key: string): Promise<{ sizeBytes: number } | null>;

  /** Moderatör önizlemesi için kısa ömürlü presigned GET URL (3b). */
  presignedGetUrl(bucket: string, key: string, expirySeconds: number): Promise<string>;

  /** Temizlik işi için: prefix altındaki anahtarlar + son değişiklik zamanları. */
  listKeys(bucket: string, prefix: string): Promise<Array<{ key: string; lastModified: Date }>>;

  /** Temizlik işi için: nesneyi siler; yoksa sessizce geçer (idempotent). */
  removeObject(bucket: string, key: string): Promise<void>;
}

/** Kalıcılık portu — Prisma buraya sızmaz (modül sınırı kuralı). */
export interface CommunityRepository {
  create(input: {
    /** id ÇAĞIRAN üretir (use case): storage_key id'ye bağlı olduğu için önce bilinmelidir. */
    id: string;
    userId: string;
    title: string;
    storageKey: string;
    durationSeconds: number;
  }): Promise<UserSound>;

  findById(id: string): Promise<UserSound | null>;

  findByUser(userId: string): Promise<UserSound[]>;

  /** Kullanıcının pending sayısı — spam tavani bu sorguyla yaşar. */
  countPendingByUser(userId: string): Promise<number>;

  markUploaded(id: string, byteSize: number): Promise<UserSound | null>;

  moderate(input: {
    id: string;
    status: 'approved' | 'rejected';
    rejectionReason: string | null;
    moderatedAt: Date;
  }): Promise<UserSound | null>;

  listByStatus(status: UserSound['status'], limit: number, offset: number): Promise<UserSound[]>;

  countByStatus(status: UserSound['status']): Promise<number>;

  /** Temizlik işi: belirtilen zamandan ESKİ, hiç yüklenmemiş pending slotlar. */
  findAbandonedPending(before: Date): Promise<UserSound[]>;

  /** Temizlik işi: belirtilen zamandan eski reddedilen satırlar (denetim süresi doldu). */
  findRejectedBefore(before: Date): Promise<UserSound[]>;

  /** Satırı KALICI siler — yalnızca temizlik işi kullanır. */
  delete(id: string): Promise<void>;

  /** Bucket taramasının DB-eleme seti için: tüm storage anahtarları. */
  listAllKeys(): Promise<string[]>;
}

export const COMMUNITY_REPOSITORY = Symbol('COMMUNITY_REPOSITORY');
export const USER_SOUND_STORAGE = Symbol('USER_SOUND_STORAGE');
