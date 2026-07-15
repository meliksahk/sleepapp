import type { DeviceTokenRepository } from '../domain/device-token';
import type { PrismaService } from '../../../shared/infra/prisma.service';

export class PrismaDeviceTokenRepository implements DeviceTokenRepository {
  constructor(private readonly prisma: PrismaService) {}

  async register(userId: string, token: string, platform: string): Promise<void> {
    const now = new Date();
    await this.prisma.device_tokens.upsert({
      where: { token },
      create: { user_id: userId, token, platform, last_seen_at: now },
      // Cihaz hesap değiştirdiyse user_id yeniden atanır.
      update: { user_id: userId, platform, last_seen_at: now },
    });
  }
}
