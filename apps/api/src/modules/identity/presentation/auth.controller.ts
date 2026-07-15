import {
  Body,
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
import { IdentityError } from '../domain/errors';
import type { AccessTokenClaims } from '../domain/user.entity';
import { AuthGuard } from './auth.guard';
import { CurrentUser } from './current-user.decorator';
import { MeResponseDto, RefreshDto, RegisterDeviceDto, SessionResponseDto } from './dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly registerDevice: RegisterDeviceUseCase,
    private readonly refreshSession: RefreshSessionUseCase,
    private readonly deleteAccount: DeleteAccountUseCase,
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
}
