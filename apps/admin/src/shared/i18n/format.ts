import type { Locale } from './dictionaries';

/**
 * Dile duyarlı sayı/tarih biçimlendirme.
 *
 * **Neden ayrı modül:** biçim, çeviri DEĞİL — `%25` ile `25%` aynı metnin iki dili
 * değil, aynı SAYININ iki gösterimi. Sözlüğe iki ayrı dizge koymak, oranın
 * hesaplandığı her yerde dil dalı yazmayı gerektirirdi.
 *
 * **Zaman dilimi uyarısı:** bu yardımcılar SUNUCU bileşenlerinden çağrılıyor, yani
 * tarihler SUNUCUNUN saat diliminde biçimleniyor — kullanıcınınkinde değil. Bu,
 * `toLocaleString()` kullanan önceki hâlin de davranışıydı; burada değiştirilmedi
 * (kullanıcının TZ'si sunucuda bilinmiyor). Gerçek kullanıcı saati istenirse
 * biçimlendirmenin istemciye taşınması ya da TZ'nin tercih olarak saklanması gerekir.
 */

/** Tarih + saat (denetim izi gibi "ne zaman oldu" alanları). */
export function formatDateTime(locale: Locale, iso: string): string {
  const date = new Date(iso);
  // Bozuk/eksik tarih: ham değeri göster. Boş hücre "veri yok" der ve YANLIŞTIR —
  // veri var, biçimlendirilemedi (statusLabel'daki aynı ilke).
  if (Number.isNaN(date.getTime())) return iso;
  return new Intl.DateTimeFormat(locale, { dateStyle: 'short', timeStyle: 'short' }).format(date);
}

/** Yalnızca tarih (kayıt oluşturma günü gibi saatin anlamsız olduğu alanlar). */
export function formatDate(locale: Locale, iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(date);
}

/**
 * Oran (0–1) → yüzde. TR'de `%25`, EN'de `25%` — işaretin yeri dile bağlıdır ve
 * elle `%${n}` yazmak TR'yi doğru, EN'i yanlış yapıyordu.
 *
 * **`fractionDigits` NEDEN VAR:** iki farklı ihtiyaç var ve tek kural ikisine uymuyor.
 * ÖLÇÜLEN oranlarda (paylaşım oranı = 1/3) ondalık gürültüdür — `%33` doğru okuma.
 * ELLE GİRİLEN yapılandırmada (rollout %12,5) ondalık gerçek veridir; yuvarlamak
 * operatöre yanlış değer gösterir ve kademeli açılışta yarım puanlar kullanılır.
 * Varsayılan 0 (metrikler); rollout açıkça 1 geçer. Tam sayılarda gereksiz ",0"
 * çıkmaz çünkü minimumFractionDigits varsayılan 0'dır.
 */
export function formatPercent(locale: Locale, ratio: number, fractionDigits = 0): string {
  return new Intl.NumberFormat(locale, {
    style: 'percent',
    maximumFractionDigits: fractionDigits,
  }).format(ratio);
}
