import { Logger } from '@nestjs/common';
import type { Mailer } from '../domain/ports';

/**
 * Geliştirme mailer'ı — magic link'i loglar (gerçek SMTP göndermez). Gerçek sağlayıcı
 * (Brevo/Resend) API anahtarı bağlanınca tek adaptör değişimiyle takılır (docs/02 §3).
 */
export class LogMailer implements Mailer {
  private readonly logger = new Logger(LogMailer.name);

  async sendMagicLink(email: string, link: string): Promise<void> {
    this.logger.log(`[dev-mailer] magic link → ${email}: ${link}`);
  }
}
