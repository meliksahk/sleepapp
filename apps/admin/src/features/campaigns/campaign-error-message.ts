/**
 * Kampanya API yanıtını owner'ın anlayacağı tek cümleye çevirir. Saf fonksiyon —
 * her hata yolu AYIRT EDİCİ olmalı. Kural sunucuda (#183); burada yalnızca reddi çeviririz.
 */
export function campaignErrorMessage(status: number): string {
  // 403: rol daraltması. UI formu owner'a gösterse de sunucu reddedebilir → sebebi söyle.
  if (status === 403) return 'Bu işlem için yetkiniz yok (yalnızca owner kampanya gönderir).';
  if (status === 400)
    return 'Girdiler geçersiz: başlık/gövde boş olamaz, platform ios veya android.';
  return 'Kampanya gönderilemedi. Lütfen tekrar deneyin.';
}
