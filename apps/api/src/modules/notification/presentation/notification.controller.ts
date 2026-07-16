import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { RegisterDeviceTokenUseCase } from '../application/register-device-token.usecase';
import { SendNotificationUseCase } from '../application/send-notification.usecase';
import { FanOutResultDto, RegisterTokenDto, TestNotificationDto } from './dto';

@ApiTags('notification')
@ApiBearerAuth()
@Controller('notifications')
@UseGuards(AuthGuard)
export class NotificationController {
  constructor(
    private readonly registerToken: RegisterDeviceTokenUseCase,
    private readonly send: SendNotificationUseCase,
  ) {}

  @Post('token')
  @HttpCode(204)
  @ApiOperation({ summary: 'Push cihaz token kaydı (idempotent)' })
  async register(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: RegisterTokenDto,
  ): Promise<void> {
    await this.registerToken.execute(user.sub, dto.token, dto.platform);
  }

  @Post('test')
  @HttpCode(200)
  @ApiOperation({ summary: 'Kendi cihazlarına test push (fan-out doğrulama)' })
  @ApiOkResponse({ type: FanOutResultDto })
  async test(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: TestNotificationDto,
  ): Promise<FanOutResultDto> {
    // Yalnızca kendi cihazlarına — hedef daima token sub (userId scope).
    return this.send.execute(user.sub, { title: dto.title, body: dto.body });
  }
}
