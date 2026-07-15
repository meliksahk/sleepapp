import { ApiProperty } from '@nestjs/swagger';

export class SoundscapeDto {
  @ApiProperty({ format: 'uuid' }) id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty({ type: 'object', additionalProperties: { type: 'string' } })
  titleI18n!: Record<string, string>;
  @ApiProperty({ type: 'object', additionalProperties: true })
  engineParams!: Record<string, unknown>;
  @ApiProperty({ type: 'object', additionalProperties: true, nullable: true })
  layerDefs!: unknown;
  @ApiProperty({ type: [String] }) archetypeAffinity!: string[];
  @ApiProperty({ example: 1 }) version!: number;
}

export class PresetDto {
  @ApiProperty() archetypeSlug!: string;
  @ApiProperty({ type: 'object', additionalProperties: true, nullable: true })
  mixerState!: unknown;
}

export class SoundscapeDetailDto {
  @ApiProperty({ type: SoundscapeDto }) soundscape!: SoundscapeDto;
  @ApiProperty({ type: [PresetDto] }) presets!: PresetDto[];
  @ApiProperty({ nullable: true, description: 'Presigned önizleme URL (varsa)' })
  previewUrl!: string | null;
}

export class WeeklyReleaseDto {
  @ApiProperty({ example: '2026-07-13', description: 'Hafta başlangıcı (ISO tarih)' })
  weekStart!: string;
  @ApiProperty({ nullable: true }) notes!: string | null;
  @ApiProperty({ type: [SoundscapeDto] }) soundscapes!: SoundscapeDto[];
}
