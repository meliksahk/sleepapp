import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { GetFlagsUseCase } from '../application/get-flags.usecase';

@ApiTags('flags')
@ApiBearerAuth()
@Controller('flags')
@UseGuards(AuthGuard)
export class FlagsController {
  constructor(private readonly getFlags: GetFlagsUseCase) {}

  @Get()
  @ApiOperation({ summary: 'Kullanıcı + context için değerlendirilmiş feature flag haritası' })
  @ApiQuery({ name: 'platform', required: false, example: 'ios' })
  @ApiQuery({ name: 'appVersion', required: false, example: '1.4.0' })
  @ApiOkResponse({
    schema: { type: 'object', additionalProperties: { type: 'boolean' } },
  })
  flags(
    @CurrentUser() user: AccessTokenClaims,
    @Query('platform') platform?: string,
    @Query('appVersion') appVersion?: string,
  ): Promise<Record<string, boolean>> {
    return this.getFlags.execute(user.sub, { platform, appVersion });
  }
}
