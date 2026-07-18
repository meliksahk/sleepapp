import type { MessageKey } from '@/shared/i18n/dictionaries';

/**
 * Flag upsert API yanıtını owner'ın anlayacağı tek cümlenin ANAHTARINA çevirir. Saf
 * fonksiyon — her hata yolu AYIRT EDİCİ olmalı: "geçersiz" demek, yüzdeyi 150 yazan
 * owner'ı çaresiz bırakır. Kural sunucuda (#167); burada yalnızca reddi eşleriz.
 *
 * Anahtar döner, dizge değil: mesaj sunucu eyleminde seçilip istemcide gösteriliyor —
 * dizge döndürmek metni o anki dile çakardı (bkz. content/error-message.ts).
 */
export function flagErrorMessage(status: number, code?: string): MessageKey {
  if (code === 'flag_key_invalid') return 'flags.errorKeyInvalid';
  // 403: rol daraltması. UI formu owner'a gösterse de sunucu reddedebilir → sebebi söyle.
  if (status === 403) return 'flags.errorForbidden';
  if (status === 400) return 'flags.errorInvalid';
  return 'flags.errorGeneric';
}
