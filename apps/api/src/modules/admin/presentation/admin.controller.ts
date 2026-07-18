import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Get,
  HttpCode,
  NotFoundException,
  Param,
  Patch,
  Post,
  Put,
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
  InvalidRecipeError,
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
  SearchUsersUseCase,
  isAdminRole,
  type AccessTokenClaims,
} from '../../identity';
import { Inject, Query } from '@nestjs/common';
import { ListAllFlagsUseCase } from '../../flags';
import { AdminUserDto } from './admin-user.dto';
import { AdminFlagDto } from './admin-flag.dto';
import { AdminMeDto } from './dto';
import { AdminSoundscapeDetailDto, AdminSoundscapeDto } from './soundscape.dto';
import { OverviewDto } from './overview.dto';
import { AuditEntryDto } from './audit.dto';
import { CreateSoundscapeDto } from './create-soundscape.dto';
import { SetRecipeDto } from './recipe.dto';
import { UpdateSoundscapeDto } from './update-soundscape.dto';
import { AUDIT_LOG, type AuditLog, type NewAuditEntry } from '../domain/audit';
import {
  OVERVIEW_SOURCE,
  SOUNDSCAPE_CATALOG,
  type CatalogEntry,
  type OverviewSource,
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
  constructor(
    @Inject(SOUNDSCAPE_CATALOG) private readonly catalog: SoundscapeCatalog,
    @Inject(OVERVIEW_SOURCE) private readonly overviewSource: OverviewSource,
    @Inject(AUDIT_LOG) private readonly audit: AuditLog,
    private readonly userSearch: SearchUsersUseCase,
    private readonly flagsList: ListAllFlagsUseCase,
  ) {}

  /**
   * Tüm feature flag tanımlarını ham kurallarıyla listeler (docs/03 A4 rollout
   * görünürlüğü). Salt OKUMA → her panel rolü (sınıf `@Roles(...ADMIN_ROLES)`).
   * Değiştirme (upsert) ayrı, owner-kapılı bir iş (zincirle sırada).
   */
  @Get('flags')
  @ApiOperation({ summary: 'Feature flag tanımlarını listele (rollout görünürlüğü)' })
  @ApiOkResponse({ type: [AdminFlagDto] })
  async listFlags(): Promise<AdminFlagDto[]> {
    const flags = await this.flagsList.execute();
    return flags.map((f) => ({ key: f.key, rules: f.rules }));
  }

  /**
   * Kullanıcı arama (docs/02 §165 destek senaryosu): e-posta alt-dizesi veya tam id.
   *
   * **ROL DARALTMASI:** yalnızca `owner` + `support` — kullanıcı e-postası PII'dir;
   * içerik editörü (`editor`) ve salt-okunur `analyst` görmemeli. Sınıf `@Roles`ını
   * bilinçli daraltıyoruz (soundscape mutasyonlarındaki desenle aynı).
   *
   * Salt OKUMA → audit_log YOK (audit mutasyonlar için). ≥2 karakter (use case kapısı):
   * boş sorgu tüm tabanı dökmez.
   */
  @Get('users')
  @Roles('owner', 'support')
  @ApiOperation({ summary: 'E-posta veya id ile kullanıcı ara (destek)' })
  @ApiOkResponse({ type: [AdminUserDto] })
  async searchUsers(@Query('q') q?: string): Promise<AdminUserDto[]> {
    const rows = await this.userSearch.execute(q ?? '');
    return rows.map((u) => ({
      id: u.id,
      kind: u.kind,
      email: u.email,
      createdAt: u.createdAt.toISOString(),
    }));
  }

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
   * Panel panosu rakamları. Yalnızca bugün DOĞRU hesaplanabilenler — D7 retention
   * ve deneme→ücretli için sahte sayı üretmektense panelde dürüst yer tutucu kalır.
   * Okuma: her panel rolü (analyst dahil) görebilir.
   */
  @Get('overview')
  @ApiOperation({ summary: 'Panel panosu sayilari' })
  @ApiOkResponse({ type: OverviewDto })
  async overview(): Promise<OverviewDto> {
    return this.overviewSource.read();
  }

  /**
   * Son panel etkinlikleri (docs/03 "Son etkinlik"). Okuma: her panel rolü —
   * analyst'in "ne oldu?" sorusuna bakabilmesi salt okunurluğa aykırı değil.
   *
   * Sabit 20 kayıt: pano bir AKIŞ özeti, arşiv değil. Tam geçmiş için filtreli
   * bir uç gerekir (ayrı iş) — sınırsız liste sessizce O(n) olurdu.
   */
  @Get('audit')
  @ApiOperation({ summary: 'Son panel etkinlikleri (denetim izi)' })
  @ApiOkResponse({ type: AuditEntryDto, isArray: true })
  async auditLog(): Promise<AuditEntryDto[]> {
    const entries = await this.audit.recent(20);
    return entries.map((e) => ({
      id: e.id,
      actorEmail: e.actorEmail,
      action: e.action,
      target: e.target,
      details: e.details,
      createdAt: e.createdAt.toISOString(),
    }));
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
      await this.audit.record({
        actorId: user.sub,
        action: 'soundscape.create',
        target: e.slug,
        details: { title: e.title },
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
  async publish(
    @Param('slug') slug: string,
    @CurrentUser() user: AccessTokenClaims,
  ): Promise<AdminSoundscapeDto> {
    return this.runCatalog(() => this.catalog.publish(slug), {
      actorId: user.sub,
      action: 'soundscape.publish',
      target: slug,
    });
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
  async unpublish(
    @Param('slug') slug: string,
    @CurrentUser() user: AccessTokenClaims,
  ): Promise<AdminSoundscapeDto> {
    return this.runCatalog(() => this.catalog.unpublish(slug), {
      actorId: user.sub,
      action: 'soundscape.unpublish',
      target: slug,
    });
  }

  /**
   * Tek kayıt + düzenlenecek ham tarif. Listede tarif taşınmaz (#119) — panelin
   * düzenleme ekranı için ayrı uç.
   */
  @Get('soundscapes/:slug')
  @ApiOperation({ summary: 'Tek soundscape + ham ses tarifi (taslak dahil)' })
  @ApiOkResponse({ type: AdminSoundscapeDetailDto })
  @ApiNotFoundResponse({ description: 'Soundscape yok' })
  async soundscape(@Param('slug') slug: string): Promise<AdminSoundscapeDetailDto> {
    try {
      const { entry, recipe } = await this.catalog.get(slug);
      return { ...toDto(entry), recipe };
    } catch (err) {
      if (err instanceof SoundscapeNotFoundError) {
        throw new NotFoundException({ code: err.code, message: err.message });
      }
      throw err;
    }
  }

  /**
   * Ses tarifini yaz (docs/03 A1). Yayınlama kapısının (#122) karşılığı: içerik
   * PANELDEN sese kavuşabilsin — o güne dek tarif yalnızca DB'ye elle girilebiliyordu.
   */
  @Put('soundscapes/:slug/recipe')
  @HttpCode(200)
  @Roles('owner', 'editor')
  @ApiOperation({ summary: 'Ses tarifini yaz (sema dogrulamali)' })
  @ApiOkResponse({ type: AdminSoundscapeDto })
  @ApiForbiddenResponse({ description: 'Yazma yetkisi yok' })
  @ApiNotFoundResponse({ description: 'Soundscape yok' })
  async setRecipe(
    @Param('slug') slug: string,
    @Body() dto: SetRecipeDto,
    @CurrentUser() user: AccessTokenClaims,
  ): Promise<AdminSoundscapeDto> {
    return this.runCatalog(() => this.catalog.setRecipe(slug, dto), {
      actorId: user.sub,
      action: 'soundscape.recipe',
      target: slug,
      details: { layers: dto.layers.length },
    });
  }

  /**
   * Başlık / affinity güncelle. KISMİ: verilmeyen alana dokunulmaz.
   * Slug yok — derin linkte yaşar (bkz. UpdateSoundscapeDto).
   */
  @Patch('soundscapes/:slug')
  @HttpCode(200)
  @Roles('owner', 'editor')
  @ApiOperation({ summary: 'Baslik/affinity guncelle (kismi)' })
  @ApiOkResponse({ type: AdminSoundscapeDto })
  @ApiForbiddenResponse({ description: 'Yazma yetkisi yok' })
  @ApiNotFoundResponse({ description: 'Soundscape yok' })
  async updateSoundscape(
    @Param('slug') slug: string,
    @Body() dto: UpdateSoundscapeDto,
    @CurrentUser() user: AccessTokenClaims,
  ): Promise<AdminSoundscapeDto> {
    return this.runCatalog(
      () =>
        this.catalog.update(slug, {
          titleEn: dto.titleEn,
          archetypeAffinity: dto.archetypeAffinity,
        }),
      {
        actorId: user.sub,
        action: 'soundscape.update',
        target: slug,
        // Yalnızca NE değişti — değerler değil (gövde PII taşımaz ilkesi).
        details: {
          changed: [
            ...(dto.titleEn === undefined ? [] : ['title']),
            ...(dto.archetypeAffinity === undefined ? [] : ['affinity']),
          ],
        },
      },
    );
  }

  /**
   * Domain hatalarını HTTP'ye çevirir — tek yerde, uçlar arasında sapma olmasın.
   *
   * `auditEntry` verilirse iz YALNIZCA BAŞARIDA yazılır: reddedilen bir yayınlama
   * denemesini "yayınladı" diye kaydetmek, izi yalandan beter yapardı.
   */
  private async runCatalog(
    fn: () => Promise<CatalogEntry>,
    auditEntry?: NewAuditEntry,
  ): Promise<AdminSoundscapeDto> {
    try {
      const entry = await fn();
      if (auditEntry) await this.audit.record(auditEntry);
      return toDto(entry);
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
      // Geçersiz tarif bir GİRDİ hatasıdır (400), durum çakışması değil.
      if (err instanceof InvalidRecipeError) {
        throw new BadRequestException({ code: err.code, message: err.message });
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
