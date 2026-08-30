import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  Post,
  UnprocessableEntityException,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';

import { AuthGuard, CurrentUser } from '../../identity';
import type { AccessTokenClaims } from '../../identity';
import { Throttle } from '@nestjs/throttler';
import { CompleteSoundUploadUseCase } from '../application/complete-sound-upload.usecase';
import { CreateSoundUploadUseCase } from '../application/create-sound-upload.usecase';
import { ListMySoundsUseCase } from '../application/moderate-and-list.usecase';
import {
  PendingLimitReachedError,
  SoundNotFoundError,
  SoundNotOwnedError,
  UploadIncompleteError,
} from '../domain/errors';
import { SoundUploadSlotDto, UserSoundDto, CreateSoundUploadDto } from './dto';
import type { UserSound } from '../domain/user-sound';

function toDto(s: UserSound): UserSoundDto {
  return {
    id: s.id,
    title: s.title,
    status: s.status,
    byteSize: s.byteSize,
    durationSeconds: s.durationSeconds,
    rejectionReason: s.rejectionReason,
    createdAt: s.createdAt.toISOString(),
  };
}

/**
 * Kullanıcının topluluk paylaşım uçları — HER SORGU token sahibiyle kapsamlanır.
 * `soundId` yolda gelse bile use case sahiplik kontrolü yapar; controller'da
 * iş mantığı YOKTUR (CLAUDE.md §3.2), yalnızca hata→HTTP çevirisi vardır.
 */
@Controller('me/sounds')
@UseGuards(AuthGuard)
@ApiTags('community')
@ApiBearerAuth()
export class CommunityController {
  constructor(
    private readonly createUpload: CreateSoundUploadUseCase,
    private readonly completeUpload: CompleteSoundUploadUseCase,
    private readonly listMine: ListMySoundsUseCase,
  ) {}

  @Post()
  // Slot açma SAATTE 10: pending tavanı (10) zaten sınırdır; bu throttle yalnızca
  // hızlı CHURN'ü (aç-kapa-dene döngüsü) kırar. Global throttler üstüne ekstra sıkılık.
  @Throttle({ default: { limit: 10, ttl: 60 * 60 * 1000 } })
  @ApiOperation({ summary: 'Yükleme slotu aç: kayıt + presigned PUT URL' })
  @ApiCreatedResponse({ type: SoundUploadSlotDto })
  async create(
    @CurrentUser() claims: AccessTokenClaims,
    @Body() body: CreateSoundUploadDto,
  ): Promise<SoundUploadSlotDto> {
    try {
      return await this.createUpload.execute(claims.sub, body);
    } catch (e) {
      if (e instanceof PendingLimitReachedError) {
        throw new UnprocessableEntityException(e.message);
      }
      // Saf doğrulayıcılar TypeError fırlatır; ValidationPipe alan kurallarını
      // zaten yakalar ama trim-sonrası boşluk gibi ikinci katman burada düşer.
      throw new BadRequestException(
        e instanceof Error && e.message.startsWith('invalid_')
          ? 'Başlık veya süre geçersiz.'
          : 'Paylaşım oluşturulamadı.',
      );
    }
  }

  @Post(':id/uploaded')
  // 201 DEĞİL 200: kaynak (kayıt) slot açılışında yaratıldı; bu çağrı bir
  // DOĞRULAMA bildirimidir — yeni bir şey üretmez, mevcut durumu işaretler.
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'PUT bitti bildirimi — depoda HEAD ile doğrulanır' })
  @ApiOkResponse({ description: 'Dosya doğrulandı, moderasyon kuyruğunda' })
  async uploaded(
    @CurrentUser() claims: AccessTokenClaims,
    @Param('id') id: string,
  ): Promise<{ ok: true }> {
    try {
      await this.completeUpload.execute(claims.sub, id);
      return { ok: true };
    } catch (e) {
      if (e instanceof SoundNotFoundError) throw new NotFoundException(e.message);
      if (e instanceof SoundNotOwnedError) {
        // Varlığı bile ifşa etmemek için 404 (bkz. errors.ts).
        throw new NotFoundException(new SoundNotFoundError().message);
      }
      if (e instanceof UploadIncompleteError) {
        throw new UnprocessableEntityException(e.message);
      }
      throw e;
    }
  }

  @Get()
  @ApiOperation({ summary: 'Kendi paylaşımlarım ve durumları' })
  @ApiOkResponse({ type: [UserSoundDto] })
  async mine(@CurrentUser() claims: AccessTokenClaims): Promise<UserSoundDto[]> {
    const items = await this.listMine.execute(claims.sub);
    return items.map(toDto);
  }
}
