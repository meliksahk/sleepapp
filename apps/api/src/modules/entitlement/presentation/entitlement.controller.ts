import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';

import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { GetEntitlementUseCase } from '../application/get-entitlement.usecase';
import { isPremium } from '../domain/entitlement';
import { EntitlementResponseDto } from './dto';

/**
 * `GET /v1/me/entitlement` (docs/02 §183). İstemci premium kapılarını buna göre açar.
 * Bugün stub premium döner; B5'te gerçek IAP durumu döner — bu controller değişmez.
 */
@ApiTags('entitlement')
@ApiBearerAuth()
@Controller('me/entitlement')
@UseGuards(AuthGuard)
export class EntitlementController {
  constructor(private readonly getEntitlement: GetEntitlementUseCase) {}

  @Get()
  @ApiOperation({ summary: 'Kimliği doğrulanmış kullanıcının premium yetkilendirmesi' })
  @ApiOkResponse({ type: EntitlementResponseDto })
  async get(@CurrentUser() user: AccessTokenClaims): Promise<EntitlementResponseDto> {
    // Scope daima token'daki sub — istemciden id kabul edilmez ("A, B'yi okuyamaz").
    const entitlement = await this.getEntitlement.execute(user.sub);
    return { tier: entitlement.tier, premium: isPremium(entitlement.tier) };
  }
}
