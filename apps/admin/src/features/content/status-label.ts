import { translate, type Locale, type MessageKey } from '@/shared/i18n/dictionaries';
import type { SoundscapeStatus } from './types';

/**
 * Durum etiketleri. Saf fonksiyon — bileşenden AYRI tutuldu ki testlenebilsin
 * (asıl derdimiz: bilinmeyen bir durumun sessizce boş hücreye dönüşmemesi).
 */
const KEYS: Record<SoundscapeStatus, MessageKey> = {
  draft: 'status.draft',
  scheduled: 'status.scheduled',
  published: 'status.published',
};

export function statusLabel(locale: Locale, status: string): string {
  const key = KEYS[status as SoundscapeStatus];
  // API yeni bir durum eklerse panel BOŞ hücre değil, ham değeri gösterir: editör
  // "burada bir şey var ama tanımıyorum" görsün, hiçbir şey görmesin değil.
  return key === undefined ? status : translate(locale, key);
}
