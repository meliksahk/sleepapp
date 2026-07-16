import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Get,
  HttpCode,
  NotFoundException,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiCreatedResponse,
  ApiForbiddenResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import {
  ContentError,
  EmptyRecipeError,
  InvalidSlugError,
  SlugTakenError,
  SoundscapeNotFoundError,
} from '../../content';
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
import { CreateSoundscapeDto } from './create-soundscape.dto';
import {
  SOUNDSCAPE_CATALOG,
  type CatalogEntry,
  type SoundscapeCatalog,
} from '../domain/soundscape-catalog';

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

  /**
   * Taslak oluştur.
   *
   * ROL DARALTMASI: sınıf `@Roles(...ADMIN_ROLES)` ile OKUMA'yı tüm panel rollerine
   * açar; burası metod düzeyinde EZER (RolesGuard handler'ı önce okur). `analyst`
   * SALT OKUNUR bir roldür (CLAUDE.md §3.3) — içeriği görebilmeli, değiştirememeli.
   * `support` da içerik editörü değildir.
   */
  @Post('soundscapes')
  @HttpCode(201)
  @Roles('owner', 'editor')
  @ApiOperation({ summary: 'Yeni taslak soundscape olustur' })
  @ApiCreatedResponse({ type: AdminSoundscapeDto })
  @ApiForbiddenResponse({ description: 'Yazma yetkisi yok (analyst/support okur, yazamaz)' })
  @ApiConflictResponse({ description: 'Slug zaten kullanimda' })
  async createSoundscape(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: CreateSoundscapeDto,
  ): Promise<AdminSoundscapeDto> {
    try {
      const e = await this.catalog.create({
        slug: dto.slug,
        titleEn: dto.titleEn,
        archetypeAffinity: dto.archetypeAffinity,
        // Denetim izi çağırandan gelir, gövdeden DEĞİL: istemcinin "ben şuyum"
        // demesine güvenmek, denetim izini işe yaramaz kılardı.
        createdBy: user.sub,
      });
      return {
        id: e.id,
        slug: e.slug,
        title: e.title,
        status: e.status,
        archetypeAffinity: [...e.archetypeAffinity],
        version: e.version,
        createdAt: e.createdAt.toISOString(),
      };
    } catch (err) {
      if (err instanceof SlugTakenError)
        throw new ConflictException({ code: err.code, message: err.message });
      if (err instanceof InvalidSlugError)
        throw new BadRequestException({ code: err.code, message: err.message });
      if (err instanceof ContentError)
        throw new BadRequestException({ code: err.code, message: err.message });
      throw err;
    }
  }

  /**
   * Yayınla. AYRI ve BİLİNÇLİ bir eylem: oluşturma daima taslak üretir (#120).
   * Boş ses tarifi burada reddedilir — sessiz bozuk içerik canlıya çıkmasın.
   */
  @Post('soundscapes/:slug/publish')
  @HttpCode(200)
  @Roles('owner', 'editor')
  @ApiOperation({ summary: 'Soundscape yayinla (bos ses tarifi reddedilir)' })
  @ApiOkResponse({ type: AdminSoundscapeDto })
  @ApiForbiddenResponse({ description: 'Yazma yetkisi yok' })
  @ApiNotFoundResponse({ description: 'Soundscape yok' })
  async publish(@Param('slug') slug: string): Promise<AdminSoundscapeDto> {
    return this.runCatalog(() => this.catalog.publish(slug));
  }

  /**
   * Yayından kaldır. Kapı YOK: geri çekmek her zaman güvenlidir ve acil durumda
   * (yanlış içerik canlıda) hiçbir koşula takılmamalıdır.
   */
  @Post('soundscapes/:slug/unpublish')
  @HttpCode(200)
  @Roles('owner', 'editor')
  @ApiOperation({ summary: 'Soundscape yayindan kaldir (taslaga dondurur)' })
  @ApiOkResponse({ type: AdminSoundscapeDto })
  async unpublish(@Param('slug') slug: string): Promise<AdminSoundscapeDto> {
    return this.runCatalog(() => this.catalog.unpublish(slug));
  }

  /** Domain hatalarını HTTP'ye çevirir — tek yerde, uçlar arasında sapma olmasın. */
  private async runCatalog(fn: () => Promise<CatalogEntry>): Promise<AdminSoundscapeDto> {
    try {
      return toDto(await fn());
    } catch (err) {
      if (err instanceof SoundscapeNotFoundError) {
        throw new NotFoundException({ code: err.code, message: err.message });
      }
      if (err instanceof SlugTakenError) {
        throw new ConflictException({ code: err.code, message: err.message });
      }
      // Boş tarif bir ÇAKIŞMA değil, kaydın MEVCUT DURUMUYLA ilgili bir engel →
      // 409: "isteğin doğru ama kaynak şu an bunu kaldırmıyor".
      if (err instanceof EmptyRecipeError) {
        throw new ConflictException({ code: err.code, message: err.message });
      }
      if (err instanceof InvalidSlugError || err instanceof ContentError) {
        throw new BadRequestException({ code: err.code, message: err.message });
      }
      throw err;
    }
  }
}

function toDto(e: CatalogEntry): AdminSoundscapeDto {
  return {
    id: e.id,
    slug: e.slug,
    title: e.title,
    status: e.status,
    archetypeAffinity: [...e.archetypeAffinity],
    version: e.version,
    createdAt: e.createdAt.toISOString(),
  };
}
