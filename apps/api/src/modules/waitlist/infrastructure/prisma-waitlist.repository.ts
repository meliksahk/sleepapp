import type { WaitlistRepository } from '../domain/waitlist';
import type { PrismaService } from '../../../shared/infra/prisma.service';

export class PrismaWaitlistRepository implements WaitlistRepository {
  constructor(private readonly prisma: PrismaService) {}

  async add(email: string, source: string | null): Promise<void> {
    // upsert: aynı e-posta çakışmasında sessizce geçer (idempotent).
    await this.prisma.waitlist.upsert({
      where: { email },
      create: { email, source },
      update: {},
    });
  }

  async count(): Promise<number> {
    return this.prisma.waitlist.count();
  }
}
