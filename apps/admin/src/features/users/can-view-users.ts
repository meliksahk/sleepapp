/**
 * Panelde kullanıcı arayabilen roller. API'deki `@Roles('owner','support')` ile AYNI
 * kümedir ve bilinçli TEKRAR edilir: burası UI'ın ne göstereceğine karar verir, gerçek
 * kapı sunucudadır (CLAUDE.md §3.3 "yalnızca UI gizleme yeterli değildir" — sunucu
 * ÖNCE 403 verir). E-posta PII olduğu için editor/analyst göremez.
 */
const VIEW_USER_ROLES = ['owner', 'support'];

export function canViewUsers(roles: readonly string[]): boolean {
  return roles.some((r) => VIEW_USER_ROLES.includes(r));
}
