import type { Cache } from '../../../shared/cache/cache.port';
import type { ContentRepository, SoundscapeSummary } from '../domain/soundscape';
import { ContentError, SoundscapeNotFoundError } from '../domain/errors';

/** Feed cache anahtar ön eki — GetFeedUseCase ile AYNI olmalı. */
const FEED_CACHE_PREFIX = 'content:feed:';

/** Başlık boş olamaz: feed'de ve kütüphanede görünen tek tanımlayıcı odur. */
export class EmptyTitleError extends ContentError {
  constructor() {
    super('empty_title', 'Başlık boş olamaz.');
  }
}

/**
 * Başlık / archetype affinity günceller (docs/03 A1).
 *
 * SLUG DEĞİŞTİRİLEMEZ (bkz. SoundscapeMetaPatch): derin linkte yaşar ve paylaşılan
 * kartlarda dolaşır; değiştirmek dışarıdaki linkleri sessizce kırardı.
 *
 * CACHE: feed `titleI18n` ve `archetypeAffinity`'yi TAŞIR (affinity sıralamayı bile
 * değiştirir) → yayındaki bir kaydın metası değişince eski hâli kullanıcılara gitmeye
 * devam ederdi. #122'de tam bu sınıftan bir hata canlı ölçümle bulundu.
 */
export class UpdateSoundscapeUseCase {
  constructor(
    private readonly repo: ContentRepository,
    private readonly cache: Cache,
  ) {}

  async execute(
    slug: string,
    input: { titleEn?: string; archetypeAffinity?: readonly string[] },
  ): Promise<SoundscapeSummary> {
    const titleEn = input.titleEn?.trim();
    if (titleEn !== undefined && titleEn.length === 0) {
      throw new EmptyTitleError();
    }

    // Mevcut başlıkları OKU: `title_i18n` çok dilli bir nesne; komple yazarsak
    // ileride eklenecek TR başlığı EN düzenlemesi sessizce silerdi.
    let titleI18n: Record<string, string> | undefined;
    if (titleEn !== undefined) {
      const current = await this.repo.findAdminBySlug(slug);
      if (current === null) throw new SoundscapeNotFoundError(slug);
      titleI18n = { ...current.summary.titleI18n, en: titleEn };
    }

    const updated = await this.repo.updateMeta(slug, {
      titleI18n,
      archetypeAffinity: input.archetypeAffinity,
    });
    if (updated === null) throw new SoundscapeNotFoundError(slug);

    await this.cache.delByPrefix(FEED_CACHE_PREFIX);
    return updated;
  }
}
