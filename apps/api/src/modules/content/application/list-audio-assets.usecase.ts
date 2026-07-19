import type { AudioAsset, AudioAssetFilter, AudioAssetRepository } from '../domain/audio-asset';

/**
 * Ses dosyası kataloğunu listeler (tür/mood filtreli).
 *
 * Presigned URL ÜRETMEZ — bilinçli. Liste 100 satır olabilir ve her satır için
 * imza üretmek (a) gereksiz iş, (b) kullanıcının hiç dokunmayacağı 100 dosya için
 * 100 adet 6 saatlik erişim hakkı dağıtmak demektir. URL yalnızca tekil uçta,
 * yalnızca istenen dosya için üretilir.
 */
export class ListAudioAssetsUseCase {
  constructor(private readonly repo: AudioAssetRepository) {}

  execute(filter: AudioAssetFilter = {}): Promise<AudioAsset[]> {
    return this.repo.list(filter);
  }
}
