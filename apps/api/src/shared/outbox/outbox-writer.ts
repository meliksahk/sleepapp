import { Prisma } from '@prisma/client';

import type { NewOutboxEvent } from './outbox.types';

/**
 * Outbox'a olay yazar — **çağıranın transaction'ı içinde**. Domain yazısı (ör. uyku
 * oturumu insert'i) ile AYNI `tx` üzerinden çağrılır: ikisi atomik commit olur. Böylece
 * "önce DB yaz sonra kuyruğa gönder" arasındaki çökme penceresi ortadan kalkar — olay ya
 * domain yazısıyla birlikte kalıcıdır ya da hiç yazılmaz.
 *
 * `tx` tipi bilerek `Prisma.TransactionClient`: writer kendi bağlantısını açmaz, çağıranın
 * transaction'ını kullanır (atomikliğin tek yolu budur).
 */
export class OutboxWriter {
  async append(tx: Prisma.TransactionClient, event: NewOutboxEvent): Promise<void> {
    await tx.outbox.create({
      data: {
        aggregate_type: event.aggregateType,
        event_type: event.eventType,
        payload: event.payload as Prisma.InputJsonValue,
      },
    });
  }
}
