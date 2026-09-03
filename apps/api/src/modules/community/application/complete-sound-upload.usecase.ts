import { SoundNotFoundError, SoundNotOwnedError, UploadIncompleteError } from '../domain/errors';
import type { CommunityRepository, UserSoundStorage } from '../domain/ports';
import { SOUND_MAX_BYTES, SOUND_MIN_BYTES } from '../domain/user-sound';

/**
 * Paylaşımın İKİNCİ adımı: "dosyayı PUT ettim" bildirimi.
 *
 * İSTEMCİYE GÜVENİLMEZ: HEAD ile nesne gerçekten var mı, boyutu sınırların
 * içinde mi diye depoya sorulur. Boyut kontrolü buradadır çünkü presigned PUT
 * Content-Length'ı ZORUNLU KILMAZ — MinIO boş/garip bir nesneyi de kabul eder.
 *
 * Durum pending KALIR: "yükledi" ile "onaylandı" farklı şeylerdir; moderasyon
 * tam da aradaki basamaktır.
 */
export class CompleteSoundUploadUseCase {
  constructor(
    private readonly repo: CommunityRepository,
    private readonly storage: UserSoundStorage,
    private readonly bucket: string,
  ) {}

  async execute(userId: string, soundId: string): Promise<void> {
    const sound = await this.repo.findById(soundId);
    if (sound === null) {
      throw new SoundNotFoundError();
    }
    if (sound.userId !== userId) {
      throw new SoundNotOwnedError();
    }

    const head = await this.storage.headObject(this.bucket, sound.storageKey);
    if (head === null) {
      throw new UploadIncompleteError('Dosya depoda bulunamadı. Yüklemeyi yeniden dene.');
    }
    if (head.sizeBytes < SOUND_MIN_BYTES || head.sizeBytes > SOUND_MAX_BYTES) {
      // Sınır dışı dosya DEPOLAMADA kalır ama kayıt işaretlenmez — kullanıcıya
      // neden söylenir, yeni bir yükleme denemesiyle düzeltir.
      throw new UploadIncompleteError(
        `Dosya boyutu kabul aralığının dışında (${SOUND_MIN_BYTES}–${SOUND_MAX_BYTES} bayt).`,
      );
    }

    await this.repo.markUploaded(sound.id, head.sizeBytes);
  }
}
