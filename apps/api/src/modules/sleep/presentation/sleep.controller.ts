import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  NotFoundException,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { RecordSleepSessionUseCase } from '../application/record-sleep-session.usecase';
import { ListSleepSessionsUseCase } from '../application/list-sleep-sessions.usecase';
import { GetNightReportUseCase } from '../application/get-night-report.usecase';
import { GetStreakUseCase } from '../application/get-streak.usecase';
import { GetSleepStatsUseCase } from '../application/get-sleep-stats.usecase';
import { SleepError } from '../domain/errors';
import type { SleepSession } from '../domain/sleep-session.entity';
import {
  NightReportDto,
  RecordSleepSessionDto,
  SleepSessionDto,
  SleepStatsDto,
  StreakDto,
} from './dto';

const NIGHT_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function toDto(s: SleepSession): SleepSessionDto {
  return {
    id: s.id,
    startedAt: s.startedAt.toISOString(),
    endedAt: s.endedAt.toISOString(),
    nightDate: s.nightDate,
    durationMinutes: s.durationMinutes,
    movementEvents: s.movementEvents,
    soundEvents: s.soundEvents,
  };
}

@ApiTags('sleep')
@ApiBearerAuth()
@Controller('sleep')
@UseGuards(AuthGuard)
export class SleepController {
  constructor(
    private readonly record: RecordSleepSessionUseCase,
    private readonly list: ListSleepSessionsUseCase,
    private readonly report: GetNightReportUseCase,
    private readonly streak: GetStreakUseCase,
    private readonly stats: GetSleepStatsUseCase,
  ) {}

  @Post('sessions')
  @HttpCode(201)
  @ApiOperation({ summary: 'Uyku oturumu kaydı (on-device türetilmiş metrikler)' })
  @ApiCreatedResponse({ type: SleepSessionDto })
  async create(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: RecordSleepSessionDto,
  ): Promise<SleepSessionDto> {
    try {
      const session = await this.record.execute(user.sub, {
        startedAt: new Date(dto.startedAt),
        endedAt: new Date(dto.endedAt),
        movementEvents: dto.movementEvents,
        soundEvents: dto.soundEvents,
      });
      return toDto(session);
    } catch (e) {
      if (e instanceof SleepError) {
        throw new BadRequestException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }

  @Get('sessions')
  @ApiOperation({ summary: 'Uyku oturumları — en yeni N veya gece aralığı (from+to)' })
  @ApiQuery({ name: 'limit', required: false })
  @ApiQuery({ name: 'from', required: false, example: '2026-07-01' })
  @ApiQuery({ name: 'to', required: false, example: '2026-07-31' })
  @ApiOkResponse({ type: [SleepSessionDto] })
  async recent(
    @CurrentUser() user: AccessTokenClaims,
    @Query('limit') limit?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ): Promise<SleepSessionDto[]> {
    // Aralık: from ve to birlikte, geçerli YYYY-MM-DD ve from <= to olmalı.
    if (from !== undefined || to !== undefined) {
      if (!from || !to || !NIGHT_DATE_RE.test(from) || !NIGHT_DATE_RE.test(to) || from > to) {
        throw new BadRequestException({
          code: 'invalid_range',
          message: 'from ve to birlikte, YYYY-MM-DD ve from <= to olmalı.',
        });
      }
      const ranged = await this.list.execute(user.sub, { from, to });
      return ranged.map(toDto);
    }
    const parsed = limit ? Number.parseInt(limit, 10) : undefined;
    const sessions = await this.list.execute(user.sub, {
      limit: parsed !== undefined && Number.isNaN(parsed) ? undefined : parsed,
    });
    return sessions.map(toDto);
  }

  @Get('report')
  @ApiOperation({ summary: 'Bir gecenin uyku raporu (özet + paylaşılabilir kart verisi)' })
  @ApiQuery({ name: 'night', required: true, example: '2026-07-15' })
  @ApiOkResponse({ type: NightReportDto })
  async nightReport(
    @CurrentUser() user: AccessTokenClaims,
    @Query('night') night?: string,
  ): Promise<NightReportDto> {
    if (!night || !NIGHT_DATE_RE.test(night)) {
      throw new BadRequestException({
        code: 'invalid_night',
        message: 'night parametresi YYYY-MM-DD olmalı.',
      });
    }
    const report = await this.report.execute(user.sub, night);
    if (!report) {
      throw new NotFoundException({ code: 'no_report', message: 'Bu gece için oturum yok.' });
    }
    return report;
  }

  @Get('streak')
  @ApiOperation({ summary: 'Kullanıcının uyku serisi (current/longest/totalNights)' })
  @ApiOkResponse({ type: StreakDto })
  streakStats(@CurrentUser() user: AccessTokenClaims): Promise<StreakDto> {
    return this.streak.execute(user.sub);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Uyku istatistikleri (gece sayısı, toplam/ortalama süre)' })
  @ApiOkResponse({ type: SleepStatsDto })
  sleepStats(@CurrentUser() user: AccessTokenClaims): Promise<SleepStatsDto> {
    return this.stats.execute(user.sub);
  }
}
