/**
 * UserSound — topluluk sesi entity'si ve PAZARLIKSIZ kuralları.
 *
 * Bu dosyanın tek sorumluluğu "geçerli bir topluluk sesi nedir" sorusuna
 * cevap vermektir; framework, DB ve S3 buraya sızmaz (hexagonal modül kuralı).
 *
 * ## SAĞLIK İDDİASI YOK (CLAUDE.md §1.1)
 * Başlık doğrulaması yalnızca biçimseldir (uzunluk). İçerik moderasyonu
 * admin'in işidir — kod hiçbir sesi "iyileştirici" ya da tersine "zararlı"
 * diye sınıflandırmaz.
 */

export type UserSoundStatus = 'pending' | 'approved' | 'rejected';

export interface UserSound {
  readonly id: string;
  readonly userId: string;
  readonly title: string;
  /** Depolama anahtarı (`community/{userId}/{soundId}`) — URL DEĞİL. Katalog
   * bucket'ında (audio-assets) yaşar; prefix izolasyonu policy için yeterlidir
   * ve presigned GET "hangi bucket?" sorusunu doğurmaz. */
  readonly storageKey: string;
  /** null = dosya henüz YÜKLENMEDİ (slot açıldı, PUT bekleniyor). */
  readonly byteSize: number | null;
  readonly durationSeconds: number;
  readonly status: UserSoundStatus;
  readonly rejectionReason: string | null;
  readonly moderatedAt: Date | null;
  readonly createdAt: Date;
}

// ─────────────────────────── limitler ("belli koşullar") ───────────────────────────

/** Başlık uzunluğu. 80 karakter ekranda tek satırdır; fazlası zaten UI'da kırpılır. */
export const SOUND_TITLE_MAX_LENGTH = 80;

/** Süre üst sınırı: 2 saat. Uyku sesleri UZUNDUR (bir gece boyu çalınır); 5 dakikalık
 * tavan topluluk ürününü öldürürdü. Alt sınır 1 sn: 0-saniyelik dosya veri değil gürültüdür. */
export const SOUND_DURATION_MAX_SECONDS = 2 * 60 * 60;
export const SOUND_DURATION_MIN_SECONDS = 1;

/** Dosya boyutu: 25 MB. 2 saatlik ses ancak SIKIŞTIRILMIŞ formatta bu tavana sığar
 * (AAC ~128kbps ≈ 115 MB/saat → pratikte kullanıcı kısa/kompakt sesler yükler).
 * Tavanın amacı kötüye kullanımı sınırlamaktır; kaliteyi değil. */
export const SOUND_MAX_BYTES = 25 * 1024 * 1024;

/** HEAD ile doğrulanacak asgari boyut: altının altındaki her şey bozuk indirme/yarım PUT'tur. */
export const SOUND_MIN_BYTES = 10 * 1024;

/** Kullanıcı başına EŞZAMANLI pending tavanı. Spam kancası: onaysız içerik biriktirip
 * kuyruk şişirmek bedava olmamalı. Onay/red sayacı DÜŞER — kaliteli katkıcıyı cezalandırmaz. */
export const MAX_PENDING_SOUNDS_PER_USER = 10;

/** Presigned PUT ömrü. 15 dk: yavaş bağlantıda 25 MB rahat çıkar; kısası yükleme ortasında ölür. */
export const UPLOAD_URL_EXPIRY_SECONDS = 15 * 60;

// ─────────────────────────── saf doğrulayıcılar ───────────────────────────

/** Başlığı temizler; geçersizse null. Trim sonrası boşluk yasak (DB CHECK ile aynı kural). */
export function sanitizeTitle(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0 || trimmed.length > SOUND_TITLE_MAX_LENGTH) return null;
  return trimmed;
}

/** Süreyi temizler; aralık dışıysa null. Tam sayı zorunlu (yarım saniye yok). */
export function sanitizeDuration(raw: unknown): number | null {
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return null;
  const whole = Math.round(raw);
  if (whole < SOUND_DURATION_MIN_SECONDS || whole > SOUND_DURATION_MAX_SECONDS) {
    return null;
  }
  return whole;
}
