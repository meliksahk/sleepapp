import { ApiProperty } from '@nestjs/swagger';
import type { FlagRules } from '../../flags';

/** Feature flag tanımı (admin görünürlük, docs/03 A4). Ham kurallar: enabled,
 * rolloutPercentage, platforms, minAppVersion. */
export class AdminFlagDto {
  @ApiProperty({ description: 'Flag anahtarı' })
  key!: string;

  @ApiProperty({
    description: 'Ham kurallar (enabled, rolloutPercentage, platforms, minAppVersion)',
  })
  rules!: FlagRules;
}
