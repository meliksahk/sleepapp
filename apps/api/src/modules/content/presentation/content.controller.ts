import { Controller, Get, NotFoundException, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { GetFeedUseCase } from '../application/get-feed.usecase';
import {
  GetSoundscapeUseCase,
  type SoundscapeDetailResult,
} from '../application/get-soundscape.usecase';
import { GetWeeklyReleaseUseCase } from '../application/get-weekly-release.usecase';
import type { Soundscape, WeeklyRelease } from '../domain/soundscape';
import { SoundscapeDetailDto, SoundscapeDto, WeeklyReleaseDto } from './dto';

@ApiTags('content')
@ApiBearerAuth()
@Controller('content')
@UseGuards(AuthGuard)
export class ContentController {
  constructor(
    private readonly getFeed: GetFeedUseCase,
    private readonly getSoundscape: GetSoundscapeUseCase,
    private readonly getWeekly: GetWeeklyReleaseUseCase,
  ) {}

  @Get('feed')
  @ApiOperation({
    summary: 'Soundscape feed — archetype verilmezse kullanıcının kendi kimliğine göre sıralı',
  })
  @ApiQuery({ name: 'archetype', required: false })
  @ApiOkResponse({ type: [SoundscapeDto] })
  feed(
    @CurrentUser() user: AccessTokenClaims,
    @Query('archetype') archetype?: string,
  ): Promise<Soundscape[]> {
    return this.getFeed.execute(user.sub, archetype);
  }

  @Get('weekly')
  @ApiOperation({ summary: 'En güncel haftalık soundscape yayını' })
  @ApiOkResponse({ type: WeeklyReleaseDto })
  async weekly(): Promise<WeeklyRelease> {
    const release = await this.getWeekly.execute();
    if (!release) {
      throw new NotFoundException({ code: 'no_release', message: 'Henüz haftalık yayın yok.' });
    }
    return release;
  }

  @Get('soundscapes/:slug')
  @ApiOperation({ summary: 'Yayınlanmış soundscape + preset detayları' })
  @ApiOkResponse({ type: SoundscapeDetailDto })
  async detail(@Param('slug') slug: string): Promise<SoundscapeDetailResult> {
    const found = await this.getSoundscape.execute(slug);
    if (!found) {
      throw new NotFoundException({ code: 'not_found', message: 'Soundscape bulunamadı.' });
    }
    return found;
  }
}
