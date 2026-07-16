import type { ContentRepository, SoundscapeSummary } from '../domain/soundscape';
import { isValidSlug } from '../domain/slug';
import { InvalidSlugError, SlugTakenError } from '../domain/errors';

/**
 * Yeni taslak oluşturur (docs/03 A1). Content'in PUBLIC application servisi —
 * admin modülü buradan tüketir, repo'ya dokunmaz (docs/02 §2 boundary).
 *
 * Durum daima 'draft': yayınlamak AYRI ve bilinçli bir adımdır. "Oluştur ve yayınla"
 * tek çağrıda olsaydı, yanlış bir kaydın kullanıcılara ulaşması bir yazım hatası
 * kadar kolay olurdu.
 */
export class CreateSoundscapeUseCase {
  constructor(private readonly repo: ContentRepository) {}

  async execute(input: {
    slug: string;
    titleEn: string;
    archetypeAffinity: readonly string[];
    createdBy: string;
  }): Promise<SoundscapeSummary> {
    const slug = input.slug.trim().toLowerCase();
    if (!isValidSlug(slug)) {
      throw new InvalidSlugError();
    }

    const created = await this.repo.createDraft({
      slug,
      titleI18n: { en: input.titleEn.trim() },
      archetypeAffinity: input.archetypeAffinity,
      createdBy: input.createdBy,
    });
    // null = DB'nin UNIQUE kısıtı reddetti (yarışa dayanıklı tek kaynak).
    if (created === null) {
      throw new SlugTakenError(slug);
    }
    return created;
  }
}
