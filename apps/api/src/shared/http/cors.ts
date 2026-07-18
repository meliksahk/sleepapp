/**
 * CORS izin listesi çözümü.
 *
 * Ayrı dosyada çünkü ayrı test edilebilir olmalı: yanlış yazılmış bir izin listesi
 * ya web'i kırar (çok dar) ya da API'yi herkese açar (çok geniş). İkisi de sessizce
 * olur — tarayıcı hatası sunucu logunda görünmez.
 */

/** Virgülle ayrık listeyi normalize eder: boşluk kırpılır, sondaki `/` atılır, boşlar elenir. */
export function parseCorsOrigins(raw: string): string[] {
  return raw
    .split(',')
    .map((o) => o.trim().replace(/\/+$/, ''))
    .filter((o) => o.length > 0);
}

/**
 * Bir kaynağa izin var mı?
 *
 * `origin` yoksa (undefined) İZİN VERİLİR: bunlar tarayıcı-dışı isteklerdir (curl,
 * mobil uygulama, sunucudan sunucuya). CORS bir TARAYICI korumasıdır; origin'siz
 * isteği reddetmek mobil uygulamayı ve sağlık kontrollerini kırardı, güvenlik de
 * kazandırmazdı (curl zaten istediği başlığı gönderebilir).
 */
export function isOriginAllowed(origin: string | undefined, allowlist: readonly string[]): boolean {
  if (!origin) return true;
  return allowlist.includes(origin.replace(/\/+$/, ''));
}
