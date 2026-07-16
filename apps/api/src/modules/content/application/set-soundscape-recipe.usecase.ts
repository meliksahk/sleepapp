import type { Cache } from '../../../shared/cache/cache.port';
import type { ContentRepository, SoundscapeSummary } from '../domain/soundscape';
import { parseEngineParams } from '../domain/engine-params';
import { InvalidRecipeError, SoundscapeNotFoundError } from '../domain/errors';

/** Feed cache anahtar ön eki — GetFeedUseCase ile AYNI olmalı. */
const FEED_CACHE_PREFIX = 'content:feed:';

/**
 * Ses tarifini yazar (docs/03 A1 "engine_params için şema-doğrulamalı editör").
 *
 * DOĞRULAMA BURADA, KOLONDA DEĞİL: `engine_params` serbest `jsonb`. Doğrulanmazsa
 * bozuk tarif DB'ye girer ve hata ancak KULLANICININ TELEFONUNDA, çalma anında
 * ortaya çıkar (mixer-state.ts'teki aynı gerekçe). Kapı burada.
 *
 * CACHE: yayınlanmış bir kaydın tarifi değişirse feed'deki ESKİ tarif kullanıcılara
 * gitmeye devam ederdi — #122'de tam bu sınıftan bir hata canlı ölçümle bulundu.
 * O yüzden burada da düşürüyoruz. (Taslak için gereksiz ama zararsız: feed zaten
 * taslakları içermez; koşullu yapmak "hangi durumda?" hatası riski taşır.)
 */
export class SetSoundscapeRecipeUseCase {
  constructor(
    private readonly repo: ContentRepository,
    private readonly cache: Cache,
  ) {}

  async execute(slug: string, recipe: unknown): Promise<SoundscapeSummary> {
    const parsed = parseEngineParams(recipe);
    if (parsed === null) throw new InvalidRecipeError();

    // Doğrulanmış hâli yazılır, ham girdi DEĞİL: fazladan alanlar böylece elenir.
    const updated = await this.repo.setEngineParams(slug, {
      schemaVersion: parsed.schemaVersion,
      layers: parsed.layers,
    });
    if (updated === null) throw new SoundscapeNotFoundError(slug);

    await this.cache.delByPrefix(FEED_CACHE_PREFIX);
    return updated;
  }
}
