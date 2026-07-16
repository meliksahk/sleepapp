/**
 * Açık yönlendirme (open redirect) koruması.
 *
 * `next` kullanıcıdan (URL'den) gelir. Doğrulanmazsa
 * `/login?next=https://kotu.site` ile kullanıcı, giriş yaptıktan HEMEN SONRA
 * saldırganın sayfasına atılırdı — üstelik "panelden geldim" güveniyle. Klasik
 * kimlik avı taşıyıcısı.
 *
 * Yalnızca panel içi MUTLAK yol kabul edilir; geri kalan her şey köke düşer.
 */
export function safeNextPath(next: string | undefined): string {
  if (next === undefined || !next.startsWith('/')) return '/';
  // '//kotu.site' ve '/\kotu.site' protokol-bağımsız URL'lerdir: tarayıcı bunları
  // DIŞ adres olarak çözer, ama ikisi de '/' ile başlar → tek başına yetmez.
  if (next.startsWith('//') || next.startsWith('/\\')) return '/';
  return next;
}
