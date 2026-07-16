import {
  BadRequestException,
  Controller,
  Get,
  NotFoundException,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { GetArchetypeShareUseCase } from '../application/get-archetype-share.usecase';
import { GetReportShareUseCase } from '../application/get-report-share.usecase';
import type { ArchetypeShare } from '../domain/share';
import type { NightReportShare } from '../domain/report-share';
import { ArchetypeShareDto, NightReportShareDto } from './dto';

const NIGHT_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

@ApiTags('sharing')
@ApiBearerAuth()
@Controller('sharing')
@UseGuards(AuthGuard)
export class SharingController {
  constructor(
    private readonly getShare: GetArchetypeShareUseCase,
    private readonly getReportShare: GetReportShareUseCase,
  ) {}

  @Get('archetype')
  @ApiOperation({ summary: 'Kullanıcının archetype sonucundan paylaşım kartı + deep link' })
  @ApiOkResponse({ type: ArchetypeShareDto })
  async archetype(@CurrentUser() user: AccessTokenClaims): Promise<ArchetypeShare> {
    const share = await this.getShare.execute(user.sub);
    if (!share) {
      throw new NotFoundException({
        code: 'no_result',
        message: 'Paylaşılacak archetype sonucu yok — önce testi tamamlayın.',
      });
    }
    return share;
  }

  @Get('report')
  @ApiOperation({ summary: 'Bir gecenin raporundan paylaşım kartı (gece raporu, viral kanca #2)' })
  @ApiQuery({ name: 'night', required: true, example: '2026-07-15' })
  @ApiOkResponse({ type: NightReportShareDto })
  async report(
    @CurrentUser() user: AccessTokenClaims,
    @Query('night') night?: string,
  ): Promise<NightReportShare> {
    if (!night || !NIGHT_DATE_RE.test(night)) {
      throw new BadRequestException({
        code: 'invalid_night',
        message: 'night parametresi YYYY-MM-DD olmalı.',
      });
    }
    const share = await this.getReportShare.execute(user.sub, night);
    if (!share) {
      throw new NotFoundException({ code: 'no_report', message: 'Bu gece için rapor yok.' });
    }
    return share;
  }
}
