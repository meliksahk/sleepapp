import type { MessageKey } from '@/shared/i18n/dictionaries';

/**
 * Kampanya API yanıtını owner'ın anlayacağı tek cümlenin ANAHTARINA çevirir. Saf
 * fonksiyon — her hata yolu AYIRT EDİCİ olmalı. Kural sunucuda (#183); burada
 * yalnızca reddi eşleriz.
 *
 * Anahtar döner, dizge değil: mesaj sunucu eyleminde seçilip istemcide gösteriliyor —
 * dizge döndürmek metni o anki dile çakardı (bkz. content/error-message.ts).
 */
export function campaignErrorMessage(status: number): MessageKey {
  // 403: rol daraltması. UI formu owner'a gösterse de sunucu reddedebilir → sebebi söyle.
  if (status === 403) return 'campaign.errorForbidden';
  if (status === 400) return 'campaign.errorInvalid';
  return 'campaign.errorGeneric';
}
