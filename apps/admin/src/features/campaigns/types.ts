/** Kampanya fan-out sonucu — API `POST /v1/admin/campaigns` yanıtı (#183). */
export interface CampaignResult {
  recipients: number;
  sent: number;
  failed: number;
}
