import { Controller, Get, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiForbiddenResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import {
  ADMIN_ROLES,
  AuthGuard,
  CurrentUser,
  Roles,
  RolesGuard,
  isAdminRole,
  type AccessTokenClaims,
} from '../../identity';
import { Inject } from '@nestjs/common';
import { AdminMeDto } from './dto';
import { AdminSoundscapeDto } from './soundscape.dto';
import { SOUNDSCAPE_CATALOG, type SoundscapeCatalog } from '../domain/soundscape-catalog';

/**
 * Admin panel API'si (docs/03 A0). Bu controller'daki HER uç rol kapılıdır —
 * sınıf düzeyinde `@Roles` ile: yeni bir uç eklerken rol koymayı unutmak
 * "herkese açık admin ucu" demek olurdu, varsayılan kapalı olmalı.
 *
 * Guard SIRASI önemli: AuthGuard req.user'ı doldurur, RolesGuard onu okur.
 */
@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin')
@UseGuards(AuthGuard, RolesGuard)
@Roles(...ADMIN_ROLES)
export class AdminController {
  constructor(@Inject(SOUNDSCAPE_CATALOG) private readonly catalog: SoundscapeCatalog) {}

  @Get('me')
  @ApiOperation({ summary: "Admin oturumunu ve rolleri doğrular (panel auth guard'ı)" })
  @ApiOkResponse({ type: AdminMeDto })
  @ApiForbiddenResponse({ description: 'Çağıranın admin rolü yok' })
  me(@CurrentUser() user: AccessTokenClaims): AdminMeDto {
    // Yalnızca TANINAN roller döner: DB'ye elle yazılmış çöp bir rol adı panelin
    // yetki mantığına sızmasın (panel bu listeye göre menü/aksiyon gösterecek).
    return { userId: user.sub, roles: user.roles.filter(isAdminRole) };
  }

  /**
   * İçerik listesi — TASLAK DAHİL (uygulamanın feed'i yalnızca yayınlanmışı görür).
   * Sınıf düzeyindeki `@Roles(...ADMIN_ROLES)` geçerli: analyst dahil her panel rolü
   * içeriği GÖREBİLİR. Yazma yetkisi ayrı iş — CRUD gelince rol daraltılacak.
   */
  @Get('soundscapes')
  @ApiOperation({ summary: 'Tum soundscape kayitlari (taslak/planli/yayinlanmis)' })
  @ApiOkResponse({ type: AdminSoundscapeDto, isArray: true })
  async soundscapes(): Promise<AdminSoundscapeDto[]> {
    const entries = await this.catalog.list();
    return entries.map((e) => ({
      id: e.id,
      slug: e.slug,
      title: e.title,
      status: e.status,
      archetypeAffinity: [...e.archetypeAffinity],
      version: e.version,
      createdAt: e.createdAt.toISOString(),
    }));
  }
}
