import type { SendNotificationUseCase } from '../application/send-notification.usecase';
import type { CampaignJob, PushQueue } from '../domain/push-queue';

/**
 * Redis'siz fallback: teslimi HEMEN (senkron) yapar. Geliştirme ve testte kuyruk
 * altyapısı olmadan tam çalışır — davranış #183 öncesiyle aynı, yalnız port arkasında.
 *
 * Üretimde REDIS_URL varsa `BullMqPushQueue` bunun yerine bağlanır; tüketici (kampanya
 * use case) hangi adaptör olduğunu bilmez.
 */
export class InlinePushQueue implements PushQueue {
  constructor(private readonly send: SendNotificationUseCase) {}

  async enqueue(job: CampaignJob): Promise<void> {
    // SendNotificationUseCase opt-out + çok-cihaz fan-out'unu zaten ele alır.
    await this.send.execute(job.userId, { title: job.title, body: job.body });
  }
}
