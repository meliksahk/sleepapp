import type { DeviceTokenRepository } from '../domain/device-token';
import type { PushTarget } from '../domain/push-sender';
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

  async findTokensByUser(userId: string): Promise<PushTarget[]> {
    const rows = await this.prisma.device_tokens.findMany({
      where: { user_id: userId },
      select: { token: true, platform: true },
    });
    return rows.map((r) => ({ token: r.token, platform: r.platform }));
  }
}
