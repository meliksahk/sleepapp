import { ApiPropertyOptional } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/**
 * Kısmi güncelleme. Verilmeyen alan = DOKUNMA.
 *
 * SLUG YOK ve olmayacak: derin linkte yaşar (`/a/{slug}`, `/library/{slug}`) ve
 * paylaşılan kartlarda dolaşır → değiştirmek dışarıdaki linkleri sessizce kırardı.
 * Yeniden adlandırma istenirse yönlendirme tablosu gerekir (ayrı iş).
 */
export class UpdateSoundscapeDto {
  @ApiPropertyOptional({ example: 'Deep Ocean Drift', description: 'İngilizce başlık' })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  titleEn?: string;

  @ApiPropertyOptional({ type: [String], description: 'Uygun uyku kimlikleri (tam liste)' })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(16)
  archetypeAffinity?: string[];
}
