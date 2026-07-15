import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';

export class JoinWaitlistDto {
  @ApiProperty({ format: 'email', example: 'user@example.com' })
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiPropertyOptional({ example: 'tiktok', description: 'UTM/kaynak etiketi' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  source?: string;
}
