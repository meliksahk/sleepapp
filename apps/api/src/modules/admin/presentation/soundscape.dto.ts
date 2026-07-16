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
