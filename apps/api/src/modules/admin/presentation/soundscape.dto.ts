import { ApiProperty } from '@nestjs/swagger';

export class AdminSoundscapeDto {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;

  @ApiProperty({ description: 'Görünen başlık (EN; yoksa slug)' })
  title!: string;

  @ApiProperty({ enum: ['draft', 'scheduled', 'published'] })
  status!: string;

  @ApiProperty({ type: [String], description: 'Uygun uyku kimlikleri' })
  archetypeAffinity!: string[];

  @ApiProperty() version!: number;

  @ApiProperty({ description: 'ISO 8601 UTC (CLAUDE.md §4)' })
  createdAt!: string;
}

/** Detay: özet + DÜZENLENECEK ham tarif (doğrulanmamış — bkz. AdminSoundscapeView). */
export class AdminSoundscapeDetailDto extends AdminSoundscapeDto {
  @ApiProperty({
    type: 'object',
    additionalProperties: true,
    description:
      'Ham engine_params. Eski/elle girilmiş bozuk bir tarif de dönebilir — editör onu GÖREBİLMELİ ki düzeltebilsin.',
  })
  recipe!: unknown;
}
