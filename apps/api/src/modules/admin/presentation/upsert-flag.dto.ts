import { ApiProperty } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Feature flag kural gövdesi (PUT /v1/admin/flags/:key). Anahtar URL'den gelir.
 * Doğrulama BURADA: rollout yüzdesi 0-100 dışıysa ya da sürüm çöpse flag CANLI
 * davranışı bozardı — global ValidationPipe (whitelist+forbidNonWhitelisted) reddeder.
 */
export class UpsertFlagDto {
  @ApiProperty({ description: 'Flag açık mı (kapalıysa hiç kimseye gitmez)' })
  @IsBoolean()
  enabled!: boolean;

  @ApiProperty({
    required: false,
    minimum: 0,
    maximum: 100,
    description: 'Tanımlıysa kova < yüzde alan kullanıcılar; tanımsız = herkes',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  rolloutPercentage?: number;

  @ApiProperty({
    type: [String],
    required: false,
    description: "Tanımlıysa yalnızca bu platformlar (ör. ['ios','android'])",
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(8)
  platforms?: string[];

  @ApiProperty({
    required: false,
    example: '1.4.0',
    description: 'Tanımlıysa istemci sürümü >= bu olmalı (semver benzeri)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  // Semver benzeri: 1-3 sayısal parça. Serbest metin sürüm karşılaştırmasını bozardı.
  @Matches(/^\d+(\.\d+){0,2}$/, { message: 'minAppVersion semver benzeri olmalı (ör. 1.4.0)' })
  minAppVersion?: string;
}
