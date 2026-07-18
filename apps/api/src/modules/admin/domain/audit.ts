/**
 * Panel denetim izi (docs/03).
 *
 * NEDEN VAR: içerik yayınlanıyor/geri çekiliyor/tarifi değişiyordu ama KİMİN
 * yaptığının izi yoktu. Yanlış içerik canlıya çıktığında kimse hesap veremezdi.
 */

/** Kaydedilen eylemler. Serbest string DEĞİL: yazım hatası izi sessizce kaybeder. */
export const AUDIT_ACTIONS = [
  'soundscape.create',
  'soundscape.update',
  'soundscape.publish',
  'soundscape.unpublish',
  'soundscape.recipe',
  'flag.upsert',
] as const;

export type AuditAction = (typeof AUDIT_ACTIONS)[number];

export interface AuditEntry {
  readonly id: string;
  readonly actorEmail: string;
  readonly action: AuditAction;
  readonly target: string;
  readonly details: Record<string, unknown>;
  readonly createdAt: Date;
}

export interface NewAuditEntry {
  /** Çağıranın id'si — token'dan gelir, gövdeden DEĞİL. */
  readonly actorId: string;
  readonly action: AuditAction;
  readonly target: string;
  readonly details?: Record<string, unknown>;
}

export interface AuditLog {
  /**
   * İzi yazar. **ASLA ATMAZ:** denetim yazımı başarısız olursa kullanıcının
   * işlemi de başarısız olurdu — iz tutmak, işi engellemekten daha az önemlidir.
   * Hata loglanır ve yutulur (bkz. adaptör).
   */
  record(entry: NewAuditEntry): Promise<void>;
  /** Son N kayıt (pano akışı), en yeniden eskiye. */
  recent(limit: number): Promise<AuditEntry[]>;
}

export const AUDIT_LOG = Symbol('AuditLog');
