import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsISO8601, Min } from 'class-validator';

export class RecordSleepSessionDto {
  @ApiProperty({ format: 'date-time', description: 'Uyku başlangıcı (ISO 8601, UTC)' })
  @IsISO8601()
  startedAt!: string;

  @ApiProperty({ format: 'date-time', description: 'Uyku bitişi (ISO 8601, UTC)' })
  @IsISO8601()
  endedAt!: string;

  @ApiProperty({ example: 12, description: 'On-device hareket olayı sayısı (türetilmiş)' })
  @IsInt()
  @Min(0)
  movementEvents!: number;

  @ApiProperty({ example: 3, description: 'On-device ses olayı sayısı (türetilmiş)' })
  @IsInt()
  @Min(0)
  soundEvents!: number;
}

export class NightReportDto {
  @ApiProperty({ example: '2026-07-15' }) nightDate!: string;
  @ApiProperty({ example: 1 }) sessionCount!: number;
  @ApiProperty({ example: 462 }) totalDurationMinutes!: number;
  @ApiProperty({ example: 12 }) movementEvents!: number;
  @ApiProperty({ example: 3 }) soundEvents!: number;
  @ApiProperty({
    example: 85,
    description: 'Uygulama-içi göreli dinginlik (0-100), sağlık ölçüsü değil',
  })
  calmScore!: number;
}

export class SleepSessionDto {
  @ApiProperty({ format: 'uuid' }) id!: string;
  @ApiProperty({ format: 'date-time' }) startedAt!: string;
  @ApiProperty({ format: 'date-time' }) endedAt!: string;
  @ApiProperty({ example: '2026-07-15', description: 'Gece etiketi (yerel gün, 06:00 sınırı)' })
  nightDate!: string;
  @ApiProperty({ example: 462 }) durationMinutes!: number;
  @ApiProperty({ example: 12 }) movementEvents!: number;
  @ApiProperty({ example: 3 }) soundEvents!: number;
}
