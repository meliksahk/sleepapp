import { Controller, Get, NotFoundException, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { GetArchetypeShareUseCase } from '../application/get-archetype-share.usecase';
import type { ArchetypeShare } from '../domain/share';
import { ArchetypeShareDto } from './dto';

@ApiTags('sharing')
@ApiBearerAuth()
@Controller('sharing')
@UseGuards(AuthGuard)
export class SharingController {
  constructor(private readonly getShare: GetArchetypeShareUseCase) {}

  @Get('archetype')
  @ApiOperation({ summary: 'Kullanıcının archetype sonucundan paylaşım kartı + deep link' })
  @ApiOkResponse({ type: ArchetypeShareDto })
  async archetype(@CurrentUser() user: AccessTokenClaims): Promise<ArchetypeShare> {
    const share = await this.getShare.execute(user.sub);
    if (!share) {
      throw new NotFoundException({
        code: 'no_result',
        message: 'Paylaşılacak archetype sonucu yok — önce testi tamamlayın.',
      });
    }
    return share;
  }
}
