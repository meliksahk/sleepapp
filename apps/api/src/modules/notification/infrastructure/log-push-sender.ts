import { Logger } from '@nestjs/common';
import type { PushMessage, PushSender, PushTarget } from '../domain/push-sender';

/**
 * Geliştirme adaptörü — gerçek APNs/FCM yerine loglar (docs/10'a dek). Port
 * sayesinde gerçek gönderici sonradan tek satırla takılır. Token loglanmaz (PII/gizli).
 */
export class LogPushSender implements PushSender {
  private readonly logger = new Logger('Push');

  async send(target: PushTarget, message: PushMessage): Promise<void> {
    // Token'ın yalnızca son 4 hanesi + platform — tam token loglanmaz.
    const tail = target.token.slice(-4);
    this.logger.log(`push → ${target.platform}:…${tail} "${message.title}"`);
  }
}
