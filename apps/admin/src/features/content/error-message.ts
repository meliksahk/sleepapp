/**
 * API yanıtını editörün anlayacağı tek cümleye çevirir.
 *
 * Saf fonksiyon: asıl derdimiz her hata yolunun DOĞRU ve AYIRT EDİCİ bir mesaj
 * vermesi. "Bir şeyler ters gitti" demek, slug'ı dolu olan editörü çaresiz bırakır.
 */
export function createErrorMessage(status: number, code?: string): string {
  if (code === 'slug_taken') return 'Bu slug zaten kullanımda. Başka bir slug deneyin.';
  if (code === 'invalid_slug') {
    return 'Slug yalnızca küçük harf, rakam ve tire içerebilir (ör. deep-ocean-drift).';
  }
  // 403: rol daraltması (analyst/support yazamaz). UI butonu gizlese de sunucu
  // reddedebilir — kullanıcı sebebi bilmeli, sessizce başarısız olmamalı.
  if (status === 403) return 'Bu işlem için yetkiniz yok.';
  if (status === 400) return 'Girdiler geçersiz. Slug ve başlığı kontrol edin.';
  return 'Kaydedilemedi. Lütfen tekrar deneyin.';
}
