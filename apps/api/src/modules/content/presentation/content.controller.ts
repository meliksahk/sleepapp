import { Controller, Get, NotFoundException, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { GetFeedUseCase } from '../application/get-feed.usecase';
import {
  GetSoundscapeUseCase,
  type SoundscapeDetailResult,
} from '../application/get-soundscape.usecase';
import { GetWeeklyReleaseUseCase } from '../application/get-weekly-release.usecase';
import { ListAudioAssetsUseCase } from '../application/list-audio-assets.usecase';
import { GetAudioAssetUseCase } from '../application/get-audio-asset.usecase';
import type { Soundscape, WeeklyRelease } from '../domain/soundscape';
import { parseMoodFilter, type AudioAsset } from '../domain/audio-asset';
import {
  AudioAssetDetailDto,
  AudioAssetDto,
  SoundscapeDetailDto,
  SoundscapeDto,
  WeeklyReleaseDto,
} from './dto';

@ApiTags('content')
@ApiBearerAuth()
@Controller('content')
@UseGuards(AuthGuard)
export class ContentController {
  constructor(
    private readonly getFeed: GetFeedUseCase,
    private readonly getSoundscape: GetSoundscapeUseCase,
    private readonly getWeekly: GetWeeklyReleaseUseCase,
    private readonly listAssets: ListAudioAssetsUseCase,
    private readonly getAsset: GetAudioAssetUseCase,
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

  /**
   * ⚠️ SIRA ÖNEMLİ: bu iki uç `soundscapes/:slug`'tan ÖNCE tanımlı olmalı diye bir
   * kısıt YOK (yollar ayrı: `audio-assets` vs `soundscapes`), ama tekil uç
   * (`audio-assets/:id`) listeden (`audio-assets`) sonra gelir — Nest'te sabit
   * segment dinamikten önce eşleşir, yine de okuyan için açık olsun.
   */
  @Get('audio-assets')
  @ApiOperation({
    summary: 'Ses dosyası kataloğu (tür/mood filtreli) — presigned URL İÇERMEZ',
  })
  @ApiQuery({ name: 'genre', required: false })
  @ApiQuery({
    name: 'mood',
    required: false,
    description: 'Virgülle ayrık; herhangi biri eşleşirse döner (örtüşme).',
  })
  @ApiOkResponse({ type: [AudioAssetDto] })
  async assets(
    @Query('genre') genre?: string,
    @Query('mood') mood?: string,
  ): Promise<AudioAssetDto[]> {
    const list = await this.listAssets.execute({
      genre: genre?.trim() || undefined,
      moods: parseMoodFilter(mood),
    });
    // AÇIK eşleme (spread DEĞİL): `key` iç depolama anahtarıdır ve dışarı
    // sızmamalı. Spread kullansaydık domain'e yarın eklenecek her alan sessizce
    // tele düşerdi — sızıntının en sık yolu budur.
    return list.map(toAssetDto);
  }

  @Get('audio-assets/:id')
  @ApiOperation({ summary: 'Tek ses dosyası + kısa ömürlü presigned URL' })
  @ApiOkResponse({ type: AudioAssetDetailDto })
  async asset(@Param('id') id: string): Promise<AudioAssetDetailDto> {
    const found = await this.getAsset.execute(id);
    if (!found) {
      throw new NotFoundException({ code: 'not_found', message: 'Ses dosyası bulunamadı.' });
    }
    return {
      asset: toAssetDto(found.asset),
      url: found.url,
      expiresInSeconds: found.expiresInSeconds,
    };
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

/** Domain → tel. `key` KASITLI olarak dışarıda bırakılır (bkz. `AudioAssetDto`). */
function toAssetDto(a: AudioAsset): AudioAssetDto {
  return {
    id: a.id,
    title: a.title,
    genre: a.genre,
    mood: [...a.mood],
    durationSeconds: a.durationSeconds,
    license: a.license,
    source: a.source,
  };
}
