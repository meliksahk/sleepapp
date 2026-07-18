import { ApiProperty } from '@nestjs/swagger';

/** Kampanya fan-out sonucu (#183) — owner panelde kaç kişiye ulaştığını görür. */
export class CampaignResultDto {
  @ApiProperty({ description: "Segmentteki kullanıcı sayısı (push token'ı olanlar)" })
  recipients!: number;

  @ApiProperty({ description: "Fiilen gönderilen cihaz push'ları (opt-out yapanlar hariç)" })
  sent!: number;

  @ApiProperty({ description: 'Gönderilemeyen (token hatası) push sayısı' })
  failed!: number;
}
