import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/**
 * Push kampanyası gövdesi (POST /v1/admin/campaigns, #183). SAĞLIK İDDİASI: owner'ın
 * sorumluluğu (§1.1) — çalışma-zamanı metni koddaki check:health-claims'e girmez.
 */
export class SendCampaignDto {
  @ApiProperty({ example: 'Yeni haftalık soundscape', description: 'Bildirim başlığı' })
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  title!: string;

  @ApiProperty({ example: 'Bu haftanın ritüel sesi yayında.', description: 'Bildirim gövdesi' })
  @IsString()
  @MinLength(1)
  @MaxLength(240)
  body!: string;

  @ApiProperty({
    required: false,
    enum: ['ios', 'android'],
    description: 'Tanımlıysa yalnızca bu platformun cihazları; boş = tüm push kullanıcıları',
  })
  @IsOptional()
  @IsString()
  @IsIn(['ios', 'android'])
  platform?: string;
}
