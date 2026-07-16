import { ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsInt } from 'class-validator';
import { ENGINE_PARAMS_SCHEMA_VERSION, MAX_MIXER_LAYERS, NOISE_TYPES } from '../../content';

/**
 * Ses tarifi girdisi.
 *
 * KASITLI OLARAK SIĞ doğrulama: DTO yalnızca "kaba şekil"i (dizi mi, kaç eleman)
 * kontrol eder. Asıl sözleşme (katman alanları, gain aralığı, benzersiz id, sürüm)
 * content'in domain'inde `parseEngineParams` ile zorlanır — kural iki yerde
 * yaşasaydı biri sessizce eskirdi ve bozuk tarif kullanıcının telefonunda patlardı.
 */
export class SetRecipeDto {
  @ApiProperty({
    example: ENGINE_PARAMS_SCHEMA_VERSION,
    description: 'Tarif şema sürümü (docs/04 §79) — eski istemci zarifçe geri düşebilsin',
  })
  @IsInt()
  schemaVersion!: number;

  @ApiProperty({
    description: `Mikser katmanları (1–${MAX_MIXER_LAYERS}); type: ${NOISE_TYPES.join('|')}, gain 0–1`,
    example: [{ id: 'base', type: 'pink', gain: 0.5 }],
    type: 'array',
    items: { type: 'object', additionalProperties: true },
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(MAX_MIXER_LAYERS)
  layers!: unknown[];
}

export class RecipeLayerDto {
  @ApiProperty() id!: string;
  @ApiProperty({ enum: NOISE_TYPES }) type!: string;
  @ApiProperty({ description: '[0,1] mikser kazancı' }) gain!: number;
}

export class RecipeDto {
  @ApiProperty() schemaVersion!: number;
  @ApiProperty({ type: [RecipeLayerDto] }) layers!: RecipeLayerDto[];
}
