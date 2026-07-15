import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { JoinWaitlistUseCase } from '../application/join-waitlist.usecase';
import { JoinWaitlistDto } from './dto';

/** Public bekleme listesi (docs/05 W0). Kimlik gerektirmez; IP rate-limit'li. */
@ApiTags('waitlist')
@Controller('waitlist')
@UseGuards(ThrottlerGuard)
@Throttle({ default: { limit: 10, ttl: 60_000 } })
export class WaitlistController {
  constructor(private readonly joinWaitlist: JoinWaitlistUseCase) {}

  @Post()
  @HttpCode(202)
  @ApiOperation({ summary: 'Bekleme listesine katıl' })
  async join(@Body() dto: JoinWaitlistDto): Promise<{ status: string }> {
    await this.joinWaitlist.execute(dto.email, dto.source ?? null);
    return { status: 'joined' };
  }
}
