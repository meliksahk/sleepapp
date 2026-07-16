import {
  Body,
  ConflictException,
  Controller,
  Delete,
  Get,
  HttpCode,
  Post,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiTooManyRequestsResponse,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { RegisterDeviceUseCase } from '../application/register-device.usecase';
import { RefreshSessionUseCase } from '../application/refresh-session.usecase';
import { LoginAdminUseCase } from '../application/login-admin.usecase';
import { DeleteAccountUseCase } from '../application/delete-account.usecase';
import { RequestEmailUpgradeUseCase } from '../application/request-email-upgrade.usecase';
import { VerifyEmailUpgradeUseCase } from '../application/verify-email-upgrade.usecase';
import { RevokeOtherSessionsUseCase } from '../application/revoke-other-sessions.usecase';
import { GetActiveSessionsUseCase } from '../application/get-active-sessions.usecase';
import { EmailAlreadyTakenError, IdentityError } from '../domain/errors';
import type { AccessTokenClaims } from '../domain/user.entity';
import { Inject } from '@nestjs/common';
import { AuthGuard } from './auth.guard';
import { CurrentUser } from './current-user.decorator';
import { IS_PRODUCTION } from './tokens';
import {
  AdminLoginDto,
  EmailRequestResponseDto,
  EmailVerifyResponseDto,
  MeResponseDto,
  RefreshDto,
  RegisterDeviceDto,
  RequestEmailDto,
  RevokedSessionsDto,
  SessionInfoDto,
  SessionResponseDto,
  VerifyEmailDto,
} from './dto';

/**
 * Admin giriş limiti — istek anında okunur (Resolvable), böylece test ve operasyon
 * ayarlayabilir. `loadEnv()` BURADA çağrılamaz: presentation katmanı `shared/config`'i
 * import edemez (boundary lint, docs/02 §2) ve decorator DI kullanamaz. Değer yine de
 * env.ts şemasında tanımlı → açılışta zod ile DOĞRULANIR; buradaki okuma yalnızca
 * doğrulanmış değeri geri alır. Bozuk/eksikse güvenli varsayılana (5) düşer.
 */
function adminLoginLimit(): number {
  const parsed = Number(process.env.ADMIN_LOGIN_LIMIT);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 5;
}

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly registerDevice: RegisterDeviceUseCase,
    private readonly refreshSession: RefreshSessionUseCase,
    private readonly loginAdmin: LoginAdminUseCase,
    private readonly deleteAccount: DeleteAccountUseCase,
    private readonly requestEmailUpgrade: RequestEmailUpgradeUseCase,
    private readonly verifyEmailUpgrade: VerifyEmailUpgradeUseCase,
    private readonly revokeOtherSessions: RevokeOtherSessionsUseCase,
    private readonly getActiveSessions: GetActiveSessionsUseCase,
    @Inject(IS_PRODUCTION) private readonly isProduction: boolean,
  ) {}

  @Post('device')
  @HttpCode(201)
  @ApiOperation({ summary: 'Anonim cihaz kaydı → access + refresh token' })
  @ApiCreatedResponse({ type: SessionResponseDto })
  async device(@Body() dto: RegisterDeviceDto): Promise<SessionResponseDto> {
    return this.registerDevice.execute({ fingerprint: dto.fingerprint, platform: dto.platform });
  }

  @Post('refresh')
  @HttpCode(200)
  @ApiOperation({ summary: 'Refresh token rotasyonu (reuse-detection ile)' })
  @ApiOkResponse({ type: SessionResponseDto })
  @ApiUnauthorizedResponse({ description: 'Geçersiz veya yeniden kullanılmış refresh token' })
  async refresh(@Body() dto: RefreshDto): Promise<SessionResponseDto> {
    try {
      return await this.refreshSession.execute(dto.refreshToken);
    } catch (e) {
      if (e instanceof IdentityError) {
        throw new UnauthorizedException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }

  /**
   * Panel girişi. Burada (identity'de) yaşar: auth kodu YALNIZCA bu modülde
   * (CLAUDE.md §6) — admin modülü kripto/parola görmez.
   *
   * KABA KUVVET: global limit route başına 60/dk'dır — "gezinme" için makul,
   * "parola tahmini" için değil (tek IP'den günde 86.400 deneme). Sistemdeki en
   * değerli hesap olduğu için burada 5/dk. Meşru kullanıcıyı zorlamaz: insan bir
   * dakikada 5'ten fazla parola denemez.
   *
   * SINIRI: bu limit IP BAŞINADIR. Çok IP'li (botnet/proxy) bir saldırgan yine
   * dağıtarak deneyebilir — asıl çözüm HESAP başına kilitleme, o ise yeni bir DB
   * alanı ister (ayrı iş, defterde). Bu, tek IP'li kaba kuvveti 12.000× yavaşlatır.
   */
  @Post('admin/login')
  @HttpCode(200)
  @Throttle({ default: { limit: adminLoginLimit, ttl: 60_000 } })
  @ApiOperation({ summary: 'Admin panel girişi (e-posta + parola)' })
  @ApiOkResponse({ type: SessionResponseDto })
  @ApiUnauthorizedResponse({ description: 'E-posta veya parola hatalı' })
  @ApiTooManyRequestsResponse({ description: 'Çok fazla giriş denemesi (5/dk)' })
  async adminLogin(@Body() dto: AdminLoginDto): Promise<SessionResponseDto> {
    try {
      return await this.loginAdmin.execute(dto.email, dto.password);
    } catch (e) {
      if (e instanceof IdentityError) {
        // Hangi koşulun düştüğü SÖYLENMEZ (kullanıcı sayımı) — tek mesaj.
        throw new UnauthorizedException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }

  @Get('me')
  @UseGuards(AuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Doğrulanmış kullanıcının kendi kimliği' })
  @ApiOkResponse({ type: MeResponseDto })
  me(@CurrentUser() user: AccessTokenClaims): MeResponseDto {
    // DAİMA token'daki sub — istemciden id kabul edilmez.
    return { userId: user.sub, roles: [...user.roles] };
  }

  @Delete('me')
  @UseGuards(AuthGuard)
  @ApiBearerAuth()
  @HttpCode(204)
  @ApiOperation({ summary: 'Hesabı sil (kaskad — tüm ilişkili veri temizlenir)' })
  async remove(@CurrentUser() user: AccessTokenClaims): Promise<void> {
    // Yalnızca kendi hesabını siler — scope daima token sub.
    await this.deleteAccount.execute(user.sub);
  }

  @Get('sessions')
  @UseGuards(AuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "Kullanıcının aktif oturumları (cihaz listesi, token'sız)" })
  @ApiOkResponse({ type: [SessionInfoDto] })
  async sessions(@CurrentUser() user: AccessTokenClaims): Promise<SessionInfoDto[]> {
    const list = await this.getActiveSessions.execute(user.sub);
    return list.map((s) => ({
      familyId: s.familyId,
      createdAt: s.createdAt.toISOString(),
      expiresAt: s.expiresAt.toISOString(),
    }));
  }

  @Post('sessions/revoke-others')
  @UseGuards(AuthGuard)
  @ApiBearerAuth()
  @HttpCode(200)
  @ApiOperation({ summary: 'Diğer cihazlardan çık — mevcut oturum hariç tümünü iptal et' })
  @ApiOkResponse({ type: RevokedSessionsDto })
  @ApiUnauthorizedResponse({ description: 'Geçersiz refresh token' })
  async revokeOthers(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: RefreshDto,
  ): Promise<RevokedSessionsDto> {
    try {
      const revoked = await this.revokeOtherSessions.execute(user.sub, dto.refreshToken);
      return { revoked };
    } catch (e) {
      if (e instanceof IdentityError) {
        throw new UnauthorizedException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }

  @Post('email/request')
  @UseGuards(AuthGuard)
  @ApiBearerAuth()
  @HttpCode(202)
  @ApiOperation({ summary: 'E-posta ile hesaba yükseltme için magic link iste' })
  @ApiOkResponse({ type: EmailRequestResponseDto })
  async requestEmail(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: RequestEmailDto,
  ): Promise<EmailRequestResponseDto> {
    try {
      const token = await this.requestEmailUpgrade.execute(user.sub, dto.email);
      // Ham token yalnızca development'ta (test/lokal); production'da ASLA sızdırılmaz.
      return this.isProduction ? { status: 'sent' } : { status: 'sent', devMagicToken: token };
    } catch (e) {
      if (e instanceof EmailAlreadyTakenError) {
        throw new ConflictException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }

  @Post('email/verify')
  @HttpCode(200)
  @ApiOperation({ summary: 'Magic link ile e-postayı doğrula → hesabı yükselt' })
  @ApiOkResponse({ type: EmailVerifyResponseDto })
  async verifyEmail(@Body() dto: VerifyEmailDto): Promise<EmailVerifyResponseDto> {
    try {
      return await this.verifyEmailUpgrade.execute(dto.token);
    } catch (e) {
      if (e instanceof EmailAlreadyTakenError) {
        throw new ConflictException({ code: e.code, message: e.message });
      }
      if (e instanceof IdentityError) {
        throw new UnauthorizedException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }
}
