import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { IsBcp47Locale, IsIanaTimeZone } from './field.validators';

const CHRONOTYPES = ['lion', 'bear', 'wolf', 'dolphin'] as const;

export class UpdateProfileDto {
  @ApiPropertyOptional({ maxLength: 40, nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  displayName?: string | null;

  @ApiPropertyOptional({ enum: CHRONOTYPES, nullable: true })
  @IsOptional()
  @IsIn(CHRONOTYPES)
  chronotype?: string | null;

  @ApiPropertyOptional({ example: 'en', maxLength: 10 })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  @IsBcp47Locale()
  locale?: string;

  @ApiPropertyOptional({ example: 'Europe/Istanbul', maxLength: 64 })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @IsIanaTimeZone()
  timezone?: string;

  @ApiPropertyOptional({ example: true, description: 'Push bildirim tercihi' })
  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;

  @ApiPropertyOptional({
    example: 23,
    minimum: 0,
    maximum: 23,
    nullable: true,
    description: 'Akşam hatırlatıcısı saati — KULLANICININ YEREL saati, UTC değil. null = kapalı.',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(23)
  reminderHour?: number | null;

  @ApiPropertyOptional({ example: 23, minimum: 0, maximum: 23, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(23)
  quietHoursStart?: number | null;

  @ApiPropertyOptional({ example: 8, minimum: 0, maximum: 23, nullable: true })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(23)
  quietHoursEnd?: number | null;
}

export class ProfileResponseDto {
  @ApiProperty({ format: 'uuid' })
  userId!: string;

  @ApiProperty({ nullable: true })
  displayName!: string | null;

  @ApiProperty({ nullable: true })
  chronotype!: string | null;

  @ApiProperty({ example: 'en' })
  locale!: string;

  @ApiProperty({ example: 'UTC' })
  timezone!: string;

  @ApiProperty({ example: true })
  notificationsEnabled!: boolean;

  @ApiProperty({ example: 23, nullable: true, description: 'Yerel saat (0-23), null = kapalı' })
  reminderHour!: number | null;

  @ApiProperty({ example: 23, nullable: true })
  quietHoursStart!: number | null;

  @ApiProperty({ example: 8, nullable: true })
  quietHoursEnd!: number | null;
}
