import { Queue, Worker } from 'bullmq';
import IORedis from 'ioredis';

import type {
  CleanupOrphanSoundsUseCase,
  CleanupReport,
} from '../application/cleanup-orphan-sounds.usecase';

/** Kuyruk adı sabit — producer ve worker aynı adı paylaşır. */
export const COMMUNITY_CLEANUP_QUEUE = 'user-sounds-cleanup';

/**
 * Topluluk sesleri günlük temizlik işi (BullMQ repeatable).
 *
 * **ENV-GATE (notification modülüyle aynı desen):** `redisUrl: null` verilirse
 * sınıf İNERT doğar — bağlantı açmaz, iş kurmaz, hook'ları no-op'tur. Böylece
 * provider fabrikası koşulsuz instance üretebilir ve Nest yaşam döngüsünü
 * OTOMATİK yönetir (`onModuleDestroy`; RedisCache/BullMqPushQueue ile aynı).
 *
 * Yaşam döngüsü: iki ayrı IORedis bağlantısı (blocking worker paylaşılamaz),
 * `maxRetriesPerRequest: null` şartı, kapanışta hepsinin quit'lenmesi.
 * Worker `error` olayı DINLENIR: dinlenmeyen error event'i test sürecinde
 * "Unhandled error" olarak paketi düşürür (bu dosyanın ilk hatası tam buydu).
 */
export class CommunityCleanupScheduler {
  private readonly producerConn?: IORedis;
  private readonly workerConn?: IORedis;
  private readonly queue?: Queue;
  private readonly worker?: Worker;

  constructor(
    /** null → INERT mod: hiçbir kaynak açılmaz (lokal test / CI / redis yok). */
    redisUrl: string | null,
    cleanup: CleanupOrphanSoundsUseCase,
  ) {
    if (!redisUrl) return;

    this.producerConn = new IORedis(redisUrl, { maxRetriesPerRequest: null });
    this.workerConn = new IORedis(redisUrl, { maxRetriesPerRequest: null });

    this.queue = new Queue(COMMUNITY_CLEANUP_QUEUE, { connection: this.producerConn });
    this.worker = new Worker(
      COMMUNITY_CLEANUP_QUEUE,
      async () => {
        const report: CleanupReport = await cleanup.execute();
        if (report.abandonedSlots + report.expiredRejections + report.orphanObjects > 0) {
          // Sessiz temizlik YOK: neyin silindiği logda kalsın (denetlenebilirlik).
          // eslint-disable-next-line no-console
          console.log('[community] cleanup:', report);
        }
      },
      { connection: this.workerConn },
    );
    // Dinlenmeyen 'error', Node sürecinde unhandled error olarak patlar.
    this.worker.on('error', (e) => {
      console.error('[community] cleanup worker hatası:', e.message);
    });
    this.queue.on('error', (e) => {
      console.error('[community] cleanup queue hatası:', e.message);
    });

    // Repeatable job tanımı idempotenttir (aynı repeat key upsert edilir).
    void this.queue
      .add(
        'sweep',
        {},
        {
          // Her gün 03:00 (sunucu saati): trafiğin en düşük olduğu pencere.
          repeat: { pattern: '0 3 * * *' },
          removeOnComplete: true,
          removeOnFail: 30,
        },
      )
      .catch((e: unknown) => {
        console.error('[community] cleanup job schedule edilemedi:', e);
      });
  }

  get isActive(): boolean {
    return this.queue !== undefined;
  }

  async onModuleDestroy(): Promise<void> {
    if (!this.isActive) return;
    await this.worker?.close();
    await this.queue?.close();
    await this.producerConn?.quit();
    await this.workerConn?.quit();
  }
}
