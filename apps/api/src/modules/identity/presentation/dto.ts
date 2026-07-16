import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceDto {
  @ApiProperty({ description: 'Cihaz başına benzersiz parmak izi', example: 'abc123-device' })
  @IsString()
  @MinLength(8)
  @MaxLength(256)
  fingerprint!: string;

  @ApiProperty({ enum: ['ios', 'android', 'web'], example: 'ios' })
  @IsString()
  @MaxLength(32)
  platform!: string;
}

export class RefreshDto {
  @ApiProperty({ description: 'Opak refresh token' })
  @IsString()
  @MinLength(16)
  refreshToken!: string;
}

export class RevokedSessionsDto {
  @ApiProperty({ example: 2, description: 'İptal edilen diğer oturum sayısı' })
  revoked!: number;
}

export class SessionInfoDto {
  @ApiProperty({ format: 'uuid', description: 'Oturum (cihaz zinciri) kimliği' })
  familyId!: string;
  @ApiProperty({ format: 'date-time' }) createdAt!: string;
  @ApiProperty({ format: 'date-time' }) expiresAt!: string;
}

export class SessionResponseDto {
  @ApiProperty()
  accessToken!: string;

  @ApiProperty()
  refreshToken!: string;

  @ApiProperty({ description: 'Access token ömrü (saniye)', example: 900 })
  accessTokenExpiresIn!: number;

  @ApiProperty({ format: 'uuid' })
  userId!: string;
}

export class MeResponseDto {
  @ApiProperty({ format: 'uuid' })
  userId!: string;

  @ApiProperty({ type: [String] })
  roles!: string[];
}

export class RequestEmailDto {
  @ApiProperty({ format: 'email', example: 'user@example.com' })
  @IsEmail()
  @MaxLength(254)
  email!: string;
}

export class VerifyEmailDto {
  @ApiProperty({ description: 'Magic link token' })
  @IsString()
  @MinLength(16)
  token!: string;
}

export class EmailRequestResponseDto {
  @ApiProperty({ example: 'sent' })
  status!: string;

  @ApiProperty({ required: false, description: 'Yalnızca development — test için ham token' })
  devMagicToken?: string;
}

export class EmailVerifyResponseDto {
  @ApiProperty({ format: 'uuid' })
  userId!: string;

  @ApiProperty({ format: 'email' })
  email!: string;
}
