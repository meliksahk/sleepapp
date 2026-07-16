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
class ShareFunnelDto {
  @ApiProperty({ description: 'Archetype testini tamamlayan BENZERSİZ kullanıcı' })
  completed!: number;

  @ApiProperty({ description: 'Kartını paylaşan benzersiz kullanıcı' })
  shared!: number;

  @ApiProperty({
    nullable: true,
    description:
      'shared/completed. Kimse testi tamamlamadıysa NULL — oran tanımsızdır; ' +
      '0 göstermek "kimse paylaşmıyor" demek olurdu ve bu yanlış olurdu.',
  })
  rate!: number | null;
}

export class OverviewDto {
  @ApiProperty({ type: SoundscapeCountsDto })
  soundscapes!: SoundscapeCountsDto;

  @ApiProperty({ description: 'Bekleme listesi kayıt sayısı' })
  waitlist!: number;

  @ApiProperty({ type: ShareFunnelDto, description: 'Viral kanca sağlığı' })
  shareFunnel!: ShareFunnelDto;
}
