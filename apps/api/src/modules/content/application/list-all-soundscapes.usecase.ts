import type { ContentRepository, SoundscapeSummary } from '../domain/soundscape';

/**
 * Admin listesi: TÜM soundscape'ler (taslak dahil). Content modülünün PUBLIC
 * application servisi — admin modülü buradan tüketir, content'in repo'suna
 * ASLA dokunmaz (docs/02 §2 boundary).
 *
 * Neden ayrı use case: `GetFeedUseCase` yalnızca YAYINLANMIŞ içeriği ve archetype
 * affinity sırasıyla döner — bu uygulama davranışıdır. Admin'in ihtiyacı tam tersi:
 * her şeyi, tarafsız sırayla. Aynı use case'i "adminMi" bayrağıyla bölmek, iki
 * farklı ürün kararını tek yere sıkıştırmak olurdu.
 *
 * Cache YOK (feed'in aksine): panel az kullanılır ve içeriği yeni kaydeden bir
 * editörün onu listede görmemesi kabul edilemez.
 */
export class ListAllSoundscapesUseCase {
  constructor(private readonly repo: ContentRepository) {}

  async execute(): Promise<SoundscapeSummary[]> {
    return this.repo.findAllSummaries();
  }
}
