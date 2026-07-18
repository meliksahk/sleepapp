// notification public API — diğer modüller (admin kampanya) YALNIZCA buradan tüketir (docs/02 §2).
export { NotificationModule } from './notification.module';
export { SendNotificationUseCase } from './application/send-notification.usecase';
export { SendCampaignUseCase } from './application/send-campaign.usecase';
export type { CampaignResult } from './application/send-campaign.usecase';
export { CountPushAudienceUseCase } from './application/count-push-audience.usecase';
