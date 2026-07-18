import { ApiProperty } from '@nestjs/swagger';

/**
 * Kampanya fan-out sonucu (#183 → #190 asenkron). Fan-out artık BullMQ kuyruğuyla ASENKRON:
 * owner isteği anında döner, teslim worker'da olur. Bu yüzden yanıt fiili sent/failed DEĞİL,
 * kaç işin kuyruğa alındığını (`queued`) bildirir — sent/failed istek anında bilinemez.
 */
export class CampaignResultDto {
  @ApiProperty({ description: "Segmentteki kullanıcı sayısı (push token'ı olanlar)" })
  recipients!: number;

  @ApiProperty({ description: 'Teslim için kuyruğa alınan iş sayısı (fiili gönderim worker’da)' })
  queued!: number;
}
