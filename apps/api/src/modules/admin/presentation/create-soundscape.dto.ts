import { ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateSoundscapeDto {
  @ApiProperty({ example: 'deep-ocean-drift', description: 'URL kimliği (küçük-harf-kebab)' })
  @IsString()
  @MinLength(2)
  @MaxLength(64)
  slug!: string;

  @ApiProperty({ example: 'Deep Ocean Drift', description: 'İngilizce başlık (birincil dil)' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  titleEn!: string;

  @ApiProperty({
    type: [String],
    required: false,
    default: [],
    description: 'Uygun uyku kimlikleri (archetype slug)',
  })
  @IsArray()
  @IsString({ each: true })
  // Üst sınır: 8 archetype var; sınırsız dizi kabul etmek anlamsız yük.
  @ArrayMaxSize(16)
  archetypeAffinity: string[] = [];
}
