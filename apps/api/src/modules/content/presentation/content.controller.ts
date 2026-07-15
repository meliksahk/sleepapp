import { Controller, Get, NotFoundException, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '../../identity';
import { GetFeedUseCase } from '../application/get-feed.usecase';
import { GetSoundscapeUseCase } from '../application/get-soundscape.usecase';
import type { Soundscape, SoundscapeDetail } from '../domain/soundscape';
import { SoundscapeDetailDto, SoundscapeDto } from './dto';

@ApiTags('content')
@ApiBearerAuth()
@Controller('content')
@UseGuards(AuthGuard)
export class ContentController {
  constructor(
    private readonly getFeed: GetFeedUseCase,
    private readonly getSoundscape: GetSoundscapeUseCase,
  ) {}

  @Get('feed')
  @ApiOperation({ summary: 'Yayınlanmış soundscape feed (archetype affinity sıralı)' })
  @ApiQuery({ name: 'archetype', required: false })
  @ApiOkResponse({ type: [SoundscapeDto] })
  feed(@Query('archetype') archetype?: string): Promise<Soundscape[]> {
    return this.getFeed.execute(archetype);
  }

  @Get('soundscapes/:slug')
  @ApiOperation({ summary: 'Yayınlanmış soundscape + preset detayları' })
  @ApiOkResponse({ type: SoundscapeDetailDto })
  async detail(@Param('slug') slug: string): Promise<SoundscapeDetail> {
    const found = await this.getSoundscape.execute(slug);
    if (!found) {
      throw new NotFoundException({ code: 'not_found', message: 'Soundscape bulunamadı.' });
    }
    return found;
  }
}
