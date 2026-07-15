import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { GetFlagsUseCase } from '../application/get-flags.usecase';

@ApiTags('flags')
@ApiBearerAuth()
@Controller('flags')
@UseGuards(AuthGuard)
export class FlagsController {
  constructor(private readonly getFlags: GetFlagsUseCase) {}

  @Get()
  @ApiOperation({ summary: 'Kullanıcı için değerlendirilmiş feature flag haritası' })
  @ApiOkResponse({
    schema: { type: 'object', additionalProperties: { type: 'boolean' } },
  })
  flags(@CurrentUser() user: AccessTokenClaims): Promise<Record<string, boolean>> {
    return this.getFlags.execute(user.sub);
  }
}
