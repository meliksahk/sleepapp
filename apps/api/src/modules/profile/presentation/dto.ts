import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

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
  locale?: string;

  @ApiPropertyOptional({ example: 'Europe/Istanbul', maxLength: 64 })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  timezone?: string;
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
}
