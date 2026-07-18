import { Queue, Worker } from 'bullmq';
import IORedis from 'ioredis';

import type { SendNotificationUseCase } from '../application/send-notification.usecase';
import type { CampaignJob, PushQueue } from '../domain/push-queue';

/** Kuyruk adı sabit — producer ve worker aynı adı paylaşır. */
export const PUSH_QUEUE_NAME = 'push-campaign';

/**
 * Redis destekli asenkron push kuyruğu (BullMQ). Producer (Queue) + consumer (Worker)
 * aynı süreçte yaşar; teslim HTTP isteğinden ayrılır ve başarısız işler yeniden denenir.
 *
 * Bağlantı: BullMQ'nun blocking komutları (worker `BRPOPLPUSH`) `maxRetriesPerRequest: null`
 * ISTER — aksi halde IORedis çağrıyı sınırlar ve worker patlar. Queue ve Worker AYRI
 * bağlantı kullanır (bir blocking worker bağlantıyı meşgul eder; paylaşım kilitlenmeye yol açar).
 *
 * Yaşam döngüsü: `onModuleDestroy` worker + queue + iki bağlantıyı kapatır. Kapatılmazsa
 * açık Redis soketleri süreç/test event-loop'unu canlı tutar (RedisCache.onModuleDestroy
 * ile aynı gerekçe).
 */
export class BullMqPushQueue implements PushQueue {
  private readonly producerConn: IORedis;
  private readonly workerConn: IORedis;
  private readonly queue: Queue;
  private readonly worker: Worker;

  constructor(
    redisUrl: string,
    send: SendNotificationUseCase,
    queueName: string = PUSH_QUEUE_NAME,
  ) {
    this.producerConn = new IORedis(redisUrl, { maxRetriesPerRequest: null });
    this.workerConn = new IORedis(redisUrl, { maxRetriesPerRequest: null });

    this.queue = new Queue(queueName, { connection: this.producerConn });
    this.worker = new Worker(
      queueName,
      async (job) => {
        const { userId, title, body } = job.data as CampaignJob;
        // SendNotificationUseCase opt-out + çok-cihaz fan-out'unu ele alır. Fırlatırsa
        // BullMQ işi başarısız sayar ve `attempts`e göre yeniden dener.
        await send.execute(userId, { title, body });
      },
      { connection: this.workerConn },
    );
  }

  async enqueue(job: CampaignJob): Promise<void> {
    await this.queue.add('deliver', job, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 1000 },
      // Başarılıyı hemen at (kuyruk şişmesin); başarısızın son 100'ünü teşhis için tut.
      removeOnComplete: true,
      removeOnFail: 100,
    });
  }

  async onModuleDestroy(): Promise<void> {
    await this.worker.close();
    await this.queue.close();
    await this.producerConn.quit();
    await this.workerConn.quit();
  }
}
