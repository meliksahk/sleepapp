/**
 * Kampanya fan-out sonucu — API `POST /v1/admin/campaigns` yanıtı (#183 → #190 asenkron).
 * Fan-out artık BullMQ kuyruğuyla asenkron: yanıt fiili teslimi değil, kaç işin sıraya
 * konduğunu bildirir (sent/failed istek anında bilinemez — teslim worker'da).
 */
export interface CampaignResult {
  recipients: number;
  queued: number;
}
