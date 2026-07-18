/**
 * Panelde push kampanyası gönderebilen roller. API'deki `@Roles('owner')` ile AYNI
 * kümedir ve bilinçli TEKRAR edilir: burası UI'ın formu KİME göstereceğine karar verir,
 * gerçek kapı sunucudadır (#183 — API önce 403 verir). Kampanya TÜM tabana ulaşır →
 * içerik editöründen dar: YALNIZCA owner.
 */
const SEND_CAMPAIGN_ROLES = ['owner'];

export function canSendCampaigns(roles: readonly string[]): boolean {
  return roles.some((r) => SEND_CAMPAIGN_ROLES.includes(r));
}
