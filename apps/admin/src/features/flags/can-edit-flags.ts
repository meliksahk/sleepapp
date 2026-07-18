/**
 * Panelde flag düzenleyebilen roller. API'deki `@Roles('owner')` ile AYNI kümedir ve
 * bilinçli TEKRAR edilir: burası UI'ın formu KİME göstereceğine karar verir, gerçek
 * kapı sunucudadır (#167 — API önce 403 verir). Flag'ler her özelliğin rollout'unu
 * kontrol eder → içerik editöründen (owner+editor) dar: YALNIZCA owner.
 */
const EDIT_FLAG_ROLES = ['owner'];

export function canEditFlags(roles: readonly string[]): boolean {
  return roles.some((r) => EDIT_FLAG_ROLES.includes(r));
}
