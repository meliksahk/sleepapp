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
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { RegisterDeviceUseCase } from '../application/register-device.usecase';
import { RefreshSessionUseCase } from '../application/refresh-session.usecase';
import { DeleteAccountUseCase } from '../application/delete-account.usecase';
import { RequestEmailUpgradeUseCase } from '../application/request-email-upgrade.usecase';
import { VerifyEmailUpgradeUseCase } from '../application/verify-email-upgrade.usecase';
import { EmailAlreadyTakenError, IdentityError } from '../domain/errors';
import type { AccessTokenClaims } from '../domain/user.entity';
import { Inject } from '@nestjs/common';
import { AuthGuard } from './auth.guard';
import { CurrentUser } from './current-user.decorator';
import { IS_PRODUCTION } from './tokens';
import {
  EmailRequestResponseDto,
  EmailVerifyResponseDto,
  MeResponseDto,
  RefreshDto,
  RegisterDeviceDto,
  RequestEmailDto,
  SessionResponseDto,
  VerifyEmailDto,
} from './dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly registerDevice: RegisterDeviceUseCase,
    private readonly refreshSession: RefreshSessionUseCase,
    private readonly deleteAccount: DeleteAccountUseCase,
    private readonly requestEmailUpgrade: RequestEmailUpgradeUseCase,
    private readonly verifyEmailUpgrade: VerifyEmailUpgradeUseCase,
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
