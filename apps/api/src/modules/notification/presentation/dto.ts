import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterTokenDto {
  @ApiProperty({ description: 'APNs/FCM push token' })
  @IsString()
  @MinLength(8)
  @MaxLength(512)
  token!: string;

  @ApiProperty({ enum: ['ios', 'android'] })
  @IsIn(['ios', 'android'])
  platform!: string;
}

export class TestNotificationDto {
  @ApiProperty({ example: 'Test', maxLength: 80 })
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  title!: string;

  @ApiProperty({ example: 'Bu bir test bildirimidir.', maxLength: 240 })
  @IsString()
  @MinLength(1)
  @MaxLength(240)
  body!: string;
}

export class FanOutResultDto {
  @ApiProperty({ example: 2, description: 'Başarılı gönderim sayısı' }) sent!: number;
  @ApiProperty({ example: 0, description: 'Başarısız gönderim sayısı' }) failed!: number;
}
