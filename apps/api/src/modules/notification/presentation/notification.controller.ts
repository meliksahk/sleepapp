import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { RegisterDeviceTokenUseCase } from '../application/register-device-token.usecase';
import { RegisterTokenDto } from './dto';

@ApiTags('notification')
@ApiBearerAuth()
@Controller('notifications')
@UseGuards(AuthGuard)
export class NotificationController {
  constructor(private readonly registerToken: RegisterDeviceTokenUseCase) {}

  @Post('token')
  @HttpCode(204)
  @ApiOperation({ summary: 'Push cihaz token kaydı (idempotent)' })
  async register(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: RegisterTokenDto,
  ): Promise<void> {
    await this.registerToken.execute(user.sub, dto.token, dto.platform);
  }
}
