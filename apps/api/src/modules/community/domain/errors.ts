/** community domain hataları — tipli hiyerarşi (CLAUDE.md §4). */

export class CommunityError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'CommunityError';
  }
}

/** Ses kaydı yok ya da BAŞKA BİR KULLANICIYA ait — dışarıya AYNI mesaj gider. */
export class SoundNotFoundError extends CommunityError {
  constructor() {
    super('sound_not_found', 'Ses bulunamadı.');
  }
}

/**
 * Sahiplik ihlali İÇERİDE ayrı tip (log/telemetri için); presentation bunu da
 * 404'e çevirir. 403 döndürmek "bu id başka birine ait ve VAR" demek olur —
 * ses id'lerinin varlığını dışarıya sızdırma.
 */
export class SoundNotOwnedError extends CommunityError {
  constructor() {
    super('sound_not_owned', 'Sound not owned by caller.');
  }
}

/** Pending tavanı doldu: kullanıcı önce mevcut yüklemelerinin akıbetini bekler. */
export class PendingLimitReachedError extends CommunityError {
  constructor(readonly limit: number) {
    super(
      'pending_limit_reached',
      `Aynı anda en fazla ${limit} bekleyen paylaşımın olabilir. Önce onların moderasyon sonucunu bekle.`,
    );
  }
}

/**
 * `uploaded` çağrıldığında dosya depoda bulunamadı (PUT hiç yapılmadı / yanlış
 * anahtar) ya da boyut sınırların DIŞINDA. Ayrı tip: kullanıcının düzeltebileceği
 * bir durumdur (yeniden PUT atabilir).
 */
export class UploadIncompleteError extends CommunityError {
  constructor(detail: string) {
    super('upload_incomplete', detail);
  }
}

/** Durum makinesi ihlali (ör. zaten approved olan sesi tekrar onaylamak). */
export class InvalidSoundStateError extends CommunityError {
  constructor(detail: string) {
    super('invalid_sound_state', detail);
  }
}
