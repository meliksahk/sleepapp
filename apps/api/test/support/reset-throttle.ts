import type { INestApplication } from '@nestjs/common';
import { ThrottlerStorage, ThrottlerStorageService } from '@nestjs/throttler';

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
 * ⚠️ **Üçüncü kez düşüldü — CI'da, REDIS_URL YOKKEN.** Burada eskiden "REDIS_URL
 * yoksa depolama bellek-içidir ve her app kurulumunda zaten sıfırdır" yazıyordu.
 * Bu, uygulamayı `beforeAll`'da BİR KEZ kuran dosyalar için YANLIŞ: bellek-içi
 * sayaç o tek uygulama örneğinde dosya boyunca birikir. `community.e2e` düşük
 * limitli bir uca (`@Throttle` 10/saat) 10'dan fazla istek attığı için CI'da 8
 * testi 429 ile düşüyordu; lokalde REDIS_URL olduğu için hep yeşildi. Böyle
 * dosyalar [resetInMemoryThrottle]'ı da çağırmalı.
 *
 * Testler `--runInBand` (sıralı) koştuğu için başka bir testin sayacını yarıda
 * silme riski yok.
 *
 * (Parametresiz kalması bilinçli: `beforeEach(fn)`'e verilen fonksiyon parametre
 * alırsa Jest onu `done` geri çağrısı bekleyen bir kanca sanar.)
 */
export async function resetThrottleCounters(): Promise<void> {
  const url = process.env.REDIS_URL;
  // REDIS_URL yoksa sayaç bellektedir → bkz. [resetInMemoryThrottle].
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

/**
 * Bellek-içi throttler sayacını sıfırlar (REDIS_URL YOKKEN — CI'ın hâli).
 *
 * Depo Redis ise hiçbir şey yapmaz; o durumda [resetThrottleCounters] yeterli.
 *
 * **Sıra önemli:** önce `onApplicationShutdown()` (açık API) bekleyen "sayacı
 * düşür" zamanlayıcılarını temizler, SONRA harita boşaltılır. Harita
 * zamanlayıcılar dururken boşaltılsaydı, TTL dolduğunda zamanlayıcı silinmiş
 * kaydı okumaya çalışır ve test sürecini TypeError ile düşürürdü.
 */
export function resetInMemoryThrottle(app: INestApplication): void {
  const storage = app.get<unknown>(ThrottlerStorage, { strict: false });
  if (!(storage instanceof ThrottlerStorageService)) return;
  storage.onApplicationShutdown();
  storage.storage.clear();
}
