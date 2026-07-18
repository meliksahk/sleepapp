/**
 * Flag upsert API yanıtını owner'ın anlayacağı tek cümleye çevirir. Saf fonksiyon —
 * her hata yolu AYIRT EDİCİ olmalı: "geçersiz" demek, yüzdeyi 150 yazan owner'ı
 * çaresiz bırakır. Kural sunucuda (#167); burada yalnızca reddi Türkçeye çeviriyoruz.
 */
export function flagErrorMessage(status: number, code?: string): string {
  if (code === 'flag_key_invalid') {
    return 'Anahtar geçersiz — yalnızca küçük harf, rakam ve tire (ör. smart-alarm).';
  }
  // 403: rol daraltması. UI formu owner'a gösterse de sunucu reddedebilir → sebebi söyle.
  if (status === 403) return 'Bu işlem için yetkiniz yok (yalnızca owner flag düzenler).';
  if (status === 400) {
    return 'Girdiler geçersiz: yüzde 0-100 arası, sürüm 1.4.0 gibi olmalı.';
  }
  return 'Kaydedilemedi. Lütfen tekrar deneyin.';
}
