import { SoundNotFoundError } from '../domain/errors';
import type { CommunityRepository, UserSoundStorage } from '../domain/ports';
import type { UserSound } from '../domain/user-sound';

/** Önizleme sonucu — moderatör dosyayı KISA ÖMÜRLÜ url ile dinler (3b). */
export interface SoundPreview {
  readonly url: string;
  readonly expiresIn: number;
}

/** Önizleme URL ömrü: dinleme tek seferlik; sızarsa bile 10 dakikada ölür. */
export const PREVIEW_EXPIRY_SECONDS = 600;

/** Kullanıcının kendi paylaşımları — SADECE kendi satırları (userId scoping). */
export class ListMySoundsUseCase {
  constructor(private readonly repo: CommunityRepository) {}

  async execute(userId: string): Promise<UserSound[]> {
    return this.repo.findByUser(userId);
  }
}

/**
 * Moderatör önizlemesi: sesin presigned GET URL'ini üretir (3b).
 *
 * Herhangi bir DURUMDAKİ ses önizlenebilir — pending'in anlamı tam olarak
 * "karar vermeden önce dinle"; approved'u tekrar dinlemek geri çekme kararı
 * için; rejected'ı dinlemek itiraz değerlendirmesi içindir.
 */
export class GetSoundPreviewUseCase {
  constructor(
    private readonly repo: CommunityRepository,
    private readonly storage: UserSoundStorage,
    private readonly bucket: string,
  ) {}

  async execute(soundId: string): Promise<SoundPreview> {
    const sound = await this.repo.findById(soundId);
    if (sound === null) throw new SoundNotFoundError();
    const url = await this.storage.presignedGetUrl(
      this.bucket,
      sound.storageKey,
      PREVIEW_EXPIRY_SECONDS,
    );
    return { url, expiresIn: PREVIEW_EXPIRY_SECONDS };
  }
}

/**
 * Moderasyon listesi (admin): durum filtreli, en yeniden eskiye.
 * Sayfalama basittir — moderasyon kuyruğu yüzlerce değil onlarca satırdır;
 * cursor tabanlı sayfalama bu iterasyonda gereksiz mühendislik olurdu.
 */
export class ListSoundsForModerationUseCase {
  constructor(private readonly repo: CommunityRepository) {}

  async execute(
    status: UserSound['status'],
    limit = 50,
    offset = 0,
  ): Promise<{ items: UserSound[]; total: number }> {
    const items = await this.repo.listByStatus(status, limit, offset);
    const total = await this.repo.countByStatus(status);
    return { items, total };
  }
}

/**
 * Moderasyon kararı — tek giriş noktası (approve | reject).
 *
 * Durum makinesi PAZARLIKSIZ:
 * - pending → approved / rejected
 * - approved → rejected (geri çekme: sonradan sorun çıkan içerik iner)
 * - rejected → approved (yanlış redin düzeltilmesi)
 * - approved → approved / rejected → rejected: NO-OP DEĞİL HATADIR — aynı
 *   kararın iki kez yazılması audit izini bulanıklaştırır.
 *
 * Red kararı gerekçesiz OLAMAZ (DB CHECK de var); kullanıcıya gösterilir.
 */
export class ModerateSoundUseCase {
  constructor(private readonly repo: CommunityRepository) {}

  async execute(input: {
    soundId: string;
    decision: 'approve' | 'reject';
    rejectionReason?: string;
  }): Promise<UserSound> {
    const existing = await this.repo.findById(input.soundId);
    if (existing === null) {
      throw new SoundNotFoundError();
    }

    if (input.decision === 'approve') {
      if (existing.status === 'approved') {
        throw new Error('sound already approved');
      }
      const updated = await this.repo.moderate({
        id: input.soundId,
        status: 'approved',
        rejectionReason: null,
        moderatedAt: new Date(),
      });
      if (updated === null) throw new SoundNotFoundError();
      return updated;
    }

    const reason = (input.rejectionReason ?? '').trim();
    if (reason.length === 0) {
      throw new TypeError('rejection_reason_required');
    }
    if (existing.status === 'rejected') {
      throw new Error('sound already rejected');
    }
    const updated = await this.repo.moderate({
      id: input.soundId,
      status: 'rejected',
      rejectionReason: reason,
      moderatedAt: new Date(),
    });
    if (updated === null) throw new SoundNotFoundError();
    return updated;
  }
}
