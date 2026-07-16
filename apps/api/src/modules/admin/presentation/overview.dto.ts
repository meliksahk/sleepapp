import { ApiProperty } from '@nestjs/swagger';

class SoundscapeCountsDto {
  @ApiProperty() draft!: number;
  @ApiProperty() scheduled!: number;
  @ApiProperty() published!: number;
}

/**
 * Pano rakamları — YALNIZCA bugün doğru hesaplanabilenler.
 *
 * D7 retention (kohort analizi gerekir) ve deneme→ücretli (F6/billing yok) BİLEREK
 * yok: sahte bir sayı göstermektense panelde dürüst yer tutucu kalır.
 */
export class OverviewDto {
  @ApiProperty({ type: SoundscapeCountsDto })
  soundscapes!: SoundscapeCountsDto;

  @ApiProperty({ description: 'Bekleme listesi kayıt sayısı' })
  waitlist!: number;
}
