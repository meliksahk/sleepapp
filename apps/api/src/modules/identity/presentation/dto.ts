import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

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

export class AdminLoginDto {
  @ApiProperty({ description: 'Admin hesabının e-postası', example: 'owner@nocta.app' })
  @IsEmail()
  email!: string;

  @ApiProperty({ description: 'Parola' })
  @IsString()
  // Alt sınır 12: admin hesabı en değerli hedeftir. Üst sınır 200: argon2 girdisini
  // sınırsız bırakmak, uzun parolayla CPU yakma (DoS) yolu açar.
  @MinLength(12)
  @MaxLength(200)
  password!: string;

  @ApiPropertyOptional({
    description:
      'İki adımlı doğrulama kodu (yalnızca hesapta 2FA etkinse gerekir). ' +
      'Eksikse yanıt 401 + code=totp_required döner.',
    example: '123456',
  })
  @IsOptional()
  @IsString()
  // Tam 6 hane: biçimsiz girdi HMAC hesaplanmadan burada elenir.
  @Matches(/^\d{6}$/, { message: 'totpCode 6 haneli olmalı' })
  totpCode?: string;
}

export class TotpConfirmDto {
  @ApiProperty({ description: 'Authenticator uygulamasındaki 6 haneli kod', example: '123456' })
  @IsString()
  @Matches(/^\d{6}$/, { message: 'code 6 haneli olmalı' })
  code!: string;
}

export class TotpEnrollResponseDto {
  @ApiProperty({
    description: 'Base32 gizli anahtar — elle giriş için. Bir daha GÖSTERİLMEZ.',
    example: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
  })
  secret!: string;

  @ApiProperty({
    description: 'QR koduna gömülecek otpauth:// URI',
    example: 'otpauth://totp/NOCTA%3Aowner%40nocta.app?secret=...&issuer=NOCTA',
  })
  otpauthUri!: string;
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
