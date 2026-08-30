import {
  BadRequestException,
  ConflictException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, Roles, RolesGuard } from '../../identity';
import type { AccessTokenClaims } from '../../identity';

import {
  ListSoundsForModerationUseCase,
  GetSoundPreviewUseCase,
  ModerateSoundUseCase,
  PREVIEW_EXPIRY_SECONDS,
} from '../application/moderate-and-list.usecase';
import { SoundNotFoundError } from '../domain/errors';
import type { UserSoundStatus } from '../domain/user-sound';
import { AdminUserSoundDto, ModerateSoundDto } from './dto';

const STATUS_RE = /^(pending|approved|rejected)$/;

function toAdminDto(s: {
  id: string;
  userId: string;
  title: string;
  status: string;
  byteSize: number | null;
  durationSeconds: number;
  rejectionReason: string | null;
  moderatedAt: Date | null;
  createdAt: Date;
}): AdminUserSoundDto {
  return {
    id: s.id,
    userId: s.userId,
    title: s.title,
    status: s.status,
    byteSize: s.byteSize,
    durationSeconds: s.durationSeconds,
    rejectionReason: s.rejectionReason,
    moderatedAt: s.moderatedAt?.toISOString() ?? null,
    createdAt: s.createdAt.toISOString(),
  };
}

/**
 * Topluluk moderasyonu — admin paneli uçları.
 *
 * Ayrı controller (admin.controller'a eklemek yerine): community modülünün
 * kendi yüzeyi; kimlik/rol kapıları identity modülünden gelir (public export).
 * Moderasyon bir EDITORYAL karardır → editor + owner. `analyst` salt-okunur
 * olduğundan bu uca erişemez; `support` da aynı şekilde.
 */
@Controller('admin/community-sounds')
@UseGuards(AuthGuard, RolesGuard)
@Roles('owner', 'editor')
@ApiTags('admin-community')
@ApiBearerAuth()
export class AdminCommunityController {
  constructor(
    private readonly listForModeration: ListSoundsForModerationUseCase,
    private readonly moderate: ModerateSoundUseCase,
    private readonly preview: GetSoundPreviewUseCase,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Moderasyon listesi (durum filtreli)' })
  @ApiOkResponse({ type: [AdminUserSoundDto] })
  @ApiQuery({ name: 'status', enum: ['pending', 'approved', 'rejected'], required: false })
  async list(@Query('status') status?: string): Promise<AdminUserSoundDto[]> {
    const resolved: UserSoundStatus = STATUS_RE.test(status ?? '')
      ? (status as UserSoundStatus)
      : 'pending';
    const { items } = await this.listForModeration.execute(resolved);
    return items.map(toAdminDto);
  }

  @Get(':id/file')
  @ApiOperation({ summary: 'Moderatör önizlemesi: kısa ömürlü dinleme URL’i (10 dk)' })
  @ApiOkResponse({
    schema: {
      type: 'object',
      properties: { url: { type: 'string' }, expiresIn: { type: 'number' } },
    },
  })
  async file(@Param('id') id: string): Promise<{ url: string; expiresIn: number }> {
    try {
      const p = await this.preview.execute(id);
      return { url: p.url, expiresIn: PREVIEW_EXPIRY_SECONDS };
    } catch (e) {
      if (e instanceof SoundNotFoundError) throw new NotFoundException(e.message);
      throw e;
    }
  }

  @Post(':id/moderate')
  // 201 DEĞİL 200: karar UYGULAMADIR, yeni kaynak yaratmaz (uploaded ile aynı
  // ilke — RPC tarzı eylemler Created demez).
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Onayla / reddet (redde gerekçe zorunlu)' })
  @ApiOkResponse({ type: AdminUserSoundDto })
  async decide(
    // claims parametresi bilinçli: ileride admin_audit_log'a moderator_id yazılacak.
    @CurrentUser() _claims: AccessTokenClaims,
    @Param('id') id: string,
    @Body() body: ModerateSoundDto,
  ): Promise<AdminUserSoundDto> {
    try {
      const updated = await this.moderate.execute({
        soundId: id,
        decision: body.decision,
        rejectionReason: body.rejectionReason,
      });
      return toAdminDto(updated);
    } catch (e) {
      if (e instanceof SoundNotFoundError) throw new NotFoundException(e.message);
      if (e instanceof TypeError) {
        // 'rejection_reason_required' → 400; durum makinesi ihlali ise 409.
        if (e.message === 'rejection_reason_required') {
          throw new BadRequestException('Red kararı için gerekçe zorunludur.');
        }
      }
      // Durum makinesi ihlali ('sound already approved/rejected') → çakışma:
      // iki moderatör aynı satıra karar verdi.
      throw new ConflictException(
        e instanceof Error ? e.message : 'Moderasyon kararı uygulanamadı.',
      );
    }
  }
}
