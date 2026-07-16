import type { SoundscapeStatus } from './types';

/**
 * Durum etiketleri. Saf fonksiyon — bileşenden AYRI tutuldu ki testlenebilsin
 * (asıl derdimiz: bilinmeyen bir durumun sessizce boş hücreye dönüşmemesi).
 */
const LABELS: Record<SoundscapeStatus, string> = {
  draft: 'Taslak',
  scheduled: 'Planlandı',
  published: 'Yayında',
};

export function statusLabel(status: string): string {
  // API yeni bir durum eklerse panel BOŞ hücre değil, ham değeri gösterir: editör
  // "burada bir şey var ama tanımıyorum" görsün, hiçbir şey görmesin değil.
  return LABELS[status as SoundscapeStatus] ?? status;
}
