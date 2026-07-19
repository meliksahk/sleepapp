import {
  ASSET_URL_TTL_SECONDS,
  type AudioAssetRepository,
  type AudioAssetWithUrl,
} from '../domain/audio-asset';
import type { AssetUrlSigner } from '../domain/soundscape';

/**
 * Tek ses dosyası + presigned indirme URL'i.
 *
 * Kayıt yoksa **null** (çağıran 404'e çevirir) — bulunamayan kaydı hataya
 * çevirmek use case'in işi değil, HTTP semantiği controller'da kalır.
 *
 * URL üretimi OFFLINE'dır (imza hesabı, ağ çağrısı yok — bkz. `S3AssetSigner`):
 * yani dosya MinIO'dan silinmiş olsa bile burası başarıyla döner ve hata
 * indirme anında görülür. Bu bilinçli: API dosya proxy'lemez, varlık kontrolü
 * için her istekte S3'e HEAD atmak uçuş başına bir ağ gidiş-dönüşü eklerdi.
 * İstemci tarafı bu yüzden "dosya çalınamadı" durumunu SESSİZCE karşılamak
 * zorundadır (mobil `MixPlayer` asset katmanını atlayıp log basar).
 */
export class GetAudioAssetUseCase {
  constructor(
    private readonly repo: AudioAssetRepository,
    private readonly signer: AssetUrlSigner,
    private readonly bucket: string,
  ) {}

  async execute(id: string): Promise<AudioAssetWithUrl | null> {
    const asset = await this.repo.findById(id);
    if (!asset) return null;
    const url = await this.signer.presignedGetUrl(this.bucket, asset.key, ASSET_URL_TTL_SECONDS);
    return { asset, url, expiresInSeconds: ASSET_URL_TTL_SECONDS };
  }
}
