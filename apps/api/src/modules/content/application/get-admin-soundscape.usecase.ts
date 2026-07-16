import type { AdminSoundscapeView, ContentRepository } from '../domain/soundscape';
import { SoundscapeNotFoundError } from '../domain/errors';

/**
 * Tek kayıt, admin görünümü (taslak dahil + ham tarif). Content'in PUBLIC servisi.
 *
 * `GetSoundscapeUseCase`'den AYRI: o uygulamanın detay ucudur — yalnızca YAYINLANMIŞ
 * kaydı döner, preset'leri çözer ve presigned önizleme URL'i üretir. Admin'in
 * ihtiyacı bambaşka: her durumdaki kaydı, düzenlenecek ham tarifle.
 */
export class GetAdminSoundscapeUseCase {
  constructor(private readonly repo: ContentRepository) {}

  async execute(slug: string): Promise<AdminSoundscapeView> {
    const view = await this.repo.findAdminBySlug(slug);
    if (view === null) throw new SoundscapeNotFoundError(slug);
    return view;
  }
}
