/**
 * Rate-limit sayaçlarını sıfırlar — hız sınırına TABİ her e2e testi için.
 *
 * **NEDEN GEREKLİ (iki kez ısırdı, ikincisinde ders alındı):** throttler sayacı
 * Redis'te ve TÜM testler arasında PAYLAŞILIR; hepsi de aynı IP'den (::1) gelir.
 * Bir dosya paketin sonlarında çalıştığında kota çoktan tükenmiş olur ve testin
 * kendi ilk isteği bile 429 alır. Hata TAMAMEN SIRAYA BAĞLIDIR: alakasız bir
 * birim test dosyası eklemek jest'in dosya sırasını değiştirip testi kırabilir
 * (#210'da tam olarak bu oldu), ya da paket turbo altında diğer paketlerle
 * eşzamanlı koşarken zamanlama değişip kırılabilir (#212'de waitlist böyle düştü).
 *
 * #210'da bunu YALNIZCA `throttler.e2e` için düzeltmiştim — tek teste yama.
 * `waitlist.e2e` aynı kırılganlığı taşıyordu ve bir sonraki koşuda düştü. Bu
 * yüzden çözüm artık paylaşılan: hız sınırına tabi YENİ bir e2e yazan herkes
 * `beforeEach(resetThrottleCounters)` yazsın, aynı tuzağa üçüncü kez düşmeyelim.
 *
 * Testler `--runInBand` (sıralı) koştuğu için başka bir testin sayacını yarıda
 * silme riski yok.
 */
export async function resetThrottleCounters(): Promise<void> {
  const url = process.env.REDIS_URL;
  // REDIS_URL yoksa depolama bellek-içidir ve her app kurulumunda zaten sıfırdır.
  if (!url) return;

  const { default: IORedis } = await import('ioredis');
  const redis = new IORedis(url, { maxRetriesPerRequest: null });
  try {
    const keys = await redis.keys('throttle:*');
    if (keys.length > 0) await redis.del(...keys);
  } finally {
    await redis.quit();
  }
}
