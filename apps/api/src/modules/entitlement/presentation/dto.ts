import { ApiProperty } from '@nestjs/swagger';

import type { EntitlementTier } from '../domain/entitlement';

export class EntitlementResponseDto {
  @ApiProperty({
    enum: ['free', 'plus', 'lifetime'],
    example: 'plus',
    description: 'Kullanıcının katmanı.',
  })
  tier!: EntitlementTier;

  @ApiProperty({
    example: true,
    description: 'Premium kapısı — plus veya lifetime → true. İstemci gating için bunu okur.',
  })
  premium!: boolean;
}
