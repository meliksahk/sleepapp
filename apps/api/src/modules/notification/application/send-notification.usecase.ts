import type { DeviceTokenRepository } from '../domain/device-token';
import type { NotificationPreferenceReader } from '../domain/notification-preference';
import type { PushMessage, PushSender } from '../domain/push-sender';

export interface FanOutResult {
  readonly sent: number;
  readonly failed: number;
}

/**
 * Bir kullanıcının tüm cihazlarına push fan-out'u (docs/02 B3). Hedef başına izole:
 * bir token başarısız olursa (ör. süresi dolmuş) diğerleri yine gönderilir.
 * Opt-out: kullanıcı profilinde bildirimleri kapattıysa (notifications_enabled=false)
 * hiç gönderilmez (docs/06).
 * NOT: şu an SENKRON gönderir; güvenilir asenkron teslim (BullMQ + Redis worker,
 * outbox) ve gerçek APNs/FCM adaptörü docs/10'a ertelendi.
 */
export class SendNotificationUseCase {
  constructor(
    private readonly tokens: DeviceTokenRepository,
    private readonly sender: PushSender,
    private readonly preferences: NotificationPreferenceReader,
  ) {}

  async execute(userId: string, message: PushMessage): Promise<FanOutResult> {
    // Opt-out: kullanıcı bildirimleri kapattıysa cihaz sorgulamadan çık.
    if (!(await this.preferences.isEnabledFor(userId))) {
      return { sent: 0, failed: 0 };
    }

    const targets = await this.tokens.findTokensByUser(userId);
    let sent = 0;
    let failed = 0;

    for (const target of targets) {
      try {
        await this.sender.send(target, message);
        sent++;
      } catch {
        // Hedef başına izole — biri düşse de diğerleri denenir. Ölü token temizliği B3+.
        failed++;
      }
    }

    return { sent, failed };
  }
}
