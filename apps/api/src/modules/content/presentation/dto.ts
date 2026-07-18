import { ApiProperty } from '@nestjs/swagger';
import { MAX_MIXER_LAYERS, LAYER_SOURCES, type LayerSource } from '../domain/mixer-state';

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

export class MixerLayerDto {
  @ApiProperty({ example: 'rain', description: 'Katman kimliği (preset içinde benzersiz)' })
  id!: string;

  @ApiProperty({ enum: LAYER_SOURCES, example: 'pink' })
  type!: LayerSource;

  @ApiProperty({ example: 0.5, minimum: 0, maximum: 1 })
  gain!: number;
}

export class MixerStateDto {
  @ApiProperty({ type: [MixerLayerDto], description: `1..${MAX_MIXER_LAYERS} katman` })
  layers!: MixerLayerDto[];
}

export class PresetDto {
  @ApiProperty() archetypeSlug!: string;
  @ApiProperty({ type: MixerStateDto, description: 'Doğrulanmış mixer durumu' })
  mixerState!: MixerStateDto;
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
