import type { CommunityRepository, UserSoundStorage } from '../domain/ports';

export interface CleanupReport {
  /** Slot açılıp dosya hiç gelmemiş satırlar (DB + nesne silindi). */
  abandonedSlots: number;
  /** Denetim süresi geçmiş reddedilen satırlar (DB + nesne silindi). */
  expiredRejections: number;
  /** DB'de karşılığı olmayan yetim nesneler (yalnızca nesne silindi). */
  orphanObjects: number;
}

/**
 * Yetim içerik temizliği — 3a'nın kapatılan riski.
 *
 * ÜÇ SIZINTI KAPANIR:
 * 1. **Abandoned slotlar:** kullanıcı slotu açıp PUT'i hiç yapmadı → satır
 *    pending ve byte_size NULL kalır. RETENTION sonrası satır + (varsa) nesne silinir.
 * 2. **Süresi geçmiş redler:** reddedilen içeriğin dosyasını sonsuza dek tutmak
 *    ne depolama disiplini ne KVKK dostudur. RETENTION sonrası satır + nesne silinir;
 *    kararın İZİ audit log'a düşer (bu iş ondan sonra çalışır).
 * 3. **Yetim nesneler:** hesap silme CASCADE'i satırı götürür ama S3 nesnesini
 *    BILEMEZ — bucket taranır, DB'de karşılığı olmayan `community/` nesneleri silinir.
 *    Bu tarama aynı zamanda 1. adımın kaçırduğu her şeyi de toplar.
 *
 * Onaylı içerik ASLA dokunulmaz: DB'de approved satırı olan anahtar korunur.
 */
export class CleanupOrphanSoundsUseCase {
  constructor(
    private readonly repo: CommunityRepository,
    private readonly storage: UserSoundStorage,
    private readonly bucket: string,
    private readonly prefix = 'community/',
  ) {}

  async execute(now = new Date()): Promise<CleanupReport> {
    const report: CleanupReport = {
      abandonedSlots: 0,
      expiredRejections: 0,
      orphanObjects: 0,
    };

    // ── 1. Yüklenmemiş slotlar ──
    const abandonedCutoff = new Date(now.getTime() - ABANDONED_SLOT_RETENTION_MS);
    for (const row of await this.repo.findAbandonedPending(abandonedCutoff)) {
      await this.storage.removeObject(this.bucket, row.storageKey).catch(() => {});
      await this.repo.delete(row.id);
      report.abandonedSlots += 1;
    }

    // ── 2. Denetim süresi dolan redler ──
    const rejectedCutoff = new Date(now.getTime() - REJECTED_RETENTION_MS);
    for (const row of await this.repo.findRejectedBefore(rejectedCutoff)) {
      await this.storage.removeObject(this.bucket, row.storageKey).catch(() => {});
      await this.repo.delete(row.id);
      report.expiredRejections += 1;
    }

    // ── 3. Bucket taraması — DB'de karşılığı olmayan her şey ──
    const objects = await this.storage.listKeys(this.bucket, this.prefix);
    if (objects.length > 0) {
      // Tüm community anahtarlarını TEK sorguda değil, set ile eleme: küçük
      // ölçekte yeterli; yüz binlerce satıra çıkınca chunk'lı lookup yazılır.
      const known = await this.repo.listAllKeys();
      const knownSet = new Set(known);
      for (const obj of objects) {
        if (knownSet.has(obj.key)) continue;
        await this.storage.removeObject(this.bucket, obj.key).catch(() => {});
        report.orphanObjects += 1;
      }
    }

    return report;
  }
}

/** Slot açıldıktan sonra dosyanın gelmesi için makul süre: 48 saat. */
export const ABANDONED_SLOT_RETENTION_MS = 48 * 60 * 60 * 1000;

/** Reddenilen dosyanın saklama süresi: 30 gün (itiraz penceresi). */
export const REJECTED_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
