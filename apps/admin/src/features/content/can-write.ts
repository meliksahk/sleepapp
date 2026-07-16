/**
 * Panelde içerik yazabilen roller. API'deki `@Roles('owner','editor')` ile AYNI
 * kümedir ve bilinçli olarak TEKRAR edilir: burası UI'ın ne göstereceğine karar
 * verir, gerçek kapı sunucudadır (#120).
 *
 * CLAUDE.md §3.3: "yalnızca UI gizleme yeterli değildir" — bu yüzden sunucu kapısı
 * ÖNCE yazıldı. Buradaki liste yalnızca yazamayacak birine boşuna form göstermemek
 * içindir; sızsa bile sunucu 403 döner (ve form o mesajı gösterir).
 */
const WRITE_ROLES = ['owner', 'editor'];

export function canWriteContent(roles: readonly string[]): boolean {
  return roles.some((r) => WRITE_ROLES.includes(r));
}
