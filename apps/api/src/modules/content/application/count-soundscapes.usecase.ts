import type { ContentRepository } from '../domain/soundscape';
import type { ContentStatus } from '../domain/soundscape';

/**
 * Durum başına içerik sayısı (panel panosu). Content'in PUBLIC servisi.
 *
 * `ListAllSoundscapesUseCase` ile SAYMAK yerine ayrı: liste tüm satırları çeker;
 * pano büyüdükçe her açılışta katalogu belleğe almak sessizce O(n) bir maliyet
 * olurdu. Bu tam olarak #101'de bulduğum hata sınıfı (istatistik listeye bağlıydı).
 */
export class CountSoundscapesUseCase {
  constructor(private readonly repo: ContentRepository) {}

  async execute(): Promise<Record<ContentStatus, number>> {
    return this.repo.countByStatus();
  }
}
