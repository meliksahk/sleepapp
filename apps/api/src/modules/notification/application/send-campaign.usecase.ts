import type { DeviceTokenRepository } from '../domain/device-token';
import type { PushQueue } from '../domain/push-queue';

export interface CampaignResult {
  /** Segmentteki kullanıcı sayısı (push token'ı olanlar). */
  readonly recipients: number;
  /** Teslim için kuyruğa alınan iş sayısı (= recipients). Fiili gönderim ASENKRON worker'da. */
  readonly queued: number;
}

/**
 * Admin kampanyası (#183): bir segmentteki tüm kullanıcılara push fan-out'u.
 *
 * **Asenkron (BullMQ, #190):** segmenti çözer ve her alıcı için bir teslim işini
 * `PushQueue`'ya alır — HTTP isteği içinde teslim beklemez. Binlerce kullanıcıda senkron
 * fan-out isteği zaman aşımına uğratırdı; kuyruk teslimi istekten ayırır ve worker
 * başarısızları yeniden dener. Owner anında `{recipients, queued}` alır; fiili sent/failed
 * worker tarafında olur (teslim LogPushSender ile loglanır; gerçek APNs/FCM anahtar-kapılı,
 * docs/10). Redis yoksa `InlinePushQueue` aynı işi senkron yapar (dev/test).
 *
 * **Segment = push token'ı olan kullanıcılar**; [platform] ile daraltılabilir. Persist YOK
 * (kampanya geçmişi ayrı iş — yeni tablo/migration ister, §8 gereği önce sorulur).
 */
export class SendCampaignUseCase {
  constructor(
    private readonly tokens: DeviceTokenRepository,
    private readonly queue: PushQueue,
  ) {}

  async execute(title: string, body: string, platform?: string): Promise<CampaignResult> {
    const userIds = await this.tokens.findUserIdsWithTokens(platform);
    for (const userId of userIds) {
      await this.queue.enqueue({ userId, title, body });
    }
    return { recipients: userIds.length, queued: userIds.length };
  }
}
