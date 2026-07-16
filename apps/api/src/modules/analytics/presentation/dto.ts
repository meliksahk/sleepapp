import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsISO8601,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { MAX_EVENTS_PER_BATCH } from '../domain/analytics-event';

export class AnalyticsEventDto {
  @ApiProperty({ example: 'archetype_completed', description: 'küçük harf/rakam/_/. (1-64)' })
  @IsString()
  @MaxLength(64)
  @Matches(/^[a-z0-9_.]+$/, { message: 'name yalnızca a-z 0-9 _ . içerebilir' })
  name!: string;

  @ApiProperty({ format: 'date-time', description: 'Olay zamanı (ISO 8601, UTC)' })
  @IsISO8601()
  occurredAt!: string;

  @ApiProperty({ required: false, description: 'Serbest anahtar-değer (PII konmaz)' })
  @IsOptional()
  @IsObject()
  props?: Record<string, unknown>;
}

export class IngestEventsDto {
  @ApiProperty({ type: [AnalyticsEventDto], description: `1-${MAX_EVENTS_PER_BATCH} olay` })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(MAX_EVENTS_PER_BATCH)
  @ValidateNested({ each: true })
  @Type(() => AnalyticsEventDto)
  events!: AnalyticsEventDto[];
}

export class IngestAcceptedDto {
  @ApiProperty({ example: 3, description: 'Kabul edilen olay sayısı' })
  accepted!: number;
}
