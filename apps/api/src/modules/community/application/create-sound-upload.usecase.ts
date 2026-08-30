import { randomUUID } from 'node:crypto';

import { PendingLimitReachedError } from '../domain/errors';
import type { CommunityRepository, UserSoundStorage } from '../domain/ports';
import {
  MAX_PENDING_SOUNDS_PER_USER,
  UPLOAD_URL_EXPIRY_SECONDS,
  sanitizeDuration,
  sanitizeTitle,
} from '../domain/user-sound';

/** CreateSoundUpload sonucu — istemci bu üçlüyle PUT atar. */
export interface SoundUploadSlot {
  readonly id: string;
  readonly uploadUrl: string;
  readonly expiresIn: number;
}

/**
 * Paylaşımın İLK adımı: kaydı oluştur, yükleme URL'i ver.
 *
 * Neden TEK istekte kayıt + URL: "önce yükle, sonra meta gönder" deseninde
 * yarım kalan yüklemeler yetim dosya üretir; burada DB kaydı öncedir, dosya
 * gelmezse satır pending kalır ve moderasyon listesinde GÖRÜNÜR (temizlenmesi
 * görülebilir bir sorundur; gizli S3 çöpü değil).
 *
 * KURALLAR ("belli koşullar"ın kodu):
 * - başlık/süre saf doğrulayıcılarla elenir,
 * - kullanıcı başına eşzamanlı pending tavanı (spam kanca),
 * - storage_key kullanıcının kimliğini TAŞIR (`user/{userId}/{soundId}`) —
 *   ileride bucket policy ile satır-başı izole edilebilsin diye.
 */
export class CreateSoundUploadUseCase {
  constructor(
    private readonly repo: CommunityRepository,
    private readonly storage: UserSoundStorage,
    private readonly bucket: string,
  ) {}

  async execute(
    userId: string,
    input: { title: unknown; durationSeconds: unknown },
  ): Promise<SoundUploadSlot> {
    const title = sanitizeTitle(input.title);
    if (title === null) {
      throw new TypeError('invalid_title');
    }
    const durationSeconds = sanitizeDuration(input.durationSeconds);
    if (durationSeconds === null) {
      throw new TypeError('invalid_duration');
    }

    const pending = await this.repo.countPendingByUser(userId);
    if (pending >= MAX_PENDING_SOUNDS_PER_USER) {
      throw new PendingLimitReachedError(MAX_PENDING_SOUNDS_PER_USER);
    }

    // id BİZİM ürettiğimiz: kullanıcının kontrolündeki hiçbir dizgi (başlık
    // dahil) depolama anahtarına girmez. `community/` prefix'i, topluluk
    // nesnelerini katalog bucket'ında İZOLE tutar (policy ileride prefix'e
    // bağlanabilir); anahtar katalog okumasıyla AYNI bucket'tadır — presigned
    // GET "hangi bucket?" sorusunu hiç doğurmaz.
    const id = randomUUID();
    const sound = await this.repo.create({
      id,
      userId,
      title,
      durationSeconds,
      storageKey: `community/${userId}/${id}`,
    });

    const uploadUrl = await this.storage.presignedPutUrl(
      this.bucket,
      sound.storageKey,
      UPLOAD_URL_EXPIRY_SECONDS,
    );
    return { id: sound.id, uploadUrl, expiresIn: UPLOAD_URL_EXPIRY_SECONDS };
  }
}
