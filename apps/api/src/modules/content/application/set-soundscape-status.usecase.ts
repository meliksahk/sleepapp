import type { Cache } from '../../../shared/cache/cache.port';
import type { ContentRepository, SoundscapeSummary } from '../domain/soundscape';
import { EmptyRecipeError, SoundscapeNotFoundError } from '../domain/errors';

/** Feed cache anahtar ön eki — GetFeedUseCase ile AYNI olmalı. */
const FEED_CACHE_PREFIX = 'content:feed:';

/**
 * Yayınla / yayından kaldır (docs/03 A1). Content'in PUBLIC application servisi.
 *
 * YAYINLAMA KAPISI: ses tarifi boş olan kayıt yayınlanamaz — feed `engineParams`'ı
 * uygulamaya taşır ve ses on-device o tariften üretilir; boş tarif = kütüphanede
 * görünen ama SES ÇIKARMAYAN kayıt. Bu kapı, "taslak boş doğar" kararının (bkz.
 * create-soundscape.usecase) güvenli olmasını sağlayan şeydir.
 *
 * Yayından kaldırmada böyle bir kapı YOK: geri çekmek her zaman güvenlidir ve
 * acil durumda (yanlış içerik canlıda) hiçbir koşula takılmamalıdır.
 */
export class SetSoundscapeStatusUseCase {
  constructor(
    private readonly repo: ContentRepository,
    private readonly cache: Cache,
  ) {}

  /**
   * Feed cache'ini düşürür. OLMADAN: geri çekme 5 DAKİKA boyunca işe yaramıyordu —
   * "yanlış içerik canlıda" senaryosunda kabul edilemez. Canlı ölçümle bulundu
   * (birim testler sıralı olduğu için ısınmış cache'i hiç görmüyordu).
   *
   * Kaba ama doğru: TÜM archetype varyantları düşer. İnce ayar (yalnızca etkilenen
   * archetype'lar) yanlış yapılırsa SESSİZ bayat içerik demek; bu maliyete değmez —
   * içerik değişimi seyrek, feed sorgusu ucuz.
   */
  private async invalidateFeed(): Promise<void> {
    await this.cache.delByPrefix(FEED_CACHE_PREFIX);
  }

  async publish(slug: string): Promise<SoundscapeSummary> {
    const view = await this.repo.findAdminBySlug(slug);
    if (view === null) throw new SoundscapeNotFoundError(slug);
    if (!view.hasRecipe) throw new EmptyRecipeError();

    const updated = await this.repo.setStatus(slug, 'published');
    if (updated === null) throw new SoundscapeNotFoundError(slug);
    await this.invalidateFeed();
    return updated;
  }

  async unpublish(slug: string): Promise<SoundscapeSummary> {
    const updated = await this.repo.setStatus(slug, 'draft');
    if (updated === null) throw new SoundscapeNotFoundError(slug);
    await this.invalidateFeed();
    return updated;
  }
}
