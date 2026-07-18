import type { DeviceTokenRepository } from '../domain/device-token';
import type { SendNotificationUseCase } from './send-notification.usecase';

export interface CampaignResult {
  /** Segmentteki kullanıcı sayısı (push token'ı olanlar). */
  readonly recipients: number;
  /** FİİLEN gönderilen cihaz push'ları (opt-out yapanlar HARİÇ). */
  readonly sent: number;
  readonly failed: number;
}

/**
 * Admin kampanyası (#183): bir segmentteki tüm kullanıcılara push fan-out'u. Mevcut
 * `SendNotificationUseCase` üstüne kurulur — o her kullanıcının opt-out'unu ve cihazlarını
 * zaten ele alır; kampanya yalnızca segmenti çözüp her birine onu çağırır.
 *
 * **Segment = push token'ı olan kullanıcılar** (yalnızca onlar push alabilir); [platform]
 * ile daraltılabilir. Persist YOK (kampanya geçmişi ayrı iş — yeni tablo/migration ister,
 * §8 gereği önce sorulur). Teslim LogPushSender ile loglanır; gerçek APNs/FCM anahtar-kapılı
 * (docs/10). Async kuyruk (BullMQ) de docs/10'a ertelendi → şimdilik SENKRON (SendNotification
 * ile aynı, bilinçli).
 */
export class SendCampaignUseCase {
  constructor(
    private readonly tokens: DeviceTokenRepository,
    private readonly send: SendNotificationUseCase,
  ) {}

  async execute(title: string, body: string, platform?: string): Promise<CampaignResult> {
    const userIds = await this.tokens.findUserIdsWithTokens(platform);
    let sent = 0;
    let failed = 0;
    for (const userId of userIds) {
      const result = await this.send.execute(userId, { title, body });
      sent += result.sent;
      failed += result.failed;
    }
    return { recipients: userIds.length, sent, failed };
  }
}
