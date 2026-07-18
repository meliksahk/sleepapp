import type { OnModuleDestroy, OnModuleInit } from '@nestjs/common';

import type { OutboxRecord, OutboxRepository } from '../../../shared/outbox/outbox.types';
import type { PushQueue } from '../domain/push-queue';

const POLL_INTERVAL_MS = 5_000;
const BATCH = 100;

/**
 * Outbox relay: yayınlanmamış domain olaylarını çeker, tüketiciye dispatch eder, yayınlandı
 * damgalar. Poll tabanlı (basit + güvenilir): süreç çökse de olaylar tabloda kalır, bir
 * sonraki turda yayınlanır — outbox'ın bütün amacı budur.
 *
 * **Gözlemlenebilir tüketici (müdür sert kısıtı):** 'sleep.session_recorded' olayı bir push
 * bildirimini kuyruğa alır (PushQueue #190 → worker → SendNotificationUseCase). Yani uyku
 * oturumu kaydı → "gece raporun hazır" bildirimi. Zincir gerçek ve testli; yalnız nihai
 * APNs/FCM teslimi anahtar-kapılı (LogPushSender, docs/10).
 *
 * Testte interval ÇALIŞMAZ (NODE_ENV=test): paylaşımlı DB'de başka testlerin outbox
 * satırlarını yakalayıp parazit yapardı. Testler `relayOnce()`'ı DOĞRUDAN çağırır
 * (deterministik). Prod'da interval poll eder.
 */
export class OutboxRelay implements OnModuleInit, OnModuleDestroy {
  private timer: ReturnType<typeof setInterval> | undefined;

  constructor(
    private readonly outbox: OutboxRepository,
    private readonly queue: PushQueue,
  ) {}

  onModuleInit(): void {
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => {
      // Poll hatası bir sonraki turda yeniden denenir (olaylar yayınlanmamış kalır).
      void this.relayOnce().catch(() => undefined);
    }, POLL_INTERVAL_MS);
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /** Bir tur: yayınlanmamışları çek → dispatch → damgala. Yayınlanan olay sayısını döner. */
  async relayOnce(): Promise<number> {
    const events = await this.outbox.findUnpublished(BATCH);
    let published = 0;
    for (const event of events) {
      await this.dispatch(event);
      // Dispatch başarılıysa damgala. Başarısızsa (throw) damgalanmaz → sonraki tur yeniden dener.
      await this.outbox.markPublished(event.id);
      published++;
    }
    return published;
  }

  private async dispatch(event: OutboxRecord): Promise<void> {
    if (event.eventType === 'sleep.session_recorded') {
      const userId = typeof event.payload.userId === 'string' ? event.payload.userId : '';
      if (userId.length > 0) {
        await this.queue.enqueue({
          userId,
          title: 'Your night report is ready',
          body: 'See last night’s sleep summary in the app.',
        });
      }
    }
    // Bilinmeyen olay tipleri: dispatch yok ama damgalanır (kuyrukta sonsuza kalmaz).
  }
}
