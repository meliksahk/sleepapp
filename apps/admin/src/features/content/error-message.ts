import type { MessageKey } from '@/shared/i18n/dictionaries';

/**
 * API yanıtını editörün anlayacağı tek cümlenin ANAHTARINA çevirir.
 *
 * Saf fonksiyon: asıl derdimiz her hata yolunun DOĞRU ve AYIRT EDİCİ bir mesaj
 * vermesi. "Bir şeyler ters gitti" demek, slug'ı dolu olan editörü çaresiz bırakır.
 *
 * **Neden dizge değil anahtar:** mesaj SUNUCU eyleminde üretiliyor ama İSTEMCİDE
 * gösteriliyor. Dizge döndürseydik metin, eylemin çalıştığı andaki dile çakılırdı;
 * kullanıcı dili değiştirince ekrandaki hata eski dilde kalırdı. (LoginForm'un
 * `messageFor` deseni.)
 */
export function createErrorMessage(status: number, code?: string): MessageKey {
  if (code === 'slug_taken') return 'content.errorSlugTaken';
  // Yayınlama kapısı: editörün ne yapması gerektiğini SÖYLE, "409" deme.
  if (code === 'empty_recipe') return 'content.errorEmptyRecipe';
  if (code === 'soundscape_not_found') return 'content.errorNotFound';
  if (code === 'empty_title') return 'content.errorEmptyTitle';
  if (code === 'invalid_slug') return 'content.errorInvalidSlug';
  // 403: rol daraltması (analyst/support yazamaz). UI butonu gizlese de sunucu
  // reddedebilir — kullanıcı sebebi bilmeli, sessizce başarısız olmamalı.
  if (status === 403) return 'content.errorForbidden';
  if (status === 400) return 'content.errorBadInput';
  return 'content.errorGeneric';
}
