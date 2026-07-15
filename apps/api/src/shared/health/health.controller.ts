import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../infra/prisma.service';

@ApiTags('health')
@Controller()
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /** Liveness — bağımlılık kontrol etmez (load balancer için hızlı). Prefix'siz. */
  @Get('health')
  health(): { status: 'ok'; uptime: number } {
    return { status: 'ok', uptime: Math.round(process.uptime()) };
  }

  /** Readiness — DB erişilebilir mi (deploy/rollout kontrolü, docs/02). */
  @Get('health/ready')
  async ready(): Promise<{ status: 'ok'; db: 'up' }> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { status: 'ok', db: 'up' };
    } catch {
      throw new ServiceUnavailableException({ status: 'degraded', db: 'down' });
    }
  }
}
