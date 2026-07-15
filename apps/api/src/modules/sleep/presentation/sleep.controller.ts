import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
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
import { SleepError } from '../domain/errors';
import type { SleepSession } from '../domain/sleep-session.entity';
import { RecordSleepSessionDto, SleepSessionDto } from './dto';

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
  @ApiOperation({ summary: 'Kullanıcının en yeni uyku oturumları' })
  @ApiQuery({ name: 'limit', required: false })
  @ApiOkResponse({ type: [SleepSessionDto] })
  async recent(
    @CurrentUser() user: AccessTokenClaims,
    @Query('limit') limit?: string,
  ): Promise<SleepSessionDto[]> {
    const parsed = limit ? Number.parseInt(limit, 10) : undefined;
    const sessions = await this.list.execute(user.sub, Number.isNaN(parsed) ? undefined : parsed);
    return sessions.map(toDto);
  }
}
